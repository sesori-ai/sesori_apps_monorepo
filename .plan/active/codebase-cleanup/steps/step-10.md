# Step 10/45 — Consolidate bridge/app process-runner and service test fakes

## Re-verification against `main`

The duplicate families remained on `main`, but several copies had acquired
meaningful behavior since the plan estimate. Equivalent fixed-result process
runners, token refreshers, control clients, settings APIs, deletion-oriented
worktree services, and strict process repositories could still share helpers.
Command queues, detached restart spawning, synchronous subscription counting,
queued settings reads, session-creation and rollback behavior, and relay
connection/close timing remained test-specific and fail loud locally.

## Change

- Added one fail-loud `NoopProcessRunner` and responder-style
  `RecordingProcessRunner`, replacing the equivalent local process runners.
- Expanded the existing `FakeTokenRefresher` and added a self-cleaning
  `FakeControlChannelClient` for fixed-token and ordinary send/stream tests.
- Added `InMemoryBridgeSettingsApi`, `DeletionWorktreeServiceFake`, and
  `StrictFakeProcessRepository`, then migrated the compatible service, routing,
  runtime, and server tests.
- Retained specialized local fakes where adopting a successful shared default
  or hiding timing and ordering state would weaken the existing assertions.
- The three recording relay clients now exercise different transport,
  connection-promotion, failure, and close-order behavior, so no shared relay
  fake was added solely to satisfy the original estimate.

## Verification

- `dart analyze --fatal-infos` in `bridge/app`: passed.
- Full `dart test` in `bridge/app`: 2,692 passed; 2 executable PowerShell cases
  skipped because PowerShell is unavailable locally.
- Focused suites passed after the final helper migrations and lifecycle fix.
- Correctness review found one low-severity controller-cleanup gap; the shared
  control client now registers an idempotent teardown, and its affected suites
  pass.
- `git diff --check`: passed.
- Size excluding this evidence file against merge-base `3c45717ce5`:
  **`+435 / -968` = 1,403 changed lines**, under the 1,500-line soft cap and 533
  fewer test lines overall.
- Architecture implementation review not run: this change is test-only and
  changes no production class, dependency ownership, or contract.
