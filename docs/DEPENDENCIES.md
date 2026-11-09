# Dependency and license audit

Audit date: 2026-11-09. Scope: the actual bundled EMA CPU/WASM engine. Root Apache-2.0 applies to new iOS code; third-party terms remain intact. Model, runtime and normalizer are shipped **inside the IPA**, with no CDN or first-run download.

| Included component | Revision / version | License and compatibility |
| --- | --- | --- |
| New Swift/bridge/worker code and SpeechCore | This repository | Apache-2.0 |
| EMA ONNX text/sound/decoder, meta.json | ozcancelik/ema-lightning-web a9a688b19badc36486cdc2444ba957bc63ac860e | Apache-2.0; unmodified converted model graphs; original model by Canberk Aslan |
| tts.js, normalizer.js | Same web revision | Apache-2.0; tts.js prominently marks the change to bundled CPU-only assets; normalizer.js unchanged |
| EMA original model card | Hugging Face e7c96f2fc0ba843cd0f86e02786655bb56f50df8 | Declares Apache-2.0; card preserved in app. ONNX provenance is the web export revision above |
| normalizer.wasm | Same web revision; built upstream from normalizer-tr d0bc1bc6523faa4f6257642190bb723b7f4274a5 | Apache-2.0 plus permissive Rust/Unicode dependencies; upstream NOTICE and dependency license texts retained |
| ONNX Runtime Web | npm 1.30.0; source f2c39fe2f838cf35ce7da92824f5a5e3ee6e88a7 | MIT plus third-party notices; complete MIT text and upstream ThirdPartyNotices.txt included |
| Apple WebKit, Network, AVFoundation, SwiftUI and Foundation | iOS SDK | Apple platform terms; linked system frameworks are not relicensed as Apache |

The runtime package's SHA-512 npm integrity, source revisions and SHA-256/size of **every** bundled asset are recorded in `App/Resources/EMA/ASSETS.json`. `scripts/check-repository.py` validates this inventory; `scripts/verify-ipa.py` verifies the same bytes in the packaged IPA. The runtime's plain CPU build includes only `ort.wasm.min.mjs`, `ort-wasm-simd-threaded.mjs` and `ort-wasm-simd-threaded.wasm` (configured with one thread). No WebGPU, JSEP, CDN, font or web UI assets are included.

## Preserved terms

- `App/Resources/EMA/licenses/` ships original EMA/web/normalizer license and notice texts, the model card and ONNX Runtime MIT/third-party texts.
- `normalizer-dependencies/` retains the upstream normalizer's full published dependency-license archive, including Rust standard-library notices. Some entries concern optional Python/build dependencies, which are not runtime components of this WASM; preserving the archive does not imply those packages are linked. The core dependencies and Unicode terms are enumerated in `normalizer-tr-THIRD_PARTY_NOTICES.md`.
- Core normalizer dependencies offer Apache-2.0 or MIT choices; tinyvec additionally offers Zlib, and Unicode data has Unicode-3.0 terms. These permissive terms can coexist with Apache-2.0 while retaining notices. Optional LGPL alternatives are not selected; no GPL/LGPL runtime was added.
- Root NOTICE identifies actual included works and modifications. Both root LICENSE/NOTICE and full EMA license assets are copied into the app and release license archive.

Source evidence: [web export](https://github.com/ozcancelik/ema-lightning-web/tree/a9a688b19badc36486cdc2444ba957bc63ac860e), [normalizer](https://github.com/erdemtuna/normalizer-tr/tree/d0bc1bc6523faa4f6257642190bb723b7f4274a5), [runtime](https://github.com/microsoft/onnxruntime/tree/v1.30.0), [model card](https://huggingface.co/canberkkkkkk/ema-lightning/tree/e7c96f2fc0ba843cd0f86e02786655bb56f50df8).

## Build/test tooling

GitHub checkout/upload/download Actions are MIT-licensed tooling pinned to immutable commits. Xcode and GitHub runner/CLI tooling remain under their respective terms. The local Python Playwright test uses installed Playwright (Apache-2.0) and Chromium (BSD and third-party terms); neither is redistributed in the app. The iOS integration test runs Apple's simulator/WebKit and the same bundled engine used by the app.

For any dependency update: review source and binary terms separately, retain complete relevant license/copyright/NOTICE text, mark source modifications, update provenance/hashes and rerun engine + IPA checks. This is a scoped review of the checked-in distribution, not a blanket approval of future dependencies or a claim that a converted model exactly matches the latest upstream model.
