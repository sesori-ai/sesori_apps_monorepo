# Step 32 — Tool kinds

## What changed

- The plugin interface's tool part gains a required `PluginToolKind` (read,
  edit, command, search, other). Each plugin classifies its own tool names:
  `ClaudeToolKindMapper`, `CodexToolKindMapper`, `PiToolKindMapper`, a private
  OpenCode classifier in `MessagePartMapper`, and `AcpContentMapper.toolKind`
  for every ACP harness (Grok, Antigravity, Copilot, Cursor, OMP, Hermes,
  DeepSeek), which reads the ACP tool `kind`.
- `sesori_shared` gains its own `ToolKind` on `MessagePartTool`, the same values
  plus `unknown`, declared
  `@JsonKey(unknownEnumValue: ToolKind.unknown) @Default(ToolKind.unknown)` with
  a `COMPATIBILITY 2026-09-25 (v1.9.1)` marker. An older bridge's missing field
  and a newer bridge's new value both read as unknown. The bridge maps one enum
  to the other in `plugin_to_shared_mapping.dart`; the plugin interface stays
  independent of `sesori_shared`.
- The transcript builder counts tool calls by kind; other and unknown kinds stay
  plain steps. The summary reads, for example, "Thought · read 2 files · edited
  1 file · ran 1 command · 1 search · 1 step · 1 failed". Counts are calls, and
  the client never parses tool input.
- Pi's tracker reads its edit test from the new classifier instead of repeating
  the names.

## Deviations

- The summary's counts now ellipsize on their own and the failure count sits
  outside them, because longer words would otherwise push "1 failed" off a phone
  screen. Failures keep their one signal.
- Web fetches count as other (plain steps); web searches count as searches. A
  separate web kind added a word and a mapping for no decision in the plan.
- Codex reads and searches files through shell commands, so those count as
  commands; recorded in `docs/HARNESS_CAPABILITIES.md`.
- Claude's `_ClaudeToolKind` stays: it drives todo and task lifecycle, which the
  normalized kind does not cover.
- Persisted bridge history written before this change reads as unknown kinds,
  so those old groups keep "N steps". Accepted as a cosmetic limit for old data.

## Verification

- `dart analyze --fatal-infos` is clean in every touched package: the plugin
  interface, OpenCode, Claude, Codex, Pi, ACP, Cursor, Grok, Hermes, OMP,
  DeepSeek, Copilot, Antigravity, the bridge app, `sesori_shared`,
  `module_core` and `module_app_ui`.
- `dart test` passes in the same bridge packages and `sesori_shared`, including
  the new mapper tests, `tool_kind_test.dart` (missing, unknown and round-trip
  kinds) and the kind mapping in `plugin_to_shared_mapping_test.dart`.
- `transcript_builder_test.dart` (20 tests) and
  `transcript_group_widget_test.dart` (6 tests) pass, including counts by kind
  and a narrow summary that keeps the failure count.
- Live plugin runs were not executed in this step.
