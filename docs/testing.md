# Testing

## Verification commands
- bootstrap: `./bin/bootstrap`
- primary build: `./bin/build-macos`
- unit tests (macOS destination): `./bin/test-unit`
- UI tests (macOS destination): `./bin/test-ui`
- smoke pass: `./bin/smoke`
- note: in constrained sandboxes, test commands may require elevated execution to communicate with `com.apple.testmanagerd.control`.

## Test strategy
- Fast unit/integration tests:
  - Keep state-model and persistence tests in `LLM CouncilTests`.
  - Prefer pure helper tests for deterministic coverage (`upsertHistory`, layout preset effects).
- UI test coverage:
  - Keep launch and core shell presence checks in `LLM CouncilUITests`.
  - Add accessibility identifiers for any interactive control needed by assertions.
- Snapshot / visual checks:
  - Use SwiftUI preview when practical.
  - Use `bin/sim-screenshot` only when iOS flows are intentionally introduced.
- Manual QA notes:
  - Verify sign-in persistence per provider across relaunch.
  - Verify `Send to Active` submits in each visible/included pane.

## Conventions
- Keep fast tests easy to run locally.
- Prefer targeted test loops while iterating.
- Use accessibility identifiers on interactive or assertion-critical UI.
- If a bug escaped, add the narrowest repeatable test that would have caught it.
