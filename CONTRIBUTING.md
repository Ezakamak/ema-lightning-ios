# Contributing / Katkı rehberi

Türkçe ve İngilizce Issue/PR kabul edilir. Turkish and English contributions are welcome.
Read [installation](docs/INSTALL.en.md), [mimari](docs/ARCHITECTURE.md) and the [license audit](docs/DEPENDENCIES.md) first.

1. Fork this repository, or create a feature branch if you have write access. Do not develop in the original EMA Lightning repository for changes to this iOS app.
2. Keep changes focused and explain the user-visible behavior. Discuss large model/runtime changes in an Issue first.
3. Run `swift test --package-path Packages/SpeechCore`, `python3 scripts/check-repository.py` and an unsigned build on macOS. For UI/audio changes, check a simulator and an actual iPhone when available. Describe what you could and could not test.
4. Update both installation guides if setup changes, CHANGELOG.md for user-facing changes, and the dependency audit/notices for any new code, model, binary or font.
5. Open a Pull Request against `main`. CI must pass. Maintainers review and merge; release tags are created from main after review.

## Honest authorship / Gerçek yazar bilgileri

Use your existing real name or established GitHub identity and a verified email or your account's GitHub-provided no-reply address. Check `git var GIT_AUTHOR_IDENT` and `git config --show-origin --get-regexp 'user\.'` before committing. Configure this repository with `git config --local user.name 'YOUR EXISTING NAME'` and `git config --local user.email 'YOUR VERIFIED EMAIL'`; replace the examples with your own values. Never copy another contributor's identity, fabricate co-authors, backdate commits or import upstream work as your own. Imported code must keep authorship/provenance and notices. GitHub associates contributions by email and its branch/contribution rules; a feature branch alone may not appear on the contribution graph until merged.

## License and conduct

Contributions are provided under Apache-2.0 unless an explicitly retained compatible upstream license applies. Preserve original copyright/license/NOTICE text and prominently mark modified upstream files. Do not submit secrets, signing materials or code/assets whose redistribution rights are unknown. Treat contributors respectfully, give actionable feedback and report reproducible issues. There is no CLA or invented attribution requirement.
