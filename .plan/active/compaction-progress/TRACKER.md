# Compaction Progress — Tracker

This tracker holds only decisions, guardrails and the fixed PR titles. It does
not mirror PR state. Live status is on GitHub:
`gh pr list --state all --search "[compaction-progress]"`. Evidence for a
finished step lives in `steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

- C1–C7 are the user's final decisions of 2026-10-06. Do not reopen them.
- P1–P12 are planning decisions from code evidence. See
  [PLAN](PLAN.md#decisions).
- Q1–Q3 are open. The plan proceeds with the suggested picks until the
  user answers. Q2 gates step 2's merge, Q1 step 3's, and Q3 step 5's.
- This plan approves the phase-1 architecture only. The step-5 PR details
  phase 2 and runs `architecture-plan-review` on it before code.

## Guardrails

- No new part type and no new session status. The state lives on
  `MessagePart.compaction` with `@Default(completed)`.
- Backend vocabulary (Claude `compact_result`, Pi reasons, OpenCode `reason`,
  token fields) stays inside its plugin. Shared code and the client see only
  `CompactionState` and `CompactionTrigger`.
- The timer counts from the compaction message's `time.created`. No client
  clock.
- Streamed words use the existing part-delta pipeline. No new event or
  buffer.
- Stranded running compactions are finalized only by the existing idle and
  read sweep.
- The row settles in place, keyed by part id. Never remove and re-add it,
  except for the documented Claude fallback in P10.

## Steps

| Step | Branch | Title | Target (changed lines) | Needs |
|---|---|---|---|---|
| 1 | `compaction-progress/plan` | [1](#fixed-pr-titles) | ≤ 800 | — |
| 2 | `compaction-progress/contract` | [2](#fixed-pr-titles) | ≤ 1,100 (about 550 generated) | 1, Q2 |
| 3 | `compaction-progress/app` | [3](#fixed-pr-titles) | ≤ 800 | 2, Q1 |
| 4 | `compaction-progress/claude` | [4](#fixed-pr-titles) | ≤ 700 | 3 |
| 5 | `compaction-progress/opencode` | [5](#fixed-pr-titles) | ≤ 800 | 3, Q3 |
| 6 | `compaction-progress/pi-codex-deepseek` | [6](#fixed-pr-titles) | ≤ 900 | 3, step 5's plan detail |
| 7 | `compaction-progress/docs` | [7](#fixed-pr-titles) | ≤ 300 | 2–6 |
| 8 | `compaction-progress/retire` | [8](#fixed-pr-titles) | ≤ 250 | 7 |

Steps 2 and 3 include generated Freezed, JSON and localization output.

## Fixed PR Titles

1. `🌱 [compaction-progress] Plan compaction progress [step 1/8]`
2. `🚧 [compaction-progress] Carry compaction progress on the compaction part [step 2/8]`
3. `⚙️ [compaction-progress] Show running and failed compaction in the transcript [step 3/8]`
4. `🚧 [compaction-progress] Show Claude compaction live, with its outcome [step 4/8]`
5. `⚙️ [compaction-progress] Stream OpenCode compaction into the live row [step 5/8]`
6. `⚙️ [compaction-progress] Move Pi, Codex and DeepSeek onto the live compaction row [step 6/8]`
7. `🌱 [compaction-progress] Reconcile the docs with shipped compaction progress [step 7/8]`
8. `🌱 [compaction-progress] Record the matrix and retire the plan [step 8/8]`
