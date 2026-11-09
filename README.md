# EMA Lightning iOS

[![iOS unsigned IPA](https://github.com/Ezakamak/ema-lightning-ios/actions/workflows/ios.yml/badge.svg)](https://github.com/Ezakamak/ema-lightning-ios/actions/workflows/ios.yml)

Bağımsız, Apache-2.0 lisanslı bir iOS başlangıç projesi. Herkes kaynak kodunu indirip geliştirebilir.
Independent, Apache-2.0 licensed iOS foundation, open to contributions.

**Durum / Status:** Varsayılan motor artık paketlenmiş gerçek EMA ONNX modelidir. Türkçe normalizer ve CPU/WASM çalışma zamanı IPA içindedir; ilk kullanımda indirme yapılmaz. Apple sistem sesi yalnızca seçilebilir alternatiftir. / The default engine now runs the bundled real EMA ONNX model with a bundled Turkish normalizer and CPU/WASM runtime. Apple's system voice is an explicit alternative.

**Doğrulama sınırı / Validation limit:** Fiziksel iPhone uçak modu testi henüz yapılmadı. Bu sürüm cihazda doğrulanmış bitmiş ürün olarak sunulmaz. / Physical iPhone airplane-mode testing remains pending; this is not a device-verified finished release. See [test evidence and gaps](docs/TESTING.md).

## Studio 0.3.0

Oluştur · Geçmiş · Ayarlar; yerel kayıt arşivi, MP3 ve ilerleyen metinli MP4
paylaşımı, varsayılan kapalı Geliştirici Modu. / Create, local history, MP3 and
caption-video export, and opt-in developer diagnostics.

[Studio kullanımı (TR)](docs/STUDIO.tr.md) · [Studio guide (EN)](docs/STUDIO.en.md)
MP4 metin zamanlaması yaklaşıktır; kesin kelime hizalaması değildir.
MP3 encoder: separate LGPL-3.0 lamejs; application code remains Apache-2.0.

## Kurulum / Installation

- [Türkçe kurulum](docs/INSTALL.tr.md)
- [English installation](docs/INSTALL.en.md)
- [Architecture](docs/ARCHITECTURE.md) · [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)
- [Dependency and license audit](docs/DEPENDENCIES.md) · [Release process](docs/RELEASING.md)

Requires iOS 17+, macOS with Xcode 16+ for development. The IPA includes all model/runtime assets and needs no API key or model download. EMA runs with ONNX Runtime Web/WASM inside WKWebView using an app-local loopback asset server. Turkish system voice availability affects only the optional Apple alternative.

## İndirmeler / Downloads

PRs, main commits and version tags build unsigned IPAs in [Actions](https://github.com/Ezakamak/ema-lightning-ios/actions).
Successful `vMAJOR.MINOR.PATCH` tag builds prepare a **draft** [Release](https://github.com/Ezakamak/ema-lightning-ios/releases) with an IPA, SHA-256 checksum and license bundle. A maintainer publishes it after device checks. No release has been claimed or pre-created by this README.

**Unsigned IPA doğrudan kurulmaz; önce kendi Apple kimliğinizle imzalanmalıdır. / An unsigned IPA must be signed with your own Apple identity before installation.** Building in GitHub Actions needs no signing certificate or Apple Developer secret.

## Kaynaklar ve teşekkür / Credits

- **Canberk Aslan** — original [EMA Lightning](https://github.com/canberk7/ema-lightning) and [Turkish TTS model](https://huggingface.co/canberkkkkkk/ema-lightning).
- **Özcan Çelik** — [EMA Lightning ONNX/web adaptation](https://github.com/ozcancelik/ema-lightning-web).

This is a separate iOS repository maintained under Ezakamak, with no implied endorsement by upstream authors. It does not change the original repositories. The actual ONNX graphs, Turkish normalizer, adapted inference code and runtime are bundled with their licenses and notices. Exact reviewed revisions and SHA-256 inventory are recorded in [the audit](docs/DEPENDENCIES.md).

## Lisans / License

New iOS code: [Apache-2.0](LICENSE). See [NOTICE](NOTICE) and [preserved upstream notices](licenses/upstream). Third-party components retain their own licenses; an Apache-2.0 root license never replaces their copyright or license terms.
