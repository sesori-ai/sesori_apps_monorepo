# Step 42 — Compatibility Expiry

## Re-verified evidence

- The owner-selected minimum public client/bridge baseline is v1.4.0.
- Public-tag source checks and retained-format audits are recorded per marker in
  `TRACKER.md`; internal and prerelease tags were not treated as baselines.
- Current-client aggregate settings reads and their legacy fallback already
  satisfy the bidirectional supported-peer contract, so that seam stays.

## Change

- Required rejection ownership and removed legacy question-owner discovery plus
  the dispatcher coordination used only by it.
- Required typed filesystem health state and strict fresh-health parsing.
- Removed the pre-v1.4 post-update relaunch and bridge-ID migration paths.
- Removed the old child-interaction display-owner fallback.
- Removed obsolete unprefixed OpenCode CLI aliases and write-only managed-runtime
  start-intent state. Retained the live Codex config fallback and supported-peer
  settings fallback.

## Verification

- `dart analyze --fatal-infos` passed in `shared/sesori_shared`,
  `bridge/app`, `bridge/sesori_plugin_opencode`,
  `bridge/sesori_plugin_codex`, `bridge/sesori_plugin_runtime`,
  `client/module_core`, and `client/app`.
- Full pure-Dart suites passed after merging the current `origin/main`: 358
  shared tests and 1,305 client-core tests. After review feedback, the affected
  full suites passed with 152 plugin-interface, 123 plugin-runtime, 436
  OpenCode, 392 Codex, and 2,681 bridge-app tests.
- The focused filesystem warning widget suite passed 18 tests.
- Focused bridge route, dispatch, runtime, restart, registration, client
  reconnect, settings fallback, and interaction-owner suites passed.
- Generated changes comprise `HealthResponse`, `RejectQuestionRequest`, and the
  removal of the unused runtime start-intent outputs; `git diff --check` passed.
- Architecture implementation review approved the complete working-tree diff
  across the client, bridge, and shared workspaces with no findings.
- Independent correctness review found one missing empty-`sessionId` boundary
  check; the handler now returns 400 and its focused route suite passes 8 tests.
- The pinned Dart formatter crashed on six pre-existing enhanced-enum files
  with `Null check operator used on a null value`; analyzers and diff checks
  are the formatting authority for those files.
