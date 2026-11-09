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
        let host = InferenceHostView(engine: engine)
        controller.view.addSubview(host)
        host.frame = CGRect(x: 0, y: 0, width: 80, height: 48)
        host.layoutIfNeeded()
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
        let window = UIWindow(frame: UIScreen.main.bounds)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let host = InferenceHostView(engine: engine)
        controller.view.addSubview(host)
        host.frame = CGRect(x: 0, y: 0, width: 80, height: 48)
        host.layoutIfNeeded()
        defer { engine.stop(); window.isHidden = true }
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
    @MainActor
    func testReadReceiptIsSynchronousAndFailureReenablesRead() async throws {
        var called = false
        let model = SpeechViewModel(action: { _, _ in
            called = true
            throw EMASpeechEngine.Failure(message: "TEST_ASYNC_ERROR")
        })
        model.speak()
        XCTAssertTrue(model.diagnostics.tapAcknowledged)
        XCTAssertEqual(model.diagnostics.trace?.records[.validation]?.status, .success)
        XCTAssertFalse(called, "Engine must not run before synchronous receipt")
        XCTAssertTrue(model.isGenerating)
        for _ in 0..<100 where model.isGenerating { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(called)
        XCTAssertFalse(model.isGenerating)
        XCTAssertTrue(model.errorMessage?.contains("TEST_ASYNC_ERROR") == true)
        model.speak()
        XCTAssertTrue(model.diagnostics.tapAcknowledged)
        model.stop()
        XCTAssertFalse(model.isGenerating)
    }

    @MainActor
    func testUnmountedWebViewTimesOutAndReturnsControl() async throws {
        let engine = EMASpeechEngine(timing: EMATiming(overall: 10, overrides: [.webView: 0.2]))
        do { _ = try await engine.render(SpeechRequest(text: "Merhaba.")); XCTFail("Unmounted WebView must not silently load") }
        catch { XCTAssertEqual(engine.diagnostics.trace?.firstFailure, .webView) }
        XCTAssertTrue(engine.diagnostics.report().contains("WKWebView"))
    }

    @MainActor
    func testWorkerFaultsBridgeTimeoutAndNativeCancellation() async throws {
        for fault in [EMATestFault.missingWorker, .thrownWorker, .stalledWorker, .unresolvedPromise, .bridgeNeverReady] {
            let engine = EMASpeechEngine(timing: EMATiming(overall: 30, overrides: [.bridge: fault == .bridgeNeverReady ? 0.8 : 20]), fault: fault)
            let window = UIWindow(frame: UIScreen.main.bounds)
            let controller = UIViewController(); window.rootViewController = controller; window.makeKeyAndVisible()
            let host = InferenceHostView(engine: engine); controller.view.addSubview(host)
            host.frame = CGRect(x: 0, y: 0, width: 80, height: 48); host.layoutIfNeeded()
            do { _ = try await engine.render(SpeechRequest(text: "Merhaba.")); XCTFail("Fault must not produce audio: \(fault)") }
            catch {
                let report = engine.diagnostics.report()
                XCTAssertNotNil(engine.diagnostics.trace?.firstFailure, report)
                XCTAssertFalse(report.contains("Merhaba."), "Input must not leak to report")
                if fault == .thrownWorker { XCTAssertTrue(report.contains("EMA_TEST_WORKER_ERROR"), report) }
                if fault == .bridgeNeverReady { XCTAssertEqual(engine.diagnostics.trace?.firstFailure, .bridge) }
            }
            engine.stop(); window.isHidden = true
        }
    }

}
