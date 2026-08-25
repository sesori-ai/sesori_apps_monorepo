# Step 14/45 - Replace arbitrary test waits with deterministic synchronization

## Re-verification against `main`

The historical total of 187 sleeps included 141 Flutter fake-time animation
pumps, which are deterministic and remain unchanged. This step removes 56
positive-duration waits from the selected pure-Dart hotspots. Positive
durations that define the timeout behavior under test remain; they are not used
as synchronization sleeps.

The session-detail and session-list suites now await observable cubit state or
controlled completers. The staleness cooldown tests retain their existing 100
ms behavior but advance it with `fakeAsync`. The Codex locator test overrides
filesystem metadata with `IOOverrides`, and the process-runner fixture uses a
bounded, newline-framed loopback control channel instead of sleeping before
checking descendant cleanup.

The shared `awaitState` helper centralizes state-stream waiting and includes a
bounded diagnostic timeout. No production implementation, wire contract,
persisted data, database schema, or user-visible behavior changed.

## Verification

- `dart analyze` in `client/module_core`: clean.
- Seven touched module-core suites: 158 tests passed three consecutive times
  with `dart test -j1`.
- The three module-core suites changed during final review
  (`session_detail_cubit_permission_test`, `session_detail_stale_test`, and
  `session_list_cubit_test`): 84 tests passed three consecutive times from
  their final contents with `dart test -j1`.
- `dart analyze` in `bridge/sesori_plugin_codex`: clean.
- `codex_desktop_app_locator_test`: 5 tests passed three consecutive times with
  `dart test -j1`.
- `dart analyze` in `bridge/app`: clean.
- `process_runner_test`: 2 tests passed three consecutive times from its final
  contents with `dart test -j1`.
- Scoped scans found no remaining positive-duration `Future.delayed` calls or
  `sleep` calls in the touched hotspots.
- `git diff --check`: clean.

The raw diff excluding this evidence file is `+942 / -702`. It exceeds the
1,500 changed-line soft cap because wrapping nine cooldown tests in `fakeAsync`
reindents their complete bodies; the change is test-only and contains no
production logic.

Architecture implementation review not run: Step 14 changes tests and a test
helper only, which is outside the architecture-review scope.
