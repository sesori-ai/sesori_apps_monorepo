# Step 2 — The Stranded-Step Rule Moves Into The History Service

Branch `compaction-progress/sweep-rule`. Bridge `app` and this plan only; no
behavior, wire or database change.

## Scope Delivered

- `ChatHistoryService._endUnfinishedPart` is the one typed rule: a `pending`
  or `running` tool part ends as an error with "The turn ended before this
  tool reported a result.", and a subtask with an open `taskState` ends as
  cancelled. `_unfinishedStatuses` feeds both the rule and the repository
  prefilter.
- The idle sweep (`finalizeOpenToolParts`), the read-path sweep and the
  read-path check `_containsUnfinishedPart` (formerly `_containsOpenToolPart`)
  all apply that rule.
- `ChatHistoryRepository.finalizeOpenToolParts` became `rewriteStoredParts`,
  persistence only: prefilter rows by the caller's statuses, decode each
  candidate, write the caller's replacement, and keep the row's spilled
  attachment JSON, which a typed decode cannot carry.
- The user's answers Q1–Q6 of 2026-10-07 are recorded, and the series is
  renumbered to nine steps.

## Evidence

- `bridge/app/test/bridge/services/chat_history_tool_finalization_test.dart`:
  the existing sweep tests pass unchanged. One test was added: a finalized
  running tool keeps its stored image attachment. With the attachment restore
  disabled, that test fails.
- `dart test` in `bridge/app`: 3,079 passed. `dart analyze --fatal-infos`:
  no issues. Toolchain: Flutter 3.47.5-stable.
- `architecture-implementation-review` on the branch against `main`:
  approved, no findings.
