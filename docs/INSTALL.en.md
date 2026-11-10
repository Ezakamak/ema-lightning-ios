# English installation

## Develop and install with Xcode

1. Install Xcode 16 or newer on macOS and complete its first-launch setup.
2. Run `git clone https://github.com/Ezakamak/ema-lightning-ios.git`, then `cd ema-lightning-ios`. Check out the relevant branch when testing a PR.
3. Run `open EMALightning.xcodeproj` and select the `EMALightning` scheme.
4. Select an iOS 17+ simulator and Run. For an iPhone, choose your own Team under Signing & Capabilities and use a unique Bundle Identifier if needed. Keep personal signing changes out of shared commits.
5. Enable Developer Mode on your iPhone and complete Xcode's pairing and trust prompts. Apple's account and provisioning restrictions apply, including those for free accounts.

The default engine uses the **real EMA Lightning ONNX model**. Models, Turkish normalizer and CPU/WASM runtime are embedded in the IPA, with no first-run download. Initial synthesis loads the models and plays after the whole utterance is ready. Input is limited to 1,000 characters. Apple's system voice is a separate engine choice and is never silently used on EMA failure.

A physical iPhone airplane-mode test could not be performed here. After installation, enable airplane mode, disable Wi-Fi/Bluetooth, force-quit and cold launch the app, then synthesize with **EMA** selected. Report device/iOS and results in an Issue. See [test scope](TESTING.md).

If the optional Apple alternative lacks a Turkish voice, download one in iOS Accessibility speech/voice settings; this is not needed for EMA.

## Unsigned IPA

Open Actions → iOS unsigned IPA → a successful run → download the `unsigned-ipa` artifact. Published versions can also be downloaded from Releases. Unzip the artifact; the IPA is inside `build/`. Verify integrity:

```sh
cd build
shasum -a 256 -c SHA256SUMS
```

The IPA is unsigned and cannot be installed by tapping it in Files or AirDrop. Sign it with your own Apple identity and suitable device provisioning using a trusted tool, or build through Xcode above. Do not upload passwords, signing certificates or provisioning profiles to the repository or issues. This project does not supply a signing service.

Local unsigned build: `scripts/build-unsigned-ipa.sh 0.2.0`. Domain tests: `swift test --package-path Packages/SpeechCore`. IPA builds require macOS, Xcode and an iOS SDK; they do not run on Linux.


Live device diagnostics / Canlı cihaz tanılama: [guide](DEVICE-DIAGNOSTICS.tr.md).
