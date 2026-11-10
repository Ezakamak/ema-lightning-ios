# EMA Lightning pronunciation service

Production: https://speak.ekatech.net/api/v1

Only dictionary distribution happens here. ONNX inference, WASM, normalizer, Apple voice,
recordings, MP3 and MP4 exports remain on the device. No account or payment is required.

## API contract (schema 1)

- `GET /api/v1/health`: `{ "status": "ok" }`, liveness only, no resource identifiers.
- `GET /api/v1/pronunciations/version`: `version`, `schemaVersion`, `locale`, `ruleCount`,
  `updatedAt` (UTC ISO8601), `checksum`.
- `GET /api/v1/pronunciations`: same metadata plus `rules` with `word`, `pronunciation`,
  `category`, `normalizedWord`. iOS ignores `normalizedWord` and computes its existing key.
- HEAD and same-origin OPTIONS are supported; write methods return 405 with Allow.
- Unknown paths: 404; query/body: 400; disallowed browser origins: 403;
  rate limit: 429 + Retry-After; unavailable/empty/invalid D1 snapshot: 503 + Retry-After.
- Full dictionary and metadata have distinct strong ETags. If-None-Match accepts matching
  strong/weak tags, lists and `*`, returning a bodyless 304.
- Maximum decoded response: 1 MiB, maximum 5,000 rules, no empty publication.
- Browser response uses `Cache-Control: no-cache` (store but revalidate) and CDN no-store;
  internal Cache API entries use public max-age=300. This avoids the existing zone's
  four-hour minimum browser TTL without modifying shared settings. Canonical cache keys
  exclude query strings and client headers. Errors aren't cached. Old edges may serve
  a previous coherent version for five minutes; iOS rejects mismatched version/full pairs.

## Schema and publication

`dictionary_metadata` is an append-only snapshot history keyed by version. Its payload
contains validated rules and checksum. A single INSERT computes the next version in
SQLite and skips publication when the latest checksum matches. An AFTER INSERT trigger
adds indexed `pronunciations` rows within the same statement transaction. A failing trigger
rolls back the publication. Readers query one latest snapshot row (indexed primary key),
so metadata and rules cannot come from separate transactions. Old versions/rules are retained.
A later reversion to an older content hash intentionally receives a new version.

`pronunciations` retains id, word, normalized_word, pronunciation, category, locale, enabled,
created_at, updated_at and revision, unique on `(revision, locale, normalized_word)`.
The importer currently publishes enabled rules only. To retire a central rule, remove it
from the reviewed source; older snapshots remain. A bundled rule still exists as fallback.

Normalization matches `SpeechCore.PronunciationRule.key`: NFC; if the word contains any
of çğıöşüÇĞÖŞÜ, use explicit `tr-TR` lowercasing, otherwise replace İ with I then explicit
English lowercasing for brand compatibility. This deliberately preserves existing I/İ brand
semantics. Do not replace it with generic SQLite LOWER or JavaScript default lowercasing.

Checksum is SHA-256 over UTF-8 canonical text: each rule becomes lowercase UTF-8 hex of
`normalized key:word:pronunciation:category` (each field individually hex encoded), lines
sorted by ASCII and joined with LF, without a trailing LF. Swift and JS share fixtures.
It detects corruption; HTTPS supplies transport authenticity.

## Local development and import

Node 22+; use the committed lockfile:

```sh
cd cloudflare/pronunciation-api
npm ci
npm test
npm run seed
npx wrangler d1 migrations apply ema_pronunciations --local
npx wrangler d1 execute ema_pronunciations --local --file seed.sql
npx wrangler d1 execute ema_pronunciations --local --file seed.sql
npm run dev
```

Tests use isolated Miniflare D1, real Worker fetch, the actual bundled 158 rules, and
mock failures/cache. The installed workerd binary supports dates through 2026-08-06,
so local tests explicitly use that date; production retains 2026-11-10. Live smoke
checks validate production runtime behavior. Test-only rules never go to production.
`seed.sql`, node_modules and local state are gitignored. The packaged JSON stays in iOS.

## Authorized production deployment / updates

Authenticate Wrangler with a narrowly scoped account token (D1 Edit, Workers Scripts Edit,
Workers Routes Edit for the named zone) via protected environment/CI secrets. No admin
credentials belong in source, command arguments, logs or IPA. This delivery used the
connected Cloudflare app identity; local Wrangler does not automatically inherit it.
Verify `wrangler whoami`, target account, D1 UUID and route before running:

```sh
npm test
npm run seed
npx wrangler d1 migrations apply ema_pronunciations --remote
npx wrangler d1 execute ema_pronunciations --remote --file seed.sql
npx wrangler deploy --dry-run
npm run deploy
node scripts/smoke.js
```

