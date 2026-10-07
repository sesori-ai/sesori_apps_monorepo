# Step 3 — Carry Compaction Progress On The Compaction Part

Branch `compaction-progress/contract`. Wire contract, plugin interface, every
compaction emitter, the history sweep and one client switch. No user-visible
change and no database migration.

## Scope Delivered

- `MessagePart.compaction` carries `CompactionState state`, a sealed union
  keyed by `status`: `running{summary?}`, `completed{summary?, freedTokens?,
  trigger?}` and `failed{error?}`, with `fallbackUnion: "completed"`.
  `CompactionTrigger` is `manual`/`auto`, and an unknown value decodes as null.
  The state defaults to completed with no details, under a dated
  `COMPATIBILITY 2026-10-07 (v1.9.1)` comment. The top-level `summary` (never
  publicly released) moved into the variants without compatibility code.
- The plugin interface mirrors it as `PluginCompactionState` and
  `PluginCompactionTrigger`. The field is `compactionState`, not `state`:
  `PluginMessagePart` already exposes a tool-only `PluginToolState get state`
  accessor, and a `state` field of another type is an invalid override. This
  follows the `subtask.taskState` precedent. PLAN Architecture 2 and the
  tracker guardrail record the name.
- `plugin_to_shared_mapping.dart` maps the state and trigger 1:1.
- Every emitter (Claude live and history, OpenCode v1 live and REST, OpenCode
  v2, Codex live and rollout, Pi live and history) emits
  `completed(summary: <today's summary>, freedTokens: null, trigger: null)`.
- `ChatHistoryService._endUnfinishedPart` ends a running compaction as
  `failed(error: "The turn ended before compaction finished.")`. The existing
  `"status":"running"` prefilter admits it, and `_containsUnfinishedPart`
  applies the same rule, so the read path sweeps a page whose only open part is
  a running compaction.
- `AssistantMessageCard` renders the existing row for a completed part and
  nothing for running or failed (step 4 renders them). The dead duplicate
  `MessagePartCompaction() => false` case is gone.
- Regression docs: `tools-and-file-changes.md` (the state, the released-bridge
  default, the unknown status and trigger, the older-client line, the new
  test) and `session-history-and-recovery.md` (the sweep and its failure
  signal).

## Evidence

Checks, with Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`, on code
commit `fcbf54672b`:

- `shared/sesori_shared/test/models/compaction_state_test.dart`: a
  v1.9.0-shaped state-less part decodes as completed with no details; each
  state round-trips; an unknown `status` decodes as completed; an unknown
  trigger decodes as null.
- `bridge/app/test/bridge/sse/bridge_event_mapper_test.dart`: the mapping of
  each running, completed and failed state, triggers included.
- `bridge/app/test/bridge/services/chat_history_tool_finalization_test.dart`:
  the idle sweep fails a running compaction and leaves completed and failed
  ones untouched; a backfill read of an idle session fails an imported running
  compaction; a fresh store whose only open part is a running compaction is
  swept on read (the abrupt-death path).
- Plugin tests assert every emitter's `completed` state with today's summary.
- `client/module_app_ui/test/features/session_detail/widgets/assistant_message_card_test.dart`:
  a completed part with a summary opens it, and a state-less part is an inert
  "Context compacted" row.
- `dart analyze --fatal-infos`: no issues in `sesori_shared`,
  `sesori_plugin_interface`, `bridge/app`, the Claude, OpenCode, Codex and Pi
  plugins, `module_app_ui` and `module_core`.
- `dart test`: `sesori_shared` 443, `bridge/app` 3,097 (3 skipped),
  `sesori_plugin_interface` 181, Claude 390, OpenCode 604, Codex 478 and Pi
  345 passed; `flutter test` of the three compaction-related
  `module_app_ui` widget files passed.

## Architecture Review

`architecture-implementation-review` of `git diff origin/main...HEAD` at
`fcbf54672b`: approved, no blocking findings. It confirmed the v1.9.0 decode
(missing state, unknown status and unknown trigger), the marker placement, the
neutral trigger vocabulary, the `compactionState` name, and the rule staying
in `ChatHistoryService`. It noted the accepted P6 coupling: the sweep's
prefilter relies on the stored `"status":"running"` text matching
`ToolStatus.running`'s marker, documented beside `_unfinishedStatuses` and
covered by the three new sweep-path tests.

## Size

Authored 461 changed lines, generated Freezed and JSON output 690 (before this
evidence file).
