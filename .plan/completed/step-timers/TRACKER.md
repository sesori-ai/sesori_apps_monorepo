# Step Timers — Tracker

## Retired with accepted gaps — 2026-11-02

Phase 1 steps 1–5 merged on 2026-09-26 (#1772, #1775, #1778, #1783, #1787).
Steps 6 and 7 never ran as their own PRs. The shipped timers are already
described in `tools-and-file-changes.md`, `session-turns.md`,
`transcript-turn-navigation.md` and the `docs/HARNESS_CAPABILITIES.md` "Live
timers" section. The `periodic-cleanup-2026-11` plan (step 23) retired phase 1
as finished, and these checks were never executed:

- step 6's separate reconciliation pass over those documents;
- the step-7 L3 run of the PLAN.md "Regression Coverage" matrix: the iOS
  device, macOS desktop and Android rows, and the live Claude Code, Codex,
  OpenCode, Pi, DeepSeek, Grok and other-ACP rows.

User decision Q6 (2026-11-02): the live harness rows run on a headless bridge and
the iOS simulator in [periodic-cleanup-2026-11](../../active/periodic-cleanup-2026-11/PLAN.md#verification-and-retirement)
step 28, and the step-6 reconciliation runs in its step 27. The iOS device,
Android and macOS desktop rows stay accepted gaps.

Phase 2 ("Later Phases" in PLAN.md) stays rough intent and needs a new plan if
picked up. Its compaction running row is superseded by
`.plan/completed/compaction-progress/`.

This tracker holds decisions, guardrails and the fixed PR titles only. It
does not mirror PR state. Live status is on GitHub:
`gh pr list --state all --search "[step-timers]"`. Evidence for a finished
step lives in `steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

- D1–D10 are the user's final decisions of 2026-09-26. Do not reopen them.
- P1–P9 are planning decisions from code evidence. See
  [PLAN](PLAN.md#decisions).

## Guardrails

- Phase 1 changes no wire, bridge or plugin code, except step 3's removal of
  the unreleased tool kind.
- Client code stays harness-neutral. A missing time shows as a missing timer;
  harness gaps go into `docs/HARNESS_CAPABILITIES.md`.
- No client-side "first seen" clock for a missing prompt or step time.
- The live-row rule lives in `TranscriptActivityBuilder` in `module_core`,
  not in the widget. "Running child" has one owner, `runningChildren`.
- One `Timer` per visible timer, owned by `TranscriptElapsedTime`; nothing
  ticks in a cubit.
- The folded running stub never gets a clock (D9, turn-navigation D16).
- "You can keep chatting meanwhile." ships only after the step-5 probes.

## Steps

| Step | Branch | Title | Target (changed lines) | Needs |
|---|---|---|---|---|
| 1 | `plan/step-timers` | [1](#fixed-pr-titles) | ≤ 700 | — |
| 2 | `step-timers/n-steps` | [2](#fixed-pr-titles) | ≤ 600 | 1, turn-navigation #1769 |
| 3 | `step-timers/remove-tool-kind` | [3](#fixed-pr-titles) | ≤ 1,200 (mostly deletions) | 2 |
| 4 | `step-timers/working-timer` | [4](#fixed-pr-titles) | ≤ 700 | 2 |
| 5 | `step-timers/sub-agent-row` | [5](#fixed-pr-titles) | ≤ 600 | 4 |
| 6 | `step-timers/docs` | [6](#fixed-pr-titles) | ≤ 250 | 2–5 |
| 7 | `step-timers/retire` | [7](#fixed-pr-titles) | ≤ 250 | 6 |

Steps 2, 4 and 5 include generated localization files; step 3 includes
regenerated Freezed output.

## Fixed PR Titles

1. `🌿 [step-timers] Plan step summaries and live timers [step 1/7]`
2. `🌿 [step-timers] Summarise step groups as "N steps" and fold a lone step again [step 2/7]`
3. `⚙️ [step-timers] Remove the tool kind the summary no longer reads [step 3/7]`
4. `⚙️ [step-timers] Tick the time since the prompt on "Working…" [step 4/7]`
5. `⚙️ [step-timers] Show running sub-agents in the transcript with their time [step 5/7]`
6. `🌱 [step-timers] Reconcile the docs with the shipped timers [step 6/7]`
7. `🌱 [step-timers] Record the matrix and retire phase 1 [step 7/7]`
