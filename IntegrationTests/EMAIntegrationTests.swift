// SPDX-License-Identifier: Apache-2.0
import XCTest
import WebKit
import AVFoundation
import SpeechCore
@testable import EMALightning

final class EMAIntegrationTests: XCTestCase {
    @MainActor
    func testBundledEMAInferenceAndTurkishNormalization() async throws {
        let engine = EMASpeechEngine()
        let window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.addSubview(engine.webView)
        engine.webView.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        defer { engine.stop(); window.isHidden = true }

        for text in ["Merhaba dünya.", "Saat 14:30, fiyat 125 TL. İstanbul ve Iğdır."] {
            let speech = try await engine.render(SpeechRequest(text: text))
            XCTAssertEqual(speech.sampleRate, 48000)
            XCTAssertGreaterThan(speech.sampleCount, 4800)
            XCTAssertGreaterThan(speech.rms, 1e-5)
            XCTAssertEqual(speech.wav.count, 44 + speech.sampleCount * 2)
            XCTAssertEqual(String(data: speech.wav.prefix(4), encoding: .ascii), "RIFF")
            XCTAssertFalse(speech.normalizedText.contains(where: \.isNumber))
            if text.contains("125") {
                XCTAssertTrue(speech.normalizedText.contains("yüz yirmi beş"))
                XCTAssertTrue(speech.normalizedText.contains("on dört otuz"))
                XCTAssertTrue(speech.normalizedText.contains("ığdır"))
            }
            // Decode with Apple's actual audio stack as well as checking the RIFF header.
            let player = try AVAudioPlayer(data: speech.wav)
            XCTAssertGreaterThan(player.duration, 0.1)
            XCTAssertEqual(player.numberOfChannels, 1)
            let attachment = XCTAttachment(data: speech.wav, uniformTypeIdentifier: "com.microsoft.waveform-audio")
            attachment.name = "EMA-model-output.wav"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        engine.stop()
        let recovered = try await engine.render(SpeechRequest(text: "Yeniden merhaba."))
        XCTAssertGreaterThan(recovered.sampleCount, 4800)
    }

    @MainActor
    func testCancelledInferenceCanRestart() async throws {
        let engine = EMASpeechEngine()
        let request = try SpeechRequest(text: "Merhaba dünya.")
        let render = Task { try await engine.render(request) }
        try await Task.sleep(for: .milliseconds(100))
        engine.stop()
        render.cancel()
        do {
            _ = try await render.value
            XCTFail("Cancelled inference must not return audio")
        } catch { /* A cancelled request is expected to throw. */ }
        let speech = try await engine.render(request)
        XCTAssertGreaterThan(speech.sampleCount, 4800)
        engine.stop()
    }
}
