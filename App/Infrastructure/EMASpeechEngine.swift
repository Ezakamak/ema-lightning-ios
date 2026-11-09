// SPDX-License-Identifier: Apache-2.0
import AVFoundation
import WebKit
import SpeechCore

struct RenderedSpeech {
    let wav: Data
    let sampleCount: Int
    let sampleRate: Int
    let rms: Double
    let normalizedText: String
}

struct EMATiming {
    var overall: Double = 180
    var stageOverride: Double?
    var overrides: [EMAStage: Double] = [:]
    func seconds(for stage: EMAStage) -> Double {
        if let value = overrides[stage] { return value }
        if let stageOverride { return stageOverride }
        switch stage {
        case .server, .webView, .bridge, .worker: return 20
        case .page, .wav, .transfer: return 30
        case .player: return 10
        case .playback: return 180
        default: return 90
        }
    }
}

/// Faults are explicit test inputs. Production always uses the real bundled worker/models.
enum EMATestFault: String {
    case none, missingWorker, thrownWorker, stalledWorker, unresolvedPromise, bridgeNeverReady
    var workerFile: String {
        switch self {
        case .missingWorker: return "missing-worker.js"
        case .thrownWorker: return "test-fixtures/throw-worker.js"
        case .stalledWorker: return "test-fixtures/stalled-worker.js"
        case .unresolvedPromise: return "test-fixtures/unresolved-worker.js"
        default: return "worker.js"
        }
    }
}

@MainActor
private final class WeakEMAMessageHandler: NSObject, WKScriptMessageHandler {
    weak var engine: EMASpeechEngine?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        engine?.receive(message)
    }
}

@MainActor
final class EMASpeechEngine: NSObject, SpeechEngine, WKNavigationDelegate, AVAudioPlayerDelegate {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    private final class Operation {
        let id = UUID()
        let diagnosticID: UUID
        var server: LoopbackAssetServer?
        var origin: URL?
        var navigation: WKNavigation?
        var pageLoaded = false
        var bridgeReady = false
        var load: CheckedContinuation<Void, Error>?
        var javascript: CheckedContinuation<Any, Error>?
        var playback: CheckedContinuation<Void, Error>?
        var overallTimer: Task<Void, Never>?
        var timers: [EMAStage: Task<Void, Never>] = [:]
        init(diagnosticID: UUID) { self.diagnosticID = diagnosticID }
    }

    let displayName = "EMA Lightning · ONNX / CPU"
    let webView: WKWebView
    let diagnostics: EMADiagnostics
    private let timing: EMATiming
    private let fault: EMATestFault
    private var active: Operation?
    private var player: AVAudioPlayer?
    private var attachment: CheckedContinuation<Void, Error>?
    private var attachmentID: UUID?

    init(diagnostics: EMADiagnostics? = nil, timing: EMATiming = EMATiming(), fault: EMATestFault = .none) {
        self.diagnostics = diagnostics ?? EMADiagnostics(); self.timing = timing; self.fault = fault
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let handler = WeakEMAMessageHandler()
        config.userContentController.add(handler, name: "emaDiagnostics")
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        handler.engine = self
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.isInspectable = false
    }

    var hostReady: Bool {
        webView.window != nil && webView.superview != nil && !webView.isHidden &&
        webView.bounds.width >= 8 && webView.bounds.height >= 8 && webView.alpha > 0.01
    }

    /// Called from the same persistent host view used in production and integration tests.
    func hostDidChange() {
        guard hostReady, attachment != nil else { return }
        let continuation = attachment
        attachment = nil; attachmentID = nil
        continuation?.resume()
    }

    func speak(_ request: SpeechRequest) async throws {
        _ = try await perform(request, diagnosticID: nil, shouldPlay: true)
    }
    func speak(_ request: SpeechRequest, diagnosticID: UUID) async throws {
        _ = try await perform(request, diagnosticID: diagnosticID, shouldPlay: true)
    }
    func render(_ request: SpeechRequest) async throws -> RenderedSpeech {
        try await perform(request, diagnosticID: nil, shouldPlay: false)
    }

