# Turn Navigation — Tracker

This tracker holds decisions, guardrails and the fixed PR titles only. It
does not mirror PR state. Live status is on GitHub:
`gh pr list --state all --search "[turn-navigation]"`. Evidence for a finished
step lives in `steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

- D1–D8 are the user's decisions of 2026-09-25 (round 3: R5 rows, D2 desktop).
- D9–D18 are defaults adopted without individual answers. The user may
  override any of them.
- D19–D23 are planning decisions, taken from code evidence and the spikes. See
  [PLAN](PLAN.md#decisions).

## Guardrails

- Turns are derived from the rendered messages on every build. Nothing about
  turns is stored, cached or sent over the wire in phase 1.
- Client code stays harness-neutral. Harness differences go into
  `docs/HARNESS_CAPABILITIES.md`, never into a client branch.
- Automation never opens a turn and is never a sticky prompt. Only a turn's
  opener is sticky.
- One global fold state, held by `SessionDetailCubit`. No per-turn or
  persisted fold state. Every control switches it through the cubit's single
  intent.
- No PR exposes a fold control before place-keeping (step 5) has merged.
- Platform key policy stays in the desktop shell. Shared code binds only the
  activators it is given.
- The transcript stays a reversed lazy `ListView`. No sliver or non-reversed
  rebuild.
- A pinch that starts while the list is detached never re-attaches it.
- Step 7 does not close until pinch has been checked on a real iPhone and on a
  real macOS trackpad.

## Steps

| Step | Branch | Title | Target (changed lines) | Needs |
|---|---|---|---|---|
| 1 | `turn-navigation/plan` | [1](#fixed-pr-titles) | ≤ 1,100 | — |
| 2 | `turn-navigation/turn-model` | [2](#fixed-pr-titles) | ≤ 600 | 1 |
| 3 | `turn-navigation/claude-queued-commands` | [3](#fixed-pr-titles) | ≤ 700 | 1 |
| 4 | `turn-navigation/fold-turns` | [4](#fixed-pr-titles) | ≤ 700 | 2, 3 |
| 5 | `turn-navigation/keep-place` | [5](#fixed-pr-titles) | ≤ 500 | 4 |
| 6 | `turn-navigation/fold-controls` | [6](#fixed-pr-titles) | ≤ 650 | 5 |
| 7 | `turn-navigation/pinch` | [7](#fixed-pr-titles) | ≤ 600 | 6 |
| 8 | `turn-navigation/sticky-prompt` | [8](#fixed-pr-titles) | ≤ 650 | 6 |
| 9 | `turn-navigation/desktop-index` | [9](#fixed-pr-titles) | ≤ 850 | 8 |
| 10 | `turn-navigation/retire` | [10](#fixed-pr-titles) | ≤ 250 | 2–9 |

Step 3's target includes regenerated DTO output. Step 4's includes the
regenerated `SessionDetailState` output. Steps 4, 6, 8 and 9 include
generated localization files.

## Fixed PR Titles

1. `🌿 [turn-navigation] Plan folded turns, sticky prompts and pinch navigation [step 1/10]`
2. `🌿 [turn-navigation] Derive transcript turns from loaded messages [step 2/10]`
3. `⚙️ [turn-navigation] Keep Claude follow-ups and queued automation after history load [step 3/10]`
4. `⚙️ [turn-navigation] Render folded turns from the session fold state [step 4/10]`
5. `⚙️ [turn-navigation] Keep the reader's turn in place when turns fold or unfold [step 5/10]`
6. `🌿 [turn-navigation] Fold and unfold every turn from the bar and the keyboard [step 6/10]`
7. `⚙️ [turn-navigation] Pinch to fold and unfold turns on touch and trackpad [step 7/10]`
8. `⚙️ [turn-navigation] Pin the current turn's prompt while reading it [step 8/10]`
9. `⚙️ [turn-navigation] Add the desktop turn index [step 9/10]`
10. `🌱 [turn-navigation] Reconcile the docs, record the matrix and retire the plan [step 10/10]`
