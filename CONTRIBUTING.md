# Contributing

Thanks for contributing to LLM Council.

## Before You Start

- Search existing issues before opening a new one.
- Keep changes narrow and focused.
- For visible UI changes, include a screenshot or short video in your PR.

## Local Setup

```bash
./bin/bootstrap
./bin/build-macos
./bin/test-unit
```

## Pull Request Checklist

- [ ] Build passes (`./bin/build-macos`)
- [ ] Relevant tests pass (`./bin/test-unit` and/or `./bin/test-ui`)
- [ ] Behavior changes are covered by tests where practical
- [ ] Documentation updated when behavior or workflows changed
- [ ] No generated artifacts, local configs, or secrets added

## Coding Guidelines

- Prefer small, reviewable PRs.
- Keep provider automation changes isolated and defensive.
- Avoid introducing provider-specific assumptions into shared workspace logic.

## Security

Do not open public issues for exploitable vulnerabilities. Follow [SECURITY.md](SECURITY.md).
