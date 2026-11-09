// SPDX-License-Identifier: Apache-2.0
import AVFoundation
import SpeechCore

/// Apple's system voice is a preview backend; it is not EMA Lightning inference.
@MainActor
final class SystemSpeechEngine: SpeechEngine {
    enum EngineError: LocalizedError {
        case turkishVoiceUnavailable
        var errorDescription: String? { "Türkçe sistem sesi bulunamadı. Ayarlar’dan Türkçe ses indirin." }
    }

    let displayName = "Apple Türkçe sistem sesi"
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ request: SpeechRequest) async throws {
        guard let voice = AVSpeechSynthesisVoice(language: "tr-TR") else {
            throw EngineError.turkishVoiceUnavailable
        }
        stop()
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: request.text)
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
