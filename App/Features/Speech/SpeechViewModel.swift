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
    let ema = EMASpeechEngine()
    private let system = SystemSpeechEngine()
    private var task: Task<Void, Never>?

    func speak() {
        stop()
        let request: SpeechRequest
        do { request = try SpeechRequest(text: text) }
        catch { errorMessage = error.localizedDescription; return }
        errorMessage = nil
        isGenerating = true
        let engine: any SpeechEngine = choice == .ema ? ema : system
        task = Task { [weak self] in
            do { try await engine.speak(request) }
            catch is CancellationError { }
            catch {
                if !Task.isCancelled { self?.errorMessage = error.localizedDescription }
            }
            if !Task.isCancelled { self?.isGenerating = false }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        ema.stop()
        system.stop()
        isGenerating = false
    }
}
