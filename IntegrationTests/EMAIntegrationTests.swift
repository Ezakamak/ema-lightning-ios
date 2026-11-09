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
        host.frame = CGRect(x: 0, y: 0, width: 32, height: 24)
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
            if text == "Merhaba dünya." { try await verifyHistoryAndExports(speech, text: text) }
        }
        engine.stop()
        let recovered = try await engine.render(SpeechRequest(text: "Yeniden merhaba."))
        XCTAssertGreaterThan(recovered.sampleCount, 4800)
    }

    @MainActor
    private func verifyHistoryAndExports(_ speech: RenderedSpeech, text: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = RecordingStore(directory: directory)
        let recording = try await store.add(wav: speech.wav, text: text,
            duration: Double(speech.sampleCount) / Double(speech.sampleRate), engine: "EMA")
        let source = store.url(for: recording)
        XCTAssertEqual(try Data(contentsOf: source), speech.wav)
        let restored = RecordingStore(directory: directory)
        XCTAssertEqual(restored.recordings.first, recording)
        try restored.rename(recording, title: "Türkçe test kaydı")
        XCTAssertEqual(RecordingStore(directory: directory).recordings.first?.title, "Türkçe test kaydı")
        let mp3 = directory.appendingPathComponent("ema.mp3")
        let mp4 = directory.appendingPathComponent("ema.mp4")
        let library = try XCTUnwrap(Bundle.main.url(forResource: "lame.all", withExtension: "js", subdirectory: "MP3"))
        let logo = Bundle.main.url(forResource: "Logo-original", withExtension: "jpg", subdirectory: "Brand")
        try await Task.detached {
            try MP3Encoder.encode(source: source, destination: mp3, library: library)
            try await CaptionVideoExporter.export(recording: recording, audioURL: source, destination: mp4, logoURL: logo) { _ in }
        }.value
        let mp3Audio = try AVAudioPlayer(contentsOf: mp3)
        XCTAssertEqual(mp3Audio.duration, recording.duration, accuracy: 0.3)
        let asset = AVURLAsset(url: mp4)
        let video = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(video.count, 1); XCTAssertEqual(audio.count, 1)
        let size = try await XCTUnwrap(video.first).load(.naturalSize)
        XCTAssertEqual(size, CGSize(width: 720, height: 1280))
        let length = try await asset.load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(length), recording.duration, accuracy: 0.3)
        let generator = AVAssetImageGenerator(asset: asset)
        _ = try generator.copyCGImage(at: .zero, actualTime: nil)
        for (url, type) in [(mp3, "public.mp3"), (mp4, "public.mpeg-4")] {
            let attachment = XCTAttachment(data: try Data(contentsOf: url), uniformTypeIdentifier: type)
            attachment.name = url.lastPathComponent; attachment.lifetime = .keepAlways; add(attachment)
        }
        // Cancellation cannot return a successful export or retain partial video frames.
        let cancelled = Task.detached {
            try Task.checkCancellation()
            try await CaptionVideoExporter.export(recording: recording, audioURL: source, destination: directory.appendingPathComponent("cancel.mp4"), logoURL: logo) { _ in }
        }
        cancelled.cancel()
        do { try await cancelled.value; XCTFail("Cancelled export must throw") } catch { XCTAssertTrue(error is CancellationError) }
        try restored.remove(recording)
        XCTAssertTrue(RecordingStore(directory: directory).recordings.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))

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
        host.frame = CGRect(x: 0, y: 0, width: 32, height: 24)
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
            host.frame = CGRect(x: 0, y: 0, width: 32, height: 24); host.layoutIfNeeded()
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
