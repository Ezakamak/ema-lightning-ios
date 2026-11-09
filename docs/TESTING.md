# EMA inference validation

## Repeatable tests

- `python3 scripts/check-repository.py`: source packaging and SHA-256 inventory of all offline model/runtime/license files.
- `swift test --package-path Packages/SpeechCore`: Turkish Unicode/input boundary tests (macOS with Swift).
- `scripts/test-ios-integration.sh`: hosted iOS Simulator tests of the production WKWebView/loopback/worker pipeline. Actual model-generated WAV is validated for 48 kHz, duration, sample count, energy and Apple AVAudioPlayer decode; numeric Turkish normalization and cancellation/restart are checked. WAV attachments are retained in `ios-integration-results`.
- `scripts/build-unsigned-ipa.sh 0.1.0`: builds the device IPA and verifies every asset hash inside the resulting ZIP. No signing secrets needed.
- `python3 tests/test_offline_engine.py`: Linux with Python Playwright and `/usr/bin/chromium`. Starts a loopback-only asset server, blocks and records every non-loopback request, uses a fresh browser context and runs actual text/sound/decoder sessions. Saves WAVs and JSON under `build/offline-engine/`. It is not an iOS test.

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
