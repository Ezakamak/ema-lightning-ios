// SPDX-License-Identifier: Apache-2.0
import Foundation
import Combine
import SpeechCore

enum EngineChoice: String, CaseIterable, Identifiable {
    case ema = "EMA Lightning (ONNX)"
    case system = "Apple sistem sesi (alternatif)"
    var id: String { rawValue }
}

@MainActor
final class SpeechViewModel: ObservableObject {
    @Published var text = "Merhaba! EMA Lightning artık kendi modelini kullanıyor."
    @Published var choice: EngineChoice = .ema { didSet { stop() } }
    @Published var errorMessage: String?
    @Published private(set) var isGenerating = false
    let diagnostics: EMADiagnostics
    let ema: EMASpeechEngine
    let library: RecordingStore
    private var system: SystemSpeechEngine?
    private var task: Task<Void, Never>?
    private var requestID: UUID?
    private let injectedAction: ((SpeechRequest, UUID) async throws -> Void)?

    init(fault: EMATestFault = .none, timing: EMATiming = EMATiming(),
         library: RecordingStore? = nil, action: ((SpeechRequest, UUID) async throws -> Void)? = nil) {
        let diagnostics = EMADiagnostics()
        self.diagnostics = diagnostics
        self.library = library ?? RecordingStore()
        ema = EMASpeechEngine(diagnostics: diagnostics, timing: timing, fault: fault)
        injectedAction = action
    }

    func speak() {
        guard !isGenerating else { return }
        // This receipt is published synchronously, before validation, WebKit or Task creation.
        let id = diagnostics.begin(engine: choice.rawValue, input: text)
        requestID = id
        diagnostics.update(.button, .running, id: id)
        diagnostics.update(.button, .success, id: id)
        diagnostics.update(.validation, .running, id: id)
        let request: SpeechRequest
        do {
            request = try SpeechRequest(text: text)
            diagnostics.update(.validation, .success, id: id)
        } catch {
            diagnostics.fail(.validation, error: error.localizedDescription, id: id)
            errorMessage = diagnostics.clean(error.localizedDescription)
            return
        }
        errorMessage = nil
        isGenerating = true
        let selected = choice
        task = Task { [weak self] in
            await Task.yield() // Give SwiftUI a rendering opportunity before engine initialization.
            guard let self, self.requestID == id, !Task.isCancelled else { return }
            defer { if self.requestID == id { self.isGenerating = false; self.task = nil } }
            do {
                if let action = self.injectedAction { try await action(request, id) }
                else if selected == .ema {
                    try await self.ema.speak(request, diagnosticID: id) { [weak self] speech in
                        guard let self, self.requestID == id else { throw CancellationError() }
                        _ = try await self.library.add(wav: speech.wav, text: request.text,
                            duration: Double(speech.sampleCount) / Double(speech.sampleRate), engine: selected.rawValue)
                    }
                }
                else {
                    self.diagnostics.note("Apple sistem sesi açıkça seçildi; EMA aşamaları çalıştırılmıyor.", id: id)
                    if self.system == nil { self.system = SystemSpeechEngine() }
                    try await self.system?.speak(request)
                }
            } catch is CancellationError { self.diagnostics.cancel(id: id) }
            catch {
                guard self.requestID == id, !Task.isCancelled else { return }
                let detail = self.diagnostics.trace?.firstFailure.flatMap { self.diagnostics.trace?.records[$0]?.detail } ?? self.diagnostics.clean(error.localizedDescription)
                self.errorMessage = detail
                if self.diagnostics.trace?.firstFailure == nil {
                    self.diagnostics.fail(self.diagnostics.currentStage ?? .engine, error: detail, id: id)
                }
            }
        }
    }

    func stop() {
        if let id = requestID, isGenerating {
            diagnostics.note("Durdur çağrısı alındı", id: id)
            diagnostics.cancel(id: id)
        }
        task?.cancel(); task = nil
        ema.stop(); system?.stop()
        isGenerating = false
        requestID = nil
    }
}
