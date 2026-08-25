# Step 28/45 — Share small plugin helpers and lifecycle wrappers

## Re-verification against Step 27

The planned inventory included several near-duplicates that are not equivalent.
Cursor still accepts empty config strings, OpenCode still uses an empty-map
fallback, Pi attachment MIME normalization has a different fallback contract,
Claude/Pi DTO scalar parsers validate different shapes, and Claude/Codex error
decoding has different privacy behavior. Those copies remain local.

The exact duplication remained in Claude/Pi shutdown sequencing, process-spawn
outcomes, and global tracked teardowns; Cursor/OMP ACP config parsing;
ACP/Codex/OpenCode attachment normalization; four GitHub release URL builders;
compaction commands; and selected message-part/tool-status construction.

## Change

- Added focused message-part factories, terminal tool-status state, compaction
  command construction, process-spawn outcome, attachment normalization, and
  all-settled shutdown cleanup to the owning shared plugin contracts.
- Migrated Claude/Pi bridge shutdown and process events without changing cleanup
  ordering, first-error propagation, plugin diagnostics, or shutdown budgets.
- Replaced Claude/Pi global teardown sets with foundation `PendingOperations`
  while retaining their per-session coordination state.
- Added shared decoded-JSON value helpers and migrated only exact consumers.
- Added ACP-owned config-option parsing for Cursor and OMP while preserving
  plugin-local catalog models and selection behavior.
- Consolidated ACP/Codex/OpenCode attachment normalization and OpenCode/Codex/
  OMP/Pi GitHub release URL assembly without changing byte limits, MIME policy,
  repositories, tags, asset names, or Cursor's non-GitHub URL.
- Added contextual logging to remaining Codex recovered failures and simplified
  stale-selection exception construction locally in Claude and Pi.
- There is no intended user-visible, wire-contract, database, or persisted-data
  change.

## Verification

- `dart analyze --fatal-infos` passed in shared, interface, runtime, ACP, Codex,
  Claude, Pi, Cursor, OMP, and OpenCode packages.
- Full `shared/sesori_shared` suite: 363 passed.
- Full `sesori_plugin_interface` suite: 159 passed.
- Full `sesori_plugin_runtime` suite: 153 passed.
- Full ACP suite: 263 passed.
- Full Codex suite: 380 passed.
- Full Claude suite: 254 passed.
- Full Pi suite: 274 passed.
- Full Cursor suite: 138 passed.
- Full OMP suite: 53 passed.
- Full OpenCode suite: 425 passed.
- Interface model code generation completed with no generated-file changes.
- Architecture implementation review: approved with no findings.
- Correctness review: no findings.
- Interface, ACP, Codex, and Cursor analyzers and full suites passed again after
  merging Step 27's review fixes forward.
- Human-review follow-up replaced flattened `PluginMessagePart` fields with one
  Freezed variant per part type; bridge-wide `make analyze` passed.
- Follow-up verification passed: full interface (160), Cursor (138), OMP (53),
  and DeepSeek (31) suites; focused OpenCode (11), ACP (138), Codex (155),
  Claude (33), Pi (44), and bridge app mapper/SSE/repository (157) suites.
- `git diff --check`: passed.
