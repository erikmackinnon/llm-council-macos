# Release Guide

This project currently ships as source-first open source on GitHub.

## Pre-release checklist

- [ ] `./bin/build-macos` succeeds
- [ ] `./bin/test-unit` succeeds
- [ ] `./bin/smoke` succeeds
- [ ] `README.md`, `BUILDING.md`, and `CHANGELOG.md` are updated
- [ ] No generated artifacts or local machine state are tracked
- [ ] No secrets or personal data are present in tracked files

## Verify repository hygiene

```bash
git status --short
git grep -n -I -E 'API_KEY|SECRET|TOKEN|BEGIN PRIVATE KEY|/Users/|@gmail.com|@icloud.com'
```

## Public history rewrite (one-time, before first public push)

Use this only when preparing the first public OSS history. It rewrites commit history.

1. Clone a fresh mirror.
2. Use `git filter-repo` to remove generated/local paths from all commits.
3. Rewrite commit author email/name if needed.
4. Force-push the sanitized history to the public repository.

Suggested path filters:

- `.build`
- `.artifacts`
- `.codex`
- `.xcodebuildmcp`
- `.agents`
- `docs/workpads`
- `docs/bootstrap`
- `docs/prompts`
- `AGENTS.md`
- `CLAUDE.md`

Do this in a throwaway clone, never in your primary local working copy.

## Tag and publish

1. Update `CHANGELOG.md`.
2. Create an annotated tag.
3. Push branch and tag.
4. Create a GitHub Release from that tag.
5. Copy changelog notes into release notes.

## Current distribution model

- Source build only.
- No notarized binaries are published yet.
- App Store packaging/signing is out of scope for this phase.