    private func perform(_ request: SpeechRequest, diagnosticID: UUID?, shouldPlay: Bool) async throws -> RenderedSpeech {
        guard active == nil else { throw Failure(message: "EMA isteği zaten çalışıyor; önce Durdur’a basın.") }
        let traceID = diagnosticID ?? diagnostics.begin(engine: displayName, input: request.text)
        diagnostics.protect(request.text)
        let op = Operation(diagnosticID: traceID)
        active = op
        let operationID = op.id
        return try await withTaskCancellationHandler {
            defer { teardown(op) }
            op.overallTimer = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(self?.timing.overall ?? 180)) } catch { return }
                self?.abort(operationID, error: Failure(message: "180 saniyelik genel işlem süresi aşıldı. Beklenen aşama: \(self?.diagnostics.currentStage?.title ?? "bilinmiyor")."))
            }
            do {
                stage(.engine, .running, op: op)
                stage(.server, .running, op: op)
                let server = LoopbackAssetServer(root: try assetRoot()) { [weak self] event in
                    Task { @MainActor [weak self] in self?.serverEvent(event, operationID: operationID) }
                }
                op.server = server
                op.origin = try await server.start()
                try ensureActive(op)
                stage(.server, .success, op: op, detail: "IPv4 loopback dinleyicisi hazır")
                stage(.webView, .running, op: op)
                if !hostReady {
                    try await withCheckedThrowingContinuation { continuation in
                        attachmentID = operationID; attachment = continuation
                    }
                }
                try ensureActive(op)
                guard hostReady else { throw Failure(message: "WKWebView aktif pencereye bağlı değil veya görünür boyutu 8×8’den küçük.") }
                stage(.webView, .success, op: op, detail: "Pencere bağlantısı ve \(Int(webView.bounds.width))×\(Int(webView.bounds.height)) viewport doğrulandı")
                stage(.engine, .success, op: op, detail: "Yerel sunucu ve WebKit host bağlantısı doğrulandı")
                try await loadPage(op)
                try ensureActive(op)
                let value: Any = try await withCheckedThrowingContinuation { continuation in
                    op.javascript = continuation
                    // Use our own continuation, not an uncancellable SDK async promise wait.
                    webView.callAsyncJavaScript("return await window.synthesize(text, requestID, {workerFile: workerFile, bootTimeoutMs: bootTimeout, timeoutMs: promiseTimeout});",
                        arguments: ["text": request.text, "requestID": operationID.uuidString, "workerFile": fault.workerFile, "bootTimeout": fault == .stalledWorker ? 500 : 20000, "promiseTimeout": fault == .unresolvedPromise ? 800 : 180000],
                        in: nil, in: .page) { [weak self] result in
                            guard let self, self.active?.id == operationID else { return }
                            let pending = op.javascript
                            op.javascript = nil
                            pending?.resume(with: result)
                        }
                }
                try ensureActive(op)
                stage(.transfer, .running, op: op, detail: "WebKit sonucu Swift tarafında doğrulanıyor")
                guard let result = value as? [String: Any], let base64 = result["wav"] as? String,
                      let wav = Data(base64Encoded: base64), let count = result["samples"] as? Int,
                      count > 4800, count <= 48000 * 180, wav.count == 44 + count * 2,
                      String(data: wav.prefix(4), encoding: .ascii) == "RIFF",
                      let rate = result["sampleRate"] as? Int, rate == 48000,
                      let rms = result["rms"] as? Double, rms.isFinite, rms > 1e-5,
                      let normalized = result["normalized"] as? String else {
                    throw Failure(message: "Swift aktarım doğrulaması başarısız: geçerli, 48 kHz mono PCM16 WAV alınamadı.")
                }
                diagnostics.protect(normalized)
                stage(.transfer, .success, op: op, detail: "\(wav.count) bayt WAV, \(count) örnek, 48 kHz doğrulandı")
                let speech = RenderedSpeech(wav: wav, sampleCount: count, sampleRate: rate, rms: rms, normalizedText: normalized)
                if shouldPlay { try await play(speech, op: op) }
                return speech
            } catch {
                if active?.id == operationID { abort(operationID, error: error) }
                throw error
            }
        } onCancel: { [weak self] in
            Task { @MainActor [weak self] in self?.abort(operationID, error: CancellationError()) }
        }
    }

    private func assetRoot() throws -> URL {
        guard let root = Bundle.main.url(forResource: "EMA", withExtension: nil) else {
            throw Failure(message: "Bundle içinde EMA klasörü bulunamadı.")
        }
        return root
    }
    private func ensureActive(_ op: Operation) throws {
        try Task.checkCancellation()
        guard active?.id == op.id else { throw CancellationError() }
    }
    private func stage(_ stage: EMAStage, _ status: DiagnosticStatus, op: Operation, detail: String = "") {
        guard active?.id == op.id else { return }
        guard diagnostics.update(stage, status, id: op.diagnosticID, detail: detail) else { return }
        op.timers[stage]?.cancel(); op.timers[stage] = nil
        if status == .running {
            let seconds = timing.seconds(for: stage)
            let id = op.id
            op.timers[stage] = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                self?.abort(id, error: Failure(message: "\(stage.title): \(Int(seconds)) s boyunca doğrulanmış tamamlanma olayı alınamadı."), preferred: stage)
            }
        }
    }
    private func loadPage(_ op: Operation) async throws {
        guard let url = op.origin else { throw Failure(message: "Yerel sunucu URL’si üretilemedi.") }
        stage(.page, .running, op: op)
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        let script = "window.__EMA_REQUEST_ID__ = '\(op.id.uuidString)'; window.__EMA_HIDE_READY__ = \(fault == .bridgeNeverReady ? "true" : "false");"
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        try await withCheckedThrowingContinuation { continuation in
            op.load = continuation
            op.navigation = webView.load(URLRequest(url: url))
            if op.navigation == nil { abort(op.id, error: Failure(message: "WKWebView HTML gezinmesini başlatamadı."), preferred: .page) }
        }
    }
    private func pageAndBridgeReady(_ op: Operation) {
        guard op.pageLoaded, op.bridgeReady else { return }
        let pending = op.load; op.load = nil
        pending?.resume()
    }

    private func play(_ speech: RenderedSpeech, op: Operation) async throws {
        stage(.player, .running, op: op)
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try AVAudioSession.sharedInstance().setActive(true)
        let audio = try AVAudioPlayer(data: speech.wav)
        audio.delegate = self
        guard audio.prepareToPlay() else { throw Failure(message: "AVAudioPlayer.prepareToPlay false döndürdü.") }
        player = audio
        stage(.player, .success, op: op, detail: "WAV çözüldü, oynatıcı ve ses oturumu hazır")
        stage(.playback, .running, op: op)
        try await withCheckedThrowingContinuation { continuation in
            op.playback = continuation
            if !audio.play() { abort(op.id, error: Failure(message: "AVAudioPlayer.play false döndürdü."), preferred: .playback) }
        }
    }

    func stop() {
        guard let op = active else { player?.stop(); return }
        abort(op.id, error: CancellationError())
    }
    private func abort(_ id: UUID, error: Error, preferred: EMAStage? = nil) {
        guard let op = active, op.id == id else { return }
        if error is CancellationError { diagnostics.cancel(id: op.diagnosticID) }
        else {
            let waiting = EMAStage.allCases.dropFirst(2).first { diagnostics.trace?.records[$0]?.status == .waiting }
            diagnostics.fail(preferred ?? diagnostics.currentStage ?? waiting ?? .completed, error: describe(error), id: op.diagnosticID)
        }
        // Clear every Swift wait independently of JavaScript or a responsive WebContent process.
        let loading = op.load; op.load = nil
        let javascript = op.javascript; op.javascript = nil
        let playback = op.playback; op.playback = nil
        if attachmentID == id {
            let mounted = attachment; attachment = nil; attachmentID = nil
            mounted?.resume(throwing: error)
        }
        loading?.resume(throwing: error); javascript?.resume(throwing: error); playback?.resume(throwing: error)
        teardown(op)
    }
    private func teardown(_ op: Operation) {
        op.overallTimer?.cancel()
        for timer in op.timers.values { timer.cancel() }
        op.timers.removeAll()
        op.server?.stop()
        guard active?.id == op.id else { return }
        active = nil
        player?.delegate = nil; player?.stop(); player = nil
        webView.stopLoading()
        webView.evaluateJavaScript("window.cancelSynthesis?.('\(op.id.uuidString)')")
        // Navigation also tears down workers if WebKit cannot execute the cancellation script.
        webView.loadHTMLString("<!doctype html><title>EMA durduruldu</title>", baseURL: nil)
    }
    private func describe(_ error: Error) -> String {
        let ns = error as NSError
        var parts = ["\(ns.domain) / \(ns.code): \(error.localizedDescription)"]
        for key in ["WKJavaScriptExceptionMessage", "WKJavaScriptExceptionStackTrace", "WKJavaScriptExceptionLineNumber", "WKJavaScriptExceptionColumnNumber"] {
            if let value = ns.userInfo[key] { parts.append("\(key): \(value)") }
        }
        return diagnostics.clean(parts.joined(separator: "\n"))
    }

    fileprivate func receive(_ message: WKScriptMessage) {
        guard let op = active, let data = message.body as? [String: Any],
              data["requestID"] as? String == op.id.uuidString,
              let url = message.frameInfo.request.url, url.host == "127.0.0.1", url.port == op.origin?.port else { return }
        let kind = data["kind"] as? String ?? "stage"
        let detail = data["detail"] as? String ?? ""
        let stack = data["stack"] as? String ?? ""
        if kind == "log" {
            diagnostics.note("JavaScript: \(detail)\(stack.isEmpty ? "" : "\nJS stack: " + stack)", id: op.diagnosticID)
            return
        }
        if kind == "error" {
            let preferred = (data["stage"] as? String).flatMap(EMAStage.init(rawValue:)) ?? diagnostics.currentStage
            abort(op.id, error: Failure(message: "JavaScript / Worker: \(detail)\(stack.isEmpty ? "" : "\nJS stack: " + stack)"), preferred: preferred)
            return
        }
        guard let raw = data["stage"] as? String, let item = EMAStage(rawValue: raw),
              let status = (data["status"] as? String).flatMap(DiagnosticStatus.init(rawValue:)) else { return }
        let allowed: Set<EMAStage> = [.bridge, .worker, .runtime, .normalizer, .textModel, .soundModel, .decoderModel, .normalization, .synthesis, .wav, .transfer]
        guard allowed.contains(item), status == .running || status == .success,
              !(item == .transfer && status == .success) else { return }
        stage(item, status, op: op, detail: detail)
        if item == .bridge && status == .success { op.bridgeReady = true; pageAndBridgeReady(op) }
    }

    private func serverEvent(_ event: AssetServerEvent, operationID: UUID) {
        guard let op = active, op.id == operationID else { return }
        diagnostics.note("HTTP: \(event.summary)", id: op.diagnosticID)
        if event.failed {
            abort(operationID, error: Failure(message: "Yerel HTTP: \(event.summary)"))
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let op = active, navigation === op.navigation else { return }
        op.pageLoaded = true
        stage(.page, .success, op: op, detail: "WKNavigationDelegate.didFinish")
        if diagnostics.trace?.records[.bridge]?.status == .waiting { stage(.bridge, .running, op: op) }
        pageAndBridgeReady(op)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let op = active, navigation === op.navigation else { return }
        abort(op.id, error: error, preferred: .page)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.webView(webView, didFail: navigation, withError: error)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard let op = active else { return }
        diagnostics.note("WebContent process termination: WebKit süreç sonlandırma olayı alındı. OS/bellek nedeni bu callback’ten belirlenemiyor.", id: op.diagnosticID)
        abort(op.id, error: Failure(message: "WebContent process sonlandırıldı; model belleği veya WebKit/OS hatası olabilir. Kesin neden callback’te verilmedi."))
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url?.absoluteString == "about:blank" { decisionHandler(.allow); return }
        guard let op = active, let url = navigationAction.request.url, let origin = op.origin,
              url.scheme == "http", url.host == "127.0.0.1", url.port == origin.port,
              url.path.hasPrefix(origin.deletingLastPathComponent().path + "/") else {
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    nonisolated func audioPlayerDidFinishPlaying(_ audio: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === audio, let op = self.active else { return }
            guard flag else { self.abort(op.id, error: Failure(message: "AVAudioPlayer oynatmayı başarısız tamamladı."), preferred: .playback); return }
            self.stage(.playback, .success, op: op, detail: "audioPlayerDidFinishPlaying(successfully: true)")
            self.stage(.completed, .running, op: op)
            self.stage(.completed, .success, op: op)
            let pending = op.playback; op.playback = nil; pending?.resume()
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ audio: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === audio, let op = self.active else { return }
            self.abort(op.id, error: error ?? Failure(message: "AVAudioPlayer WAV decode hatası"), preferred: .playback)
        }
    }
}
