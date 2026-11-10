// SPDX-License-Identifier: Apache-2.0
import AVFoundation
import SpeechCore

/// Explicit Apple preview. It never substitutes for EMA or enters the EMA archive.
@MainActor
final class SystemSpeechEngine: NSObject, SpeechEngine, AVSpeechSynthesizerDelegate {
    enum EngineError: LocalizedError {
        case turkishVoiceUnavailable
        var errorDescription: String? { "Türkçe sistem sesi bulunamadı. Ayarlar’dan Türkçe ses indirin." }
    }
    let displayName = "Apple Türkçe sistem sesi"
    private let synthesizer = AVSpeechSynthesizer()
    private var pending: CheckedContinuation<Void, Error>?
    private var utterance: AVSpeechUtterance?
    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ request: SpeechRequest) async throws {
        try Task.checkCancellation()
        stop()
        guard let voice = AVSpeechSynthesisVoice(language: "tr-TR") else { throw EngineError.turkishVoiceUnavailable }
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try AVAudioSession.sharedInstance().setActive(true)
        let speech = AVSpeechUtterance(string: request.text); speech.voice = voice
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                pending = continuation; utterance = speech; synthesizer.speak(speech)
            }
        } onCancel: { Task { @MainActor [weak self] in self?.stop() } }
    }
    func stop() {
        let continuation = pending; pending = nil; utterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        continuation?.resume(throwing: CancellationError())
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish speech: AVSpeechUtterance) {
        guard utterance === speech else { return }
        let continuation = pending; pending = nil; utterance = nil; continuation?.resume()
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel speech: AVSpeechUtterance) {
        guard utterance === speech else { return }; stop()
    }
}
