# Step 2 — Derive Transcript Turns From Loaded Messages

Branch `turn-navigation/turn-model`. Architecture 1.

## Plan Claims Checked

- `TranscriptBuilder` is pure and stateless. A group's `failedCount` counts
  only finished failed steps.
- `TranscriptStepStatus` folds cancelled and unknown tools into finished, so
  the rule reads `ToolStatus` directly.
- `hasRenderableUserContent` is true for every message except a user message
  without text or a known file.
- Automation is an assistant message whose sender is not `agent`.
- Message times are optional, and `completed` may be null.

## Scope Delivered

- `client/module_core/lib/src/cubits/session_detail/transcript_turns.dart`,
  exported from `sesori_dart_core.dart`:
  - `const TranscriptTurnBuilder().build(messages:, transcript:, isBusy:,
    hasOlderMessages:)` returns `TranscriptTurns`: `turns` (oldest first),
    `turnIndexByMessageId` and `promptTurnFor(openerMessageId:)`.
  - The sealed `TranscriptTurn` carries `messageIds` and a summary. Its
    variants are `TranscriptPromptTurn` (adds `opener` and `duration`),
    `TranscriptPartialTurn` and `TranscriptPreamble`.
  - `TranscriptTurnSummary` holds `steps`, `failedSteps` and the sealed
    `TranscriptTurnOutcome`: running, failed (`errorLine`) or done
    (`answerLine`).
- The follow-up rule (D11) is private, at the bottom of the same file.
  `_opensTurn` decides; `_outputEndOf` and `_partEnd` read how the agent's
  latest output ends. Overriding D11 or D17 changes only these three functions
  and their tests.
- Tests: `client/module_core/test/cubits/session_detail/transcript_turns_test.dart`.
- No behavior change for step 9 to reconcile: nothing consumes the model yet.

## Deviation

Architecture 1 left four cases open. PLAN.md now records how the rule reads
them:

- When the latest agent message has no content part yet, such as a step start
  alone, the rule reads the last content part of an earlier agent message in
  the turn. That is D11's "latest agent output".
- A file, or a step whose status the client does not know, ends in an answer.
  A spare boundary costs less than a prompt hidden inside the previous turn.
- A sub-agent without its own status counts as a step in progress.
- "No agent output yet" applies only to a turn that has an opener. Otherwise
  automation before the first prompt would absorb that prompt, against D3.

Size: 867 changed lines against the 600-line target. The production file is
289 lines and the tests are 492, because the formatter puts each fixture
message on its own line. The rest is the export, the plan edit and this file.

## Automated Evidence

Toolchain: Flutter 3.47.5. `dart analyze --fatal-infos` is clean in
`module_core`.

| Command | Result |
|---|---|
| `dart test test/cubits/session_detail/transcript_turns_test.dart test/cubits/session_detail/transcript_builder_test.dart` in `client/module_core` | 39 passed (18 new) |
| Nine one-line mutations of the rule, the segmenting and the renderable filter | each fails the new tests |

## Review

`architecture-implementation-review`, scope `origin/main...HEAD` at the model
commit:

- First review: **approved**, with no findings. Its two notes outside
  architecture scope were this evidence file, added afterwards, and the size
  explained under Deviation.

## Manual

None. There is no user-visible change.
