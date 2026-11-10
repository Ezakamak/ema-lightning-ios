// SPDX-License-Identifier: Apache-2.0
import AVFoundation
import Combine

@MainActor
final class RecordingPlayback: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var recordingID: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    private var player: AVAudioPlayer?
    private var clock: Timer?
    private var interruption: NSObjectProtocol?

    override init() {
        super.init()
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.pause() }
        }
    }
    func play(_ recording: SpeechRecording, url: URL) throws {
        if recordingID == recording.id, let player {
            if player.isPlaying { pause(); return }
            try activate()
            if player.currentTime >= player.duration - 0.05 { player.currentTime = 0 }
            guard player.play() else { throw PlaybackError.failed }
        } else {
            stop(); try activate()
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.delegate = self
            guard audio.prepareToPlay(), audio.play() else { throw PlaybackError.failed }
            player = audio; recordingID = recording.id; duration = audio.duration
        }
        isPlaying = true; startClock()
    }
    private func activate() throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try AVAudioSession.sharedInstance().setActive(true)
    }
    func pause() { player?.pause(); isPlaying = false; clock?.invalidate(); clock = nil }
    func seek(_ value: Double) { player?.currentTime = max(0, min(value, duration)); position = player?.currentTime ?? 0 }
    func stop() {
        player?.stop(); player?.delegate = nil; player = nil
        clock?.invalidate(); clock = nil; isPlaying = false; recordingID = nil; position = 0; duration = 0
    }
    private func startClock() {
        clock?.invalidate()
        clock = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.position = self?.player?.currentTime ?? 0 }
        }
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        position = duration; isPlaying = false; clock?.invalidate(); clock = nil
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) { stop() }
    deinit { clock?.invalidate(); if let interruption { NotificationCenter.default.removeObserver(interruption) } }
    private enum PlaybackError: LocalizedError {
        case failed
        var errorDescription: String? { "Ses kaydı oynatılamadı." }
    }
}
