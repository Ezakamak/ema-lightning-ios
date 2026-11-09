# Releases

1. Merge reviewed changes to main after the iOS workflow passes. Confirm that the release accurately describes the current engine. Update the changelog and release notes through a PR.
2. Smoke-test on a physical iPhone: Turkish text, empty/long input, stop, background/foreground and voice-unavailable handling. Recheck the license inventory and any new binary/model provenance.
3. Tag the reviewed main commit with a new `vMAJOR.MINOR.PATCH`, for example `git tag -a v0.1.0 -m 'Release 0.1.0'` followed by `git push origin v0.1.0`. Never move a published tag.
4. CI runs domain tests and creates an arm64 unsigned archive/IPA. A release job verifies that the tag commit is contained in main, verifies SHA256SUMS, then creates a **draft** Release containing the IPA, checksums and license bundle. Failed builds cannot reach that job.
5. Review the draft, add changelog highlights and device test results, and publish it in GitHub Releases. Drafts are not publicly downloadable; Actions artifacts expire after 30 days. Published release assets remain available according to repository retention/access.

No signing secrets are needed. The release job alone gets contents:write. The workflow does not merge PRs or publish drafts automatically. Re-running an already-created tag release fails rather than replacing assets; inspect and manage the existing draft explicitly, or use a new version if code changed.

For manual Actions runs use main or a review branch; manual runs build artifacts but do not create a release. The first release should remain a clearly described foundation/preview until native EMA integration and device validation are complete.
