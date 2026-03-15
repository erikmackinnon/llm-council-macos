# Building llm-council-macos (LLM Council for macOS)

## Prerequisites

- macOS 14+
- Xcode 16+
- Command line developer tools (`xcode-select --install`)
- `jq` available on `PATH`

Optional:

- `xcbeautify` for cleaner `xcodebuild` output
- `swiftformat` and `swiftlint` for `bin/format` and `bin/lint`

## Quick Start

```bash
./bin/bootstrap
./bin/build-macos
```

## Run Tests

```bash
./bin/test-unit
./bin/smoke
```

UI tests:

```bash
./bin/test-ui
```

## Notes

- `./bin/bootstrap` generates local files under `.codex/` and `.xcodebuildmcp/`.
- Those generated files are local-only and intentionally not tracked in git.
- Repository scripts default to unsigned builds for contributor portability:
  - `CODE_SIGNING_ALLOWED=NO`
  - `CODE_SIGNING_REQUIRED=NO`
  - `CODE_SIGN_IDENTITY=-`
- Override those vars if you need signed local builds.
- In restricted environments, test commands may require elevated execution privileges to communicate with `com.apple.testmanagerd.control`.
- If Xcode requires signing for running the app/tests, set your own local signing team in Xcode project settings.

## Useful Commands

- Build iOS target: `./bin/build-ios`
- Lint: `./bin/lint`
- Format: `./bin/format`
- Dead code scan: `./bin/deadcode`
- XCResult summary: `./bin/xcresult-summary`
- Coverage summary: `./bin/coverage-summary`
