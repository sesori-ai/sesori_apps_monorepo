# Step 23/45 — Remove dead plugin contracts and collapse PluginProvider

## Re-verification against `main`

The generic `BridgePluginApi.dispose()` contract remained unused by bridge
core, while concrete plugin/runtime wrappers still own meaningful teardown.
`PluginProvider` variants still carried identical fields and producers never
needed variant-specific behavior. `PluginAgentVariant`, two default process
factories, registry lookup methods, OpenCode's optional auto-initialization,
and several migration-era comments also remained dead.

Four planned removals were no longer valid. `healthCheck()` is the documented
headless instantaneous availability probe and has production/tool callers;
`PluginApiException` is shared by bridge routing and OpenCode; injectable
approval ID generators provide deterministic tests across plugin families; and
the setup-status variants already make version presence unrepresentable for
statuses that cannot carry it. Those contracts were retained.

## Change

- Removed `dispose()` from `BridgePluginApi`; concrete plugins and narrow
  managed-runtime APIs continue to expose and own teardown where required.
- Replaced the ten identical `PluginProvider` union variants with one generated
  value class and simplified OpenCode and Pi provider mapping to one constructor.
- Removed `PluginAgentVariant`, dead approval-registry lookup methods, unused
  Claude and Pi default process factories, and stale migration comments.
- Made `AcpStdioClient.processFactory` required and removed OpenCode's unused
  `autoInitialize` branch so initialization is always explicit.
- Regenerated affected sources. The provider's legacy generated `runtimeType`
  discriminator disappears before plugin providers are mapped to the explicit
  client transport model; there is no public wire, persisted-data, database, or
  user-visible behavior change.

## Verification

- `make analyze` in `bridge`: passed for every bridge package after merging
  current `origin/main`.
- Full bridge test matrix passed before the base merge.
- `dart test` in `bridge/app`: passed after the base merge.
- `dart test` in `bridge/sesori_plugin_pi`: passed after the base merge.
- `dart run build_runner build`: completed; generated sources are current.
- Architecture implementation review: approved with no findings.
- Correctness review: no actionable findings.
- `git diff --check origin/main...HEAD`: passed.
- Size excluding this evidence file against merge-base `0969f00d63`:
  **`+253 / -1466` = 1,719 changed lines**. This exceeds the 1,500-line soft cap
  by 219 lines because the generated `PluginProvider` sources account for 926
  changed lines; excluding those generated files, the change is 793 lines.
