# Step 25/45 — Fold Codex/OpenCode managed-runtime plumbing

## Re-verification against `main`

The duplicated process-draining wrappers, dynamic-port generators, transport
status reporters, managed API lifecycle members, and live-plugin wrappers all
remained. The two known drift fixes still existed only in Codex: random port
selection was bounded by draws rather than distinct results, and repeated
disconnects did not accumulate uncancelable debounce futures.

The planned descriptor startup helper was no longer a valid shared invariant.
OpenCode now has attach, unreachable/degraded, and nullable-handle branches with
different rollback ownership, while Codex is managed-only. Startup, abort, and
rollback orchestration therefore remain plugin-local instead of being flattened
into flags. `BridgePluginApi` is also sealed around its two project-ownership
variants, so the shared managed lifecycle contract remains a separate facet
rather than introducing a third subtype.

## Change

- Added shared `DrainingSpawnedProcess` and bounded
  `dynamicPortCandidates(...)` primitives and removed both plugin copies.
- Added `ManagedRuntimeStatusReporter`, adopting Codex's repeated-disconnect
  suppression for both transports, and removed the two private reporters.
- Added the lifecycle-only `ManagedRuntimeApi` and generic
  `ManagedRuntimeBridgePlugin<R, A>`. Codex and OpenCode retain their distinct
  project APIs and descriptor startup policies while sharing status/work-state
  delegation, diagnostics, owned-runtime interruption policy, and ordered,
  idempotent teardown.
- Preserved OpenCode's attach/degraded rule that never interrupts work on a
  server the bridge does not own. Monitor disarm still precedes API disposal and
  owned-process stop, all teardown steps still run after a failure, and the first
  failure is rethrown with its stack trace.
- Removed the obsolete plugin-local wrapper/reporter files and their duplicated
  tests. Shared tests now own those invariants; plugin runtime suites retain the
  managed, attach, degraded, abort, restart, and shutdown integration coverage.
- Updated the durable plan and tracker to remove the stale startup-helper
  guardrail. There is no public wire, persisted-data, database, or user-visible
  behavior change.

## Verification

- `dart analyze --fatal-infos` in `bridge/sesori_plugin_runtime`: passed.
- `dart test` in `bridge/sesori_plugin_runtime`: 138 passed.
- `dart analyze --fatal-infos` in `bridge/sesori_plugin_codex`: passed.
- Full `dart test` in `bridge/sesori_plugin_codex`: 387 passed.
- `dart test test/runtime` in `bridge/sesori_plugin_codex`: 53 passed after the
  final architecture cleanup.
- `dart analyze --fatal-infos` in `bridge/sesori_plugin_opencode`: passed.
- Full `dart test` in `bridge/sesori_plugin_opencode`: 425 passed.
- `dart test test/runtime` in `bridge/sesori_plugin_opencode`: 87 passed after
  the final architecture cleanup.
- Architecture implementation review: approved after deleting two
  one-consumer typedef files and using the shared wrapper directly.
- Correctness review: no actionable findings. Its two behavior observations
  were the planned bounded-draw and repeated-disconnect drift corrections.
- `git diff --check`: passed.
- Size against `origin/main`, excluding this evidence file:
  **`+705 / -993` = 1,698 changed lines**. This exceeds the 1,500-line soft cap
  by 198 lines because the consolidation deletes 841 lines of duplicated
  plugin-local wrappers, reporters, and their duplicate tests; production code
  is net smaller and the step remains one cohesive lifecycle boundary.
