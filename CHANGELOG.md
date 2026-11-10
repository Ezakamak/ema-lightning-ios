# Changelog

## Unreleased — reading fixes

- 158 editable pronunciation suggestions and persistent personal overrides in Settings.
- Prose/list/Markdown punctuation preparation before the unchanged Turkish normalizer.
- Original editor, history and MP4 text retained; no second voice or model download.
- Removed the extra bottom recording-count bar; live WebKit host moved into Create tab icon.
- New opening example text shared with the example action.
- Broad tests are opt-in via workflow_dispatch; this follow-up is code-only, without CI/build.

## 0.3.0 — Studio preview

- New Create, History and Settings UI, light/dark appearance, supplied logo/icon.
- Persistent local WAV/text archive, search, replay/seek, rename and deletion.
- Offline real MP3 encoding and portrait H.264/AAC MP4 with estimated phrase captions.
- System share sheet, cancellation, export validation and partial-file cleanup.
- Developer-only diagnostics by default; original real EMA engine retained.
- Complete LGPL MP3 component source, notices and replacement instructions bundled.
- Tests and icon/IPA/portable ZIP generation run in GitHub Actions.

All notable changes will be recorded here. Versions follow MAJOR.MINOR.PATCH. Entries in Unreleased are not published releases.

## Unreleased

- Real EMA Lightning ONNX model is now the default engine; Apple system voice remains an explicit alternative.
- Bundled FP32 text/sound/decoder graphs, Turkish normalizer WASM and ONNX Runtime Web 1.30.0; no CDN or first-use download.
- Worker-based cancellable CPU inference, 48 kHz native WAV playback, 1,000-character input cap and model-error reporting without silent fallback.
- Hosted iOS Simulator inference tests, offline browser tests, asset provenance hashes and IPA payload verification.
- Physical iPhone airplane-mode and listening/performance validation remain pending.

### Initial foundation

- Independent Apache-2.0 iOS foundation with SwiftUI, injectable speech engine and tested text validation.
- Apple Turkish system voice preview; native EMA/ONNX inference remains pending.
- Unsigned IPA CI for PRs/main/tags and draft GitHub Releases for successful version tags.
- Turkish/English installation, contribution guidance, architecture, dependency audit and Issue templates.
- Explicit credits to Canberk Aslan and Özcan Çelik; preserved upstream license/notice snapshots.

### Device diagnostics (0.2.0, unreleased)

- Synchronous Read receipt and independent Form button actions.
- Persistent visible WebKit host, window attachment validation, separate page/bridge handshakes.
- Twenty real-event stages, elapsed times, copy/share diagnostics and input/key/identifier redaction.
- Explicit Swift continuation cancellation, per-stage timeouts, detailed Worker/JS/ORT/WebKit/HTTP errors and actual AVAudioPlayer completion.
- Added state-machine, failure/recovery and UI regression tests. Physical iPhone/iOS 27 validation remains pending.
