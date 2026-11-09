# EMA Lightning iOS

[![iOS unsigned IPA](https://github.com/Ezakamak/ema-lightning-ios/actions/workflows/ios.yml/badge.svg)](https://github.com/Ezakamak/ema-lightning-ios/actions/workflows/ios.yml)

Bağımsız, Apache-2.0 lisanslı bir iOS başlangıç projesi. Herkes kaynak kodunu indirip geliştirebilir.
Independent, Apache-2.0 licensed iOS foundation, open to contributions.

**Durum / Status:** Yerel EMA/ONNX çıkarımı henüz uygulanmadı. Mevcut uygulama açıkça etiketlenmiş Apple Türkçe sistem sesi önizlemesi sunar. / Native EMA/ONNX inference is not implemented yet. The current app offers an explicitly labeled Apple Turkish system voice preview.

## Kurulum / Installation

- [Türkçe kurulum](docs/INSTALL.tr.md)
- [English installation](docs/INSTALL.en.md)
- [Architecture](docs/ARCHITECTURE.md) · [Contributing](CONTRIBUTING.md) · [Changelog](CHANGELOG.md)
- [Dependency and license audit](docs/DEPENDENCIES.md) · [Release process](docs/RELEASING.md)

Requires iOS 17+, macOS with Xcode 16+ for development. No third-party runtime packages, model downloads or API keys are required for the system voice preview. Turkish system voice availability depends on device settings.

## İndirmeler / Downloads

PRs, main commits and version tags build unsigned IPAs in [Actions](https://github.com/Ezakamak/ema-lightning-ios/actions).
Successful `vMAJOR.MINOR.PATCH` tag builds prepare a **draft** [Release](https://github.com/Ezakamak/ema-lightning-ios/releases) with an IPA, SHA-256 checksum and license bundle. A maintainer publishes it after device checks. No release has been claimed or pre-created by this README.

**Unsigned IPA doğrudan kurulmaz; önce kendi Apple kimliğinizle imzalanmalıdır. / An unsigned IPA must be signed with your own Apple identity before installation.** Building in GitHub Actions needs no signing certificate or Apple Developer secret.

## Kaynaklar ve teşekkür / Credits

- **Canberk Aslan** — original [EMA Lightning](https://github.com/canberk7/ema-lightning) and [Turkish TTS model](https://huggingface.co/canberkkkkkk/ema-lightning).
- **Özcan Çelik** — [EMA Lightning ONNX/web adaptation](https://github.com/ozcancelik/ema-lightning-web).

This is a separate iOS repository maintained under Ezakamak, with no implied endorsement by upstream authors. It does not change the original repositories. Upstream code and model binaries are not bundled in this initial native foundation. License/notice snapshots and exact reviewed revisions are recorded in [the audit](docs/DEPENDENCIES.md).

## Lisans / License

New iOS code: [Apache-2.0](LICENSE). See [NOTICE](NOTICE) and [preserved upstream notices](licenses/upstream). Third-party components retain their own licenses; an Apache-2.0 root license never replaces their copyright or license terms.
