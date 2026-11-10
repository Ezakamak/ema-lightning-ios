# EMA Lightning privacy website

Buildless, bilingual HTML source with local CSS/JS only. Build: `node web/privacy/scripts/build.mjs`.
CI checks use GitHub Actions per the root AGENTS.md. The integrated release adds the policy link in iOS Settings.

## Hosting and impact

Existing `speak.ekatech.net` CNAME remains `ekatech-homepage-git.pages.dev`.
Existing `speak.ekatech.net/api/v1/*` → `ema-pronunciation-api` remains untouched.
A separate `ema-lightning-privacy` module Worker serves only the following new routes:

- `speak.ekatech.net/` (exact root)
- `speak.ekatech.net/privacy*`
- `speak.ekatech.net/en*`
- `speak.ekatech.net/style.css`
- `speak.ekatech.net/preferences.js`
- `speak.ekatech.net/og.svg`
- `speak.ekatech.net/robots.txt`
- `speak.ekatech.net/sitemap.xml`

The Worker returns 404 for unrecognized paths within these prefixes. No catch-all route,
DNS edit, Pages redeployment, data binding, account/session forwarding or API proxying.
Other paths still use the existing Pages origin. This is deliberate isolation, not a
migration of that shared origin. Exact root route does not intercept API paths.

Deployment uses the connected Cloudflare API multipart module upload, with today's
compatibility date. No new CLI configuration or credentials are required. Upload
`dist/worker.mjs` as main module `worker.mjs`, no bindings, no logpush. Observability:
logs/traces enabled at 1% sampling, persistence and invocation logs disabled,
query string redaction enabled. No console logs in the handler.

Future updates: build and test through the workflow, upload the built artifact to
this same Worker, and retain the route IDs in evidence/deployment.json. Rollback:
delete only the route IDs recorded there (this restores previous Pages content),
or upload a prior reviewed Worker version. Never delete the existing API route.

## Review limits

See AUDIT.md for source revisions, privacy conclusions and App Privacy recommendations.
Theme: system by default, explicit light/dark stored in localStorage. Language: normal
HTML links, available with JS disabled. No consent banner, analytics or remote assets.

The Open Graph image is an SVG served locally; crawler support for SVG previews varies.
Real-device Safari and the exact App Store binary require separate verification.
