# Privacy review — 2026-11-10

## Evidence scope

Main iOS revision: `bba657d9ccf452ae72e06f71242fa0d89976c8af`.
Also reviewed open PR #11 / `feat/central-pronunciation-sync` at
`6adc1ef` because its API already has a production route on this hostname.
A deployed API is not proof that the submitted iOS binary contains its client.
The policy explicitly distinguishes versions with this feature. The exact App Store
Connect binary and current App Privacy answers were not accessible in this review.
No app behavior, permissions, dependencies or manifest were changed.

| Finding | Source |
| --- | --- |
| Bundled EMA inference, no remote TTS | App/Infrastructure/EMASpeechEngine.swift; App/Resources/EMA/{tts.js,worker.js,bridge.js}; docs/DEPENDENCIES.md |
| Loopback only; token path; same-origin CSP | App/Infrastructure/LoopbackAssetServer.swift |
| Non-persistent WebKit | App/Infrastructure/EMASpeechEngine.swift:90 |
| Automatically stores original text/WAV/title/date/duration/engine | App/Features/Speech/SpeechViewModel.swift; App/Features/Library/RecordingStore.swift |
| Personal dictionary and preferences in UserDefaults | App/Features/Settings/{PronunciationStore,AppSettings}.swift |
| User deletion controls | App/Features/Library/LibraryView.swift; App/Features/Settings/SettingsView.swift |
| Local MP3/MP4 export; share sheet; cleanup of files >24h attempted at launch | App/Infrastructure/Export/{ExportCoordinator,MP3Encoder,CaptionVideoExporter}.swift |
| Optional Apple preview via AVSpeechSynthesizer | App/Infrastructure/SystemSpeechEngine.swift |
| Local diagnostic bridge, manually copied/shared reports | App/Resources/EMA/telemetry.js; App/Features/Speech/{EMADiagnostics,DiagnosticsPanel}.swift; Packages/SpeechCore/Sources/SpeechCore/DiagnosticTrace.swift |
| No sensitive permission descriptions; background playback/local networking | App/Resources/Info.plist; EMALightning.xcodeproj/project.pbxproj |
| Empty collected-data manifest, tracking false; UserDefaults CA92.1, timestamps C617.1 | App/Resources/PrivacyInfo.xcprivacy |
| Sync branch: read-only HTTPS, ephemeral cookie-free URLSession, public rules only | PR #11 App/Features/Settings/PronunciationSyncService.swift |
| API: IP rate limiter, no user-content insert | PR #11 cloudflare/pronunciation-api/src/index.js and migrations/0001_dictionary.sql; live settings checked via Cloudflare |
| Contact address already published | https://ekatech.net and ekatech-corporate/site/index.html:34 |

Search covered app Swift, JS, plist, project dependencies and source docs; bundled
runtime fetches load local assets. Tests/build tooling may use GitHub/Apple APIs;
those are not shipped app telemetry. No Firebase, advertising or crash SDK was
found in this source scope. This is source review, not a network capture of a
signed release. Apple system-service behavior is not independently certified.

## App Store Connect recommendation

Apple's collection definition distinguishes on-device processing from transmission
for retention beyond servicing a real-time request. Read current Apple guidance:
https://developer.apple.com/app-store/app-privacy-details/

- **Reviewed main only:** `Data Not Collected` is supported for the app's own normal
  TTS flow: local Other User Content (text), Audio Data, preferences and diagnostic
  timings do not alone constitute off-device collection. Do not select these as
  collected merely because files exist locally. Tracking: No.
- **User-selected exports:** sharing to the user's selected destination is disclosed;
  it is not automatic collection by EKATECH. Reassess any future upload-to-support flow.
- **Email support:** Email Address and Customer Support (and any voluntarily attached
  content) are processed if users contact support. Apple's optional-disclosure criteria
  may apply only if all criteria are met (infrequent, optional, user initiated, clearly
  disclosed). Do not silently assume exemption; confirm the actual support workflow.
  If disclosure is required: App Functionality, linked to the sender, no tracking.
