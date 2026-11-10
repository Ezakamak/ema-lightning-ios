# Dependency and license audit

Audit date: 2026-11-09. Scope: this initial native iOS foundation. No third-party runtime dependency, model, font, JavaScript, WASM or ONNX binary is shipped. SpeechCore is first-party local source. There are no remote Swift Package, CocoaPods or Carthage dependencies.

| Included component | Terms / compatibility | Evidence / obligation |
| --- | --- | --- |
| New app and SpeechCore source | Apache-2.0 | Root LICENSE; app bundles LICENSE.txt and NOTICE.txt |
| Apple SwiftUI, Combine, Foundation, AVFoundation | Apple SDK/platform terms; not relicensed as Apache | Linked from iOS SDK; follow Apple development and distribution terms |
| Upstream notice snapshots only | Apache-2.0 and embedded notices retained verbatim | licenses/upstream; no upstream executable code copied |

## Reviewed upstream sources (not bundled)

| Source | Reviewed revision | Finding |
| --- | --- | --- |
| canberk7/ema-lightning | 68f54a187db55bfab119889ee27d14a384d8959b | Root Apache-2.0; no root NOTICE in reviewed tree |
| ozcancelik/ema-lightning-web | a9a688b19badc36486cdc2444ba957bc63ac860e | Root Apache-2.0 with NOTICE; ONNX conversions, normalizer WASM and additional third-party notices |

The exact LICENSE files, web NOTICE and normalizer third-party notices are preserved under `licenses/upstream/`. These files describe upstream distributions; they are not a claim that their assets are in this IPA. Model Apache-2.0 is reported by upstream README/NOTICE; model artifacts and their separate model-card revision have not been independently audited for inclusion.

Apache-2.0 source can be incorporated into this Apache-2.0 project while preserving LICENSE, relevant NOTICE and copyright/patent/attribution notices, and marking modified files. A future MIT runtime can coexist with Apache-2.0 provided its full MIT copyright/license notices and those of bundled transitives are retained. The web project's normalizer WASM includes Rust dependencies and Unicode notices; those must be audited at the actual binary revision. The upstream OFL font is not used. None of these potential future components is approved for bundling by this initial audit.

## Build tooling (not linked into the app)

GitHub Actions checkout, upload-artifact and download-artifact are MIT-licensed tooling pinned to immutable commit IDs in `.github/workflows/ios.yml`. Their dependencies execute on hosted runners rather than being redistributed in the app. Apple Xcode/SDK, GitHub CLI and runner tooling remain under their respective vendor terms. No downloaded third-party build tool is vendored by this repository.

## Required for dependency changes

Record exact version/commit, source URL, SPDX license expression, transitive components and distribution form here. Read the upstream license/NOTICE, retain complete relevant text and copyright headers, mark modifications, and update app resources and the release license bundle when shipping a component. Reject unknown terms until resolved. Code and model licenses must be checked separately. Re-run the audit whenever dependencies or model hashes change; the current review is not a blanket guarantee for future releases.