Review source changes before import. Repeating identical import does not create revisions.
Migrations are additive and contain no DROP/DELETE. Never point these commands at another
D1 database. Workers have no public management endpoint. Token access is the administration
boundary. CI checks do not contain deployment credentials or automatically publish changes.

## Resource and route isolation

Account f675233e9a1e54a261896105ebb7f6c9; D1 ema_pronunciations
(5c9f50f3-97c7-4a19-9791-7344bda006d3); Worker ema-pronunciation-api; binding DB.
Rate-limit namespace 1001 is reserved for this Worker in this account; existing Worker binding inventory showed no collision (60 requests per IP per minute per location).
It is an approximate abuse limit, not a billing/security quota; IPs are never written to D1.

The pre-existing proxied CNAME points to ekatech-homepage-git.pages.dev and the Pages
custom domain is active. Only `speak.ekatech.net/api/v1/*` is routed to this Worker.
The root continues to be served by existing Pages and remains available for a future EMA
web app. No Pages project, DNS record, shared zone setting, Casino resource or existing
D1/DO/R2 was modified. Moving the root to a future separate web project requires its own
reviewed domain migration; this task does not move that shared Pages binding.

Universal wildcard SSL is active. Live evidence is in `evidence/live-smoke.json`.
Do not intentionally break production D1 to test 503: that path is tested in isolation.

## iOS synchronization and offline behavior

`PronunciationSyncService` starts with a validated Application Support snapshot, or the
unchanged bundled dictionary. Startup and inference never await networking. App startup
and foreground activation check when due (24h after success); manual check bypasses the
interval. A main-actor single-flight guard coalesces concurrent requests. Failure backoff
starts at 5 minutes and doubles to 24h, persisted across launches. URLSession is ephemeral,
without cookies/cache, 15s request / 30s resource timeout, no connectivity waiting.

Only GET version/full requests are made. Metadata uses If-None-Match. Same versions never
redownload rules. Downloads are streamed with a byte cap, staged in a protected temporary file, decoded, validated for schema,
locale, counts, duplicate normalized keys, rule syntax, checksum and monotonic version.
Metadata/full mismatches are retried later. Validated data is atomically written with
completeUntilFirstUserAuthentication protection and excluded from backup. Failed/partial
writes keep the old file. Corrupt cache restores bundled fallback and forces fresh checking.

Priority: personal > central > bundled. A disabled personal entry remains a tombstone for
both lower layers; removing it reveals the central/bundled rule. The existing ready-list
toggle controls both central and bundled sources. Personal UserDefaults storage is unchanged.
The engine already copies effectiveRules before its first await, so a sync cannot mutate
an in-flight synthesis. Next requests read the new snapshot.

Offline first install, airplane mode, DNS failure, timeout, Worker/D1 outage, malformed JSON,
interrupted download and unsupported schema keep synthesis available. UI uses inline status,
version, publication date, last successful check, rule count and a manual check button.

## Privacy and operational logs

No user text, recordings or personal rules are transmitted. No tracking/advertising SDK,
user identifier or analytics event was added. URLSession sends ordinary HTTPS connection
metadata; Cloudflare sees source IP, request URL, time and standard HTTP/TLS headers.
The limiter uses IP transiently; it is not stored in application records. Worker code logs
no request body, headers, IP or secrets. Invocation logs are disabled; logs/traces have
persistence disabled, 1% sampling, query-string redaction, no Logpush destination.

Cloudflare's underlying security, NEL (observed on the hostname), aggregate metrics and
provider operational processing remain subject to the account/provider policy. This task
cannot promise zero provider retention or change the shared zone's logging policy. The
normal Workers Logs/Traces retention would be seven days if persistence were enabled:
https://developers.cloudflare.com/workers/observability/logs/workers-logs/
https://developers.cloudflare.com/workers/observability/traces/

The existing PrivacyInfo.xcprivacy declares no collected data and no tracking. No new
required-reason API category was added. Update the public privacy notice to disclose the
optional dictionary connection/technical metadata; confirm App Store Connect answers against
actual provider retention/access and Apple's current definition before the next release.
This implementation does not itself create analytics or persist device/IP identifiers.

## Validation limitations

Swift tests simulate the network with URLProtocol on an iOS simulator through the separate
GitHub Actions dictionary workflow, plus existing SpeechCore tests. These are independent
of TestFlight, which was not changed. Physical iPhone testing, actual airplane mode, audible
ONNX quality, export regressions and battery behavior require a real device. Mock rule
snapshots verify request isolation; they are not a replacement for on-device synthesis.
