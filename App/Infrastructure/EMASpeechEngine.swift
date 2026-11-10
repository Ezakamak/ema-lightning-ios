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

/// Actual EMA ONNX graphs executed by the bundled CPU/WASM runtime inside WebKit.
/// AVSpeechSynthesizer is never used by this adapter, including on failures.
@MainActor
final class EMASpeechEngine: NSObject, SpeechEngine, WKNavigationDelegate {
    enum EngineError: LocalizedError {
        case missingAssets, invalidAudio, timedOut, webProcessTerminated
        case javascript(String)
        var errorDescription: String? {
            switch self {
            case .missingAssets: return "Paketlenmiş EMA dosyaları bulunamadı."
            case .invalidAudio: return "EMA geçerli ses üretemedi."
            case .timedOut: return "EMA işlemi zaman aşımına uğradı. Daha kısa bir metin deneyin."
            case .webProcessTerminated: return "EMA çalışma zamanı durduruldu. Yeniden deneyin."
            case .javascript(let message): return message
            }
        }
    }

    let displayName = "EMA Lightning · ONNX / CPU"
    let webView: WKWebView
    private var server: LoopbackAssetServer?
    private var origin: URL?
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var pageLoaded = false
    private var loadingNavigation: WKNavigation?
    private var generation = UUID()
    private var player: AVAudioPlayer?
    private var activeRender: UUID?
    private var timeout: Task<Void, Never>?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.isInspectable = false
    }

    func speak(_ request: SpeechRequest) async throws {
        let speech = try await render(request)
        try Task.checkCancellation()
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try AVAudioSession.sharedInstance().setActive(true)
        player = try AVAudioPlayer(data: speech.wav)
        guard player?.play() == true else { throw EngineError.invalidAudio }
    }

    /// Does not play audio; the iOS integration tests exercise this exact inference path.
    func render(_ request: SpeechRequest) async throws -> RenderedSpeech {
        guard activeRender == nil else { throw EngineError.javascript("EMA zaten ses üretiyor.") }
        let renderID = UUID()
        activeRender = renderID
        let current = generation
        print("EMA: loading bundled inference page")
        let timer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(180)) } catch { return }
            self?.invalidate(error: EngineError.timedOut)
        }
        timeout = timer
        defer {
            timer.cancel()
            if activeRender == renderID { activeRender = nil; timeout = nil }
        }
        try await loadPage()
        guard generation == current else { throw CancellationError() }
        print("EMA: starting bundled ONNX synthesis")
        let value = try await webView.callAsyncJavaScript(
            "if (!window.emaReady) throw new Error('EMA bridge not ready'); return await window.synthesize(text);",
            arguments: ["text": request.text], in: nil, contentWorld: .page)
        try Task.checkCancellation()
        guard generation == current else { throw CancellationError() }
        guard let result = value as? [String: Any], let base64 = result["wav"] as? String,
              let wav = Data(base64Encoded: base64), wav.count > 44,
              let count = result["samples"] as? Int, count > 4800,
              let rate = result["sampleRate"] as? Int, rate == 48000,
              let rms = result["rms"] as? Double, rms.isFinite, rms > 1e-5,
              let normalized = result["normalized"] as? String else { throw EngineError.invalidAudio }
        print("EMA: rendered \(count) samples at \(rate) Hz")
        return RenderedSpeech(wav: wav, sampleCount: count, sampleRate: rate, rms: rms, normalizedText: normalized)
    }

    private func loadPage() async throws {
        if pageLoaded { return }
        if server == nil {
            guard let root = Bundle.main.url(forResource: "EMA", withExtension: nil) else {
                throw EngineError.missingAssets
            }
            let assetServer = LoopbackAssetServer(root: root)
            server = assetServer
            do { origin = try await assetServer.start() }
            catch { server = nil; throw error }
        }
        guard let url = origin else { throw EngineError.missingAssets }
        try await withCheckedThrowingContinuation { continuation in
            loadContinuation = continuation
            loadingNavigation = webView.load(URLRequest(url: url))
        }
    }

    func stop() {
        player?.stop()
        player = nil
        invalidate(error: CancellationError())
    }

    private func invalidate(error: Error) {
        generation = UUID()
        timeout?.cancel()
        activeRender = nil
        loadingNavigation = nil
        webView.evaluateJavaScript("window.cancelSynthesis?.()")
        webView.stopLoading()
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
        // Reload on next request: also recovers from a terminated WebContent process.
        pageLoaded = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === loadingNavigation else { return }
        loadingNavigation = nil
        pageLoaded = true
        loadContinuation?.resume()
        loadContinuation = nil
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation === loadingNavigation else { return }
        loadingNavigation = nil
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.webView(webView, didFail: navigation, withError: error)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        invalidate(error: EngineError.webProcessTerminated)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let origin,
              url.scheme == "http", url.host == "127.0.0.1", url.port == origin.port,
              url.path.hasPrefix(origin.deletingLastPathComponent().path + "/") else {
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }

    deinit { server?.stop() }
}
