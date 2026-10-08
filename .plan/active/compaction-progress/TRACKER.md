# Compaction Progress — Tracker

This tracker holds only decisions, guardrails and the fixed PR titles. It does
not mirror PR state. Live status is on GitHub:
`gh pr list --state all --search "[compaction-progress]"`. Evidence for a
finished step lives in `steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

- C1–C7 are the user's final decisions of 2026-10-06. Do not reopen them.
- P1–P12 are planning decisions from code evidence. See
  [PLAN](PLAN.md#decisions).
- Q1–Q6 are the user's final answers of 2026-10-07. Do not reopen them. See
  [PLAN](PLAN.md#answered-questions).
  - Q1: only "auto" is labelled.
  - Q2: an unfinished compaction becomes the quiet "Compaction failed" note.
  - Q3: v1.9.0 apps on Pi and Codex lose the running `compact` card.
  - Q4: the sweep-rule refactor ships as its own PR, step 2.
  - Q5: old apps show nothing while an OpenCode summary streams, with no
    extra code.
  - Q6: failure notes the harness's history lacks survive one re-import,
    then disappear.
- R1 is the user's answer of 2026-10-08: a list row that replaces one that
  left in the same update stays put; only new rows ease in.
- `docs/HARNESS_CAPABILITIES.md` keeps one two-column compaction table
  (Compaction row, Summary). Step 8 dropped the planned four-column split.
- The series was renumbered on 2026-10-07 to insert step 2. Step 1 merged
  under its old title.
- This plan approves the phase-1 architecture only. The step-6 PR details
  phase 2 and runs `architecture-plan-review` on it before code.

## Guardrails

- No new part type and no new session status. The state lives on
  `MessagePart.compaction` (`state`, with `@Default(completed)`), mirrored by
  `PluginMessagePart.compaction` (`compactionState`) since step 3.
- Backend vocabulary (Claude `compact_result`, Pi reasons, OpenCode `reason`,
  token fields) stays inside its plugin. Shared code and the client see only
  `CompactionState` and `CompactionTrigger`.
- The timer counts from the compaction message's `time.created`. No client
  clock.
- Streamed words use the existing part-delta pipeline. No new event or
  buffer.
- Stranded running compactions are finalized only by the existing idle and
  read sweep, whose rule lives in `ChatHistoryService` from step 2.
- The row settles in place, keyed by part id. Never remove and re-add it,
  except for Pi's failure note (step 7) and Claude's one re-key after a
  history re-import (P10 option 2, with R1).

## Steps

| Step | Branch | Title | Target (changed lines) | Needs |
|---|---|---|---|---|
| 1 | `compaction-progress/plan` | [1](#fixed-pr-titles) | ≤ 800 | — |
| 2 | `compaction-progress/sweep-rule` | [2](#fixed-pr-titles) | ≤ 600 (about 350 plan edits) | 1 |
| 3 | `compaction-progress/contract` | [3](#fixed-pr-titles) | ≤ 1,100 (about 550 generated) | 2 |
| 4 | `compaction-progress/app` | [4](#fixed-pr-titles) | ≤ 800 | 3 |
| 5 | `compaction-progress/claude` | [5](#fixed-pr-titles) | ≤ 700 | 4 |
| 5b | `compaction-progress/claude-reimport-dedup` | [5b](#fixed-pr-titles) | ≤ 400 | 5 |
| 6 | `compaction-progress/opencode` | [6](#fixed-pr-titles) | ≤ 800 | 4 |
| 7 | `compaction-progress/pi-codex-deepseek` | [7](#fixed-pr-titles) | ≤ 900 | 4, step 6's plan detail |
| 7b | `compaction-progress/codex-reimport-dedup` | [7b](#fixed-pr-titles) | ≤ 400 | 7 |
| 7c | `compaction-progress/pi-compaction-settle` | [7c](#fixed-pr-titles) | ≤ 400 | 7 |
| 8 | `compaction-progress/step-8-docs` | [8](#fixed-pr-titles) | ≤ 300 | 2–7 |
| 9 | `compaction-progress/retire` | [9](#fixed-pr-titles) | ≤ 250 | 8 |

Steps 3 and 4 include generated Freezed, JSON and localization output.

## Fixed PR Titles

1. `🌱 [compaction-progress] Plan compaction progress [step 1/8]` (merged
   before the renumbering)
2. `⚙️ [compaction-progress] Move the stranded-step rule into the history service [step 2/9]`
3. `🚧 [compaction-progress] Carry compaction progress on the compaction part [step 3/9]`
4. `⚙️ [compaction-progress] Show running and failed compaction in the transcript [step 4/9]`
5. `🚧 [compaction-progress] Show Claude compaction live, with its outcome [step 5/9]`
   - 5b. `🌿 [compaction-progress] Keep one Claude compaction row after a reload [step 5b/9]`
     (a fix found by step 9's live run)
6. `⚙️ [compaction-progress] Stream OpenCode compaction into the live row [step 6/9]`
7. `⚙️ [compaction-progress] Move Pi, Codex and DeepSeek onto the live compaction row [step 7/9]`
   - 7b. `🌿 [compaction-progress] Keep one Codex compaction row after a reload [step 7b/9]`
     (a fix found by step 9's live run)
   - 7c. `🌿 [compaction-progress] Settle Pi compaction without a failed flash [step 7c/9]`
     (a fix found by step 9's live run)
8. `🌱 [compaction-progress] Reconcile the docs with shipped compaction progress [step 8/9]`
9. `🌱 [compaction-progress] Record the matrix and retire the plan [step 9/9]`
