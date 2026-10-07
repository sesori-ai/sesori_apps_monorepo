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
- Checks, with Dart 3.13.4 from Flutter 3.47.5-stable first on `PATH`:
  - on code commit `a884ede423`, cwd `bridge/app`: `dart test` passed all
    3,079 tests, and `dart analyze --fatal-infos` reported no issues;
  - on merge commit `7668238474` (main merged in, no code change of this
    step), cwd `bridge/app`: `dart test test/bridge/services/` passed all
    477 tests, and `dart analyze --fatal-infos` reported no issues.
- `architecture-implementation-review` of `git diff origin/main...HEAD` at
  `7668238474`, run from the repository root: approved, no findings.
- This evidence commit changes no code.
