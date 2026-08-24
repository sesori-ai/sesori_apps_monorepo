# Step 42 — Compatibility Expiry

## Re-verified evidence

- The owner-selected minimum public client/bridge baseline is v1.4.0.
- Public-tag source checks and retained-format audits are recorded per marker in
  `TRACKER.md`; internal and prerelease tags were not treated as baselines.
- Current-client aggregate settings reads and their legacy fallback already
  satisfy the bidirectional supported-peer contract, so that seam stays.

## Change

- Removed the context-free `GET /agent` route and CWD/repository identity glue.
- Required rejection ownership and removed legacy question-owner discovery plus
  the dispatcher coordination used only by it.
- Required typed filesystem health state and strict fresh-health parsing.
- Removed the pre-v1.4 post-update relaunch and bridge-ID migration paths.
- Removed the old child-interaction display-owner fallback.
- Retained external CLI aliases, live Codex config fallback, the frozen-schema
  runtime intent side file, and supported-peer settings fallback with corrected
  durable rationale.

## Verification

- `dart analyze --fatal-infos` passed in `shared/sesori_shared`,
  `bridge/app`, `bridge/sesori_plugin_opencode`,
  `bridge/sesori_plugin_codex`, `bridge/sesori_plugin_runtime`,
  `client/module_core`, and `client/app`.
- Full pure-Dart suites passed: 358 shared tests, 2,681 bridge tests, and
  1,305 client-core tests.
- The focused filesystem warning widget suite passed 18 tests.
- Focused bridge route, dispatch, runtime, restart, registration, client
  reconnect, settings fallback, and interaction-owner suites passed.
- Generated diffs are confined to `HealthResponse` and
  `RejectQuestionRequest`; `git diff --check` passed.
- Architecture implementation review approved the complete working-tree diff
  across the client, bridge, and shared workspaces with no findings.
- Independent correctness review found one missing empty-`sessionId` boundary
  check; the handler now returns 400 and its focused route suite passes 8 tests.
- The pinned Dart formatter crashed on six pre-existing enhanced-enum files
  with `Null check operator used on a null value`; analyzers and diff checks
  are the formatting authority for those files.
