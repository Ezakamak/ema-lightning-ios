// SPDX-License-Identifier: Apache-2.0
import Combine
import SpeechCore

@MainActor
final class SpeechViewModel: ObservableObject {
    @Published var text = "Merhaba! EMA Lightning iOS projesine hoş geldiniz."
    @Published var errorMessage: String?
    private let engine: any SpeechEngine
    var engineName: String { engine.displayName }

    init(engine: any SpeechEngine) { self.engine = engine }

    func speak() {
        do {
            try engine.speak(SpeechRequest(text: text))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() { engine.stop() }
}