- **PR #11 included:** verify IP rate-limiter and Cloudflare retention against the exact
  binary and infrastructure. Transient real-time request processing may be excluded;
  retained IP/security logs or metrics may require disclosure. IP classification is
  purpose-dependent: consider Other Data Types (security/IP), Diagnostics/Other
  Diagnostic Data for retained technical records, and Product Interaction if retained
  request histories measure use. Do not select Device ID or Coarse Location unless
  IP is actually used to identify devices or derive location. Purpose: App Functionality;
  linkage must be assessed from real retention and joinability, not presumed anonymous.
- Only disclose Crash Data / Performance Data if those reports are actually collected
  remotely; local diagnostics alone do not qualify. If users send reports through
  support, evaluate the optional-disclosure criteria above.

Do not finalize `Data Not Collected` for an unreviewed signed binary or retained
server-side collection. The manifest's empty list is evidence, not proof of compliance.

## Explicitly unresolved before submission

- The final release includes PR #11; its build number and Apple processing must be verified after upload.
- Exact provider/security log retention and handling of support correspondence.
  Public policy explicitly states no verified retention duration rather than inventing one.
- Delivery to the published support mailbox was not tested; no email was sent.
- Physical iPhone/iPad Safari and airplane-mode verification were not performed.
- In-app policy access is included by this integrated release in Settings.
- The existing App Store support URL (`https://speak.ekatech.net/support`) returned HTTP 404 during integration. Fix the published support page or Store metadata before a new submission. The in-app support link uses the published email address.
- Legal entity/address and jurisdiction-specific legal review were not supplied. The
  policy uses the existing EKATECH brand/contact and makes no invented legal guarantees.

## Deployment and verification result

Published 2026-11-10 as Worker `ema-lightning-privacy`, deployment
`7c0ce22675184f6bb28cb8fbcd1545ed`, from website source commit `3c7a762`.
PR: https://github.com/Ezakamak/ema-lightning-ios/pull/13 (open; not merged).
CI: https://github.com/Ezakamak/ema-lightning-ios/actions/runs/42805707864
— three web checks passed. The unrelated automatically triggered unsigned iOS
build was cancelled; no iOS build was needed.

Live GETs of `/`, `/privacy`, `/en`, `/en/privacy` and all local assets succeeded.
Live HEAD `/privacy` returned 200, HTTP returned 308 to HTTPS. Live policy HTML
matches the checked-in source byte-for-byte: all policy text, language links and
contact email are available without JavaScript. No Set-Cookie was observed.
The existing pronunciation API health check succeeded and version JSON was
unchanged byte-for-byte. DNS record and original API route ID remain unchanged.
Casino policy content is unchanged after normalizing Cloudflare's rotating email
obfuscation tokens. The separate corporate root changed concurrently during the
session; it remains accessible, and this task did not mutate its configuration.

Browser QA was not performed: the managed Sites preview instructions require
`cua_repl.js`, but no callable browser/REPL tool is exposed in this session. Per
those instructions, no alternate browser-control path or browser installation
was attempted. Responsive layout, TR/EN links and theme code were source-reviewed;
actual Safari rendering, interactive theme selection and system-theme changes
remain unverified. No claim of App Store approval is made.

## Integrated release update

PR #11 merged at `8ee71cd51f5a560de93b2fdfbb5d19d6711ebfd0` on 2026-11-10.
The next signed release includes D1 sync, offline fallback and the Settings privacy link.
PR #3 (`165b5e3`) and PR #4 (`a3adaa6`) are both ancestors of main: their diagnostics,
Studio, history and export implementations are already included. Public TR/EN policies
now identify dictionary sync as integrated. Infrastructure retention and App Privacy
answers remain separate release-review checks; no unverified disclosure was changed.
