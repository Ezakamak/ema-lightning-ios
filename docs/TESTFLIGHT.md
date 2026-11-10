# TestFlight delivery

Run **EMA Lightning TestFlight upload** manually with marketing version `0.1.0`.
The workflow does not run simulator tests. It serializes uploads and defaults the
build number to `run_number.run_attempt`, so retrying creates a new build number.
An explicit build number must be unused in App Store Connect.

The existing App Store Connect record uses
`net.ekatech.ema-lightning-ios.627Y9N4Q6P`. The owner confirmed this identifier
on 2026-11-10. The Xcode app target, archive check, API preflight and upload
metadata must all match it exactly. The test target remains present.

## Authentication and signing

The four repository secrets are `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`
and `APPLE_TEAM_ID`. The private key must be complete PKCS#8 EC P-256 PEM with
real line breaks. No additional secrets are needed for the verified automatic
signing route. The API preflight validates syntax and signs a five-minute ES256
JWT with a raw IEEE-P1363 signature. Neither JWT nor response bodies are logged.
It checks apps, profiles, distribution certificate access, and exact app and
Bundle ID equality before compiling. HTTP 200 alone is insufficient: the
response must contain the exact identifier.

Use a **Team API Key**. Individual keys use `sub: user` rather than `iss` and do
not support provisioning endpoints. A 401 cannot distinguish a mismatched
Key ID/private key pair from an incorrect issuer, revoked key or account issue.
A 403 indicates a permission failure; network errors, 429 and 5xx are reported
separately. API read permissions do not establish cloud signing permissions.

The workflow uses `macos-26`, Xcode 26.5, Release configuration, automatic
provisioning and `app-store-connect` export. The team comes from the existing
secret. Xcode creates/uses the development identity for archive and cloud-managed
distribution signing for export. Successful development archive does not prove
that a distribution certificate/profile can be used. Cloud signing was verified
by a successful signed IPA export on 2026-11-10.

The `.p8` API key is **not** an Apple Distribution signing private key. If cloud
signing becomes unavailable, inspect the key role and additional cloud-managed
certificate permissions in App Store Connect Users and Access. Manual signing
requires a distribution certificate **and its matching private key**, an App
Store profile for this exact app/team, an ephemeral unlocked runner keychain,
and manual export certificate/profile mappings. None is assumed to exist here.
The signing key can be generated securely on the machine creating the CSR; an
existing certificate's key must be obtained from its original keychain or secure
backup. A downloaded `.cer` alone cannot recover it. Never commit any such keys.

## Upload and recovery

The preflight resolves the numeric Apple app ID and passes it explicitly to
`altool --upload-package` with bundle ID, version and build number. The Xcode
runner's `altool --help` is printed to verify supported options. Private key files
live outside the checkout with restrictive permissions and are removed even on
failure. Signed IPAs are retained for one day to allow upload recovery without
recompiling. Artifacts never contain API private keys.

A successful upload command means Apple accepted delivery. Apple processing and
tester availability are separate. Run **Apple API credential check** with the
uploaded build number to inspect its processing state without rebuilding.
`VALID` confirms processing; export compliance, beta review and tester/group
assignment can still affect availability. Any failed export/upload fails the
workflow; no success summary is written for those stages.

## Incident evidence (2026-11-10)

- [#1](https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42766249925)
  and [#3](https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42769042387):
  `CryptoKitASN1Error.invalidPEMDocument`, before archive.
- [#2](https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42767868791):
  archive succeeded with Apple Development identity, export failed with cloud
  signing permission error and missing distribution profile.
- [#4](https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42769342057):
  `listTeams` HTTP 401, then missing development profile. This is a different
  authentication failure; the old logs do not prove which credential was wrong.
- [Updated-secret preflight](https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42777415980):
  valid PEM, apps 200, profiles 200. PR #8 was inspected, merged and run.
- [Automatic signing verification](https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42777459175):
  archive and export succeeded; upload failed because the original bundle ID
  could not be resolved to an Apple app ID.
- [Exact identifier check](https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42777860444):
  API responses contained the suffixed identifier, not the original identifier.
- [Corrected identifier preflight](https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42777930505):
  authentication, provisioning, certificate access and exact identifiers passed.

## Apple references checked

- [Current SDK requirements](https://developer.apple.com/news/upcoming-requirements/):
  since April 28, 2026, Xcode 26+ and iOS 26+ SDK; Xcode 26.5 satisfies this.
- [JWT generation](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests)
- [API keys and roles](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [Cloud-managed certificates](https://developer.apple.com/help/account/certificates/cloud-managed-certificates/)
- [Supported upload tools](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/):
  altool remains supported for iOS uploads. Its macOS notarization deprecation
  does not apply to iOS delivery; the current CLI prefers `--upload-package`.

## App bundle validation

The first correctly addressed upload reached Apple's validator and reported
90474 (missing orientations), 90022/90023 (missing iPhone/iPad icons), and 90713
(missing icon catalog name). The app now includes original opaque original red crescent/microphone icons at all iPhone/iPad/marketing sizes, an `AppIcon` asset catalog
registered in the Xcode resource phase, and all four supported orientations.
Repository checks verify those source requirements without simulator tests.


## Current Studio and original icon

Build 10.1 used the previous main interface. The owner subsequently approved
including the current Studio source from PR #4 (`a3adaa68`) and restoring the
supplied red icon. The original JPEG is tracked unchanged at
`App/Resources/Brand/Logo-original.jpg`. Run `python3 scripts/generate-app-icons.py`
with Pillow installed to regenerate all opaque PNG sizes in
`App/Assets.xcassets/AppIcon.appiconset`. The full original artwork and aspect
ratio are preserved. Generated assets are committed; Actions verifies them
before archive. The Studio Create/History/Settings, MP3/MP4 export and pronunciation
features are included, with the working App Store identity and signing workflow.
No simulator test jobs are reintroduced. Marketing version remains `0.1.0`.
