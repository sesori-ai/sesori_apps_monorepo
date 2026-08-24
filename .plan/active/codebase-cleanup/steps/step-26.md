# Step 26/45 — Share descriptor setup probing and managed installation capability

## Re-verification against Step 25

The nullable `RuntimeVersionValidator.detectVersion()` result still forced each
managed descriptor to reimplement process-failure classification and the same
explicit → PATH → fallback → managed precedence. Codex retained a 260-line
private selector duplicating provisioning. Cursor, Codex, and Hermes retained
the same CSI-only ANSI stripping, while Claude retained the stronger CSI+OSC
form.

The planned generic install and setup factories were not valid shared
boundaries. Descriptor install streams own different output limits and
long-lived `http.Client` disposal, OMP resolves Linux assets asynchronously from
host libc, and authentication/status hints are backend-specific. Those
pipelines remain local. No executor factory, shared output-limit constant,
generic auth callback, hint table, or install factory was added.

## Change

- Added typed `RuntimeProbeOutcome` variants for ready, missing, timeout,
  non-zero exit, unrecognized output, and unexpected failure. Unexpected
  failures retain and log their original error and stack trace.
- Added neutral `ManagedRuntimeSelectionService`, which owns read-only explicit
  → PATH → ordered fallback → managed precedence, minimum/exact managed-version
  policy, source/path/version results, rejected PATH versions, rejection detail,
  and abort boundaries. Descriptors parse their own config and resolve their
  own candidates before calling it.
- Made `ManagedRuntimeProvisionService` consume an injected selector and retain
  its existing progress, notice, failure, and no-install behavior. Removed the
  duplicate Codex selector and its duplicate tests.
- Migrated Cursor, OMP, Pi, Codex, and OpenCode setup inspection while retaining
  each plugin's exact explicit-bin authority, setup statuses/hints,
  authentication checks, runtime version reporting, and OpenCode attach mode.
  Cursor preserves its existing minimum-version managed check; the other four
  preserve exact pinned-managed checks. Hermes and Claude keep their custom
  probes.
- Added `RuntimeManifest.supportsManagedInstallOn(...)`. The default delegates
  to synchronous asset lookup; OMP overrides it for async libc-aware Linux asset
  selection. Install composition and HTTP client ownership remain local.
- Added foundation `stripAnsi(...)` with CSI+OSC handling and migrated Cursor,
  Codex, Hermes, and Claude to it.
- There is no public wire, persisted-data, database, or intended user-visible
  behavior change.

## Verification

- `dart analyze --fatal-infos` in `bridge/sesori_bridge_foundation`: passed.
- Foundation ANSI tests: 3 passed.
- `dart analyze --fatal-infos` in `bridge/sesori_plugin_runtime`: passed.
- Full `dart test` in `bridge/sesori_plugin_runtime`: 146 passed.
- `dart analyze --fatal-infos` in Cursor, OMP, Pi, Codex, OpenCode, Hermes, and
  Claude plugin packages: passed.
- Cursor descriptor availability tests: 17 passed.
- OMP descriptor and manifest tests: 17 passed.
- Pi descriptor and manifest tests: 12 passed.
- Codex descriptor setup tests: 14 passed.
- OpenCode descriptor availability/lifecycle tests: 45 passed.
- Hermes descriptor tests: 18 passed.
- Claude descriptor and approval-registry tests: 29 passed.
- Architecture plan review: approved after making descriptor-owned config and
  Codex desktop-candidate resolution explicit.
- Architecture implementation review finding applied: provisioning now receives
  `ManagedRuntimeSelectionService` directly rather than accepting a validator
  solely to construct that collaborator.
- Correctness review produced no valid behavior regression. Its useful test-gap
  observation added direct coverage for abort after a completed shared probe;
  its Cursor exact-version suggestion was rejected because existing Cursor
  setup intentionally uses the minimum policy.
- `git diff --check`: passed.
- Size excluding the plan and this evidence file: **`+833 / -1,030` = 1,863
  changed lines**. This exceeds the 1,500-line soft cap by 363 lines because the
  cohesive migration deletes the 260-line Codex selector and its 286-line
  duplicate test while replacing five descriptor probe implementations;
  production and test code together are net 197 lines smaller.
