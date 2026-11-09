> Maintainer preference: test/build/package operations run in GitHub Actions.
> Full package and simulator tests are now opt-in with workflow_dispatch → run_tests.
> The pronunciation/UI follow-up is committed with CI skipped: no test or build
> result is claimed for it. The previous Studio run built successfully but its
> iOS job was cancelled at the maintainer's request.

# EMA inference validation

## Repeatable tests

- `python3 scripts/check-repository.py`: source packaging and SHA-256 inventory of all offline model/runtime/license files.
- `swift test --package-path Packages/SpeechCore`: Turkish Unicode/input boundary tests (macOS with Swift).
- `scripts/test-ios-integration.sh`: hosted iOS Simulator tests of the production WKWebView/loopback/worker pipeline. Actual model-generated WAV is validated for 48 kHz, duration, sample count, energy and Apple AVAudioPlayer decode; numeric Turkish normalization and cancellation/restart are checked. WAV attachments are retained in `ios-integration-results`.
- `scripts/build-unsigned-ipa.sh 0.1.0`: builds the device IPA and verifies every asset hash inside the resulting ZIP. No signing secrets needed.
- `python3 tests/test_offline_engine.py`: Linux with Python Playwright and `/usr/bin/chromium`. Starts a loopback-only asset server, blocks and records every non-loopback request, uses a fresh browser context and runs actual text/sound/decoder sessions. Saves WAVs and JSON under `build/offline-engine/`. It is not an iOS test.

## Simulator compatibility note

The Xcode 16.4 / iOS 18.5 simulator failed before running any tests because of missing `libswiftWebKit.dylib`, matching [WebKit bug 293831](https://bugs.webkit.org/show_bug.cgi?id=293831). The integration test command applies the documented `IPHONEOS_DEPLOYMENT_TARGET=18.4` workaround **only to simulator test builds**. Device IPA archives still target iOS 17. This simulator run therefore does not establish iOS 17 device compatibility. No tests are skipped to apply this workaround. The simulator is booted explicitly, tests launch without attaching a debugger and simulator binaries use ad-hoc signing (no Apple identity/certificate). This avoids an observed hosted-runner stall waiting for the debugger before any test started. Device archives remain unsigned. The hosted test job uses GitHub’s supported `macos-15-intel` image to separate simulator launch behavior from the ARM runner stalls observed in earlier attempts; the device build job still produces ARM64 iOS archives.

## Observed locally (2026-11-09)

Real packaged FP32 ONNX models + normalizer + Runtime Web 1.30.0 produced:

| Input | Audio samples / 48 kHz | RMS | Normalization |
| --- | --- | --- | --- |
| Merhaba dünya. | 42,240 (0.88 s) | 0.0603 | merhaba dünya. |
| Saat 14:30, fiyat 125 TL. İstanbul ve Iğdır. | 209,280 (4.36 s) | 0.0593 | saat on dört otuz, fiyat yüz yirmi beş türk lirası. istanbul ve ığdır. |
| Çağrı, güzel bir öğleden sonra görüşürüz! | 109,440 (2.28 s) | 0.0751 | çağrı, güzel bir öğleden sonra görüşürüz! |

All outputs were finite, non-silent mono PCM16 WAV at 48 kHz. No non-loopback request occurred; cold start did not use downloaded/cached browser assets. Cancellation rejected the active request and a fresh worker produced audio afterward. These checks validate inference and waveform structure, not perceptual quality or bit identity with Python's different random generator.

GitHub iOS test/build results are recorded in the PR and Actions run. A green run is required before the new IPA is described as built successfully; this file alone is not proof of a CI result.

## Not performed here

No physical iPhone is attached. Real airplane-mode cold launch/playback, listening-based intelligibility/voice comparisons, Bluetooth/headphone interruptions, device memory/thermal/battery measurements and extended stress tests have not been performed. The simulator cannot substitute for these checks. Do not report this as a device-verified finished product.

## Physical-device acceptance checklist

1. Sign/install the new IPA, choose EMA (default), enable airplane mode and disable Wi-Fi/Bluetooth explicitly. Force-quit and cold launch; no prior model download should be needed.
2. Read the three phrases above; confirm Canberk's EMA voice rather than the Apple system voice. Repeat with numbers, dates, currency, Turkish characters and punctuation.
3. Stop during model loading, synthesis and playback; start again. Switch to the explicitly labeled Apple alternative and back.
4. Background/foreground the app, test missing/system voices, incoming audio interruptions and a 1,000-character text. Record device, iOS, peak memory, first-audio time and any termination.
5. Attach results to the PR before publishing a stable release; retain unsuccessful cases as well.

## Live diagnostics regression suite (0.2.0)

Core tests exercise all 20 stage transitions, measured durations, cancellation, first-failure retention, stale request rejection and report redaction. Hosted integration tests retain actual ONNX synthesis and add synchronous ViewModel receipt/error recovery, an unattached WebView deadline, Worker script/constructor errors, absent ready handshake, unresolved promise and bridge timeout cases. UI tests tap the actual production Read control and reproduce the old automatic Form row in a DEBUG-only fixture. The fixture workers generate errors or no reply; they never generate substitute audio, and production does not select them.

The final CI run and IPA link are recorded in the diagnostics PR. Physical iPhone 15 Pro Max / iOS 27 validation is pending. See [Turkish device diagnostics guide](DEVICE-DIAGNOSTICS.tr.md).
