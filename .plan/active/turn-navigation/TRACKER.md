# Turn Navigation — Tracker

This tracker holds decisions, guardrails and the fixed PR titles only. It
does not mirror PR state. Live status is on GitHub:
`gh pr list --state all --search "[turn-navigation]"`. Evidence for a finished
step lives in `steps/step-NN.md`, written only by that step's own PR.

## Decisions In Force

- D1–D8 are the user's decisions of 2026-09-25 (round 3: R5 rows, D2 desktop).
- D9–D18 are defaults adopted without individual answers. The user may
  override any of them.
- D19–D23 are planning decisions, taken from code evidence and the spikes.
- **D24–D31 are the user's decisions of 2026-09-26**, after rejecting the
  shipped in-place fold on a real device. They replace the fold with a separate
  Prompts screen and supersede D1, D6's index pane, D9, D10, D13's numbering
  clause, D15, D16, D17 and D18, and narrow D8.
- D32–D37 are defaults adopted for the Prompts screen without individual
  answers. The user may override any of them.
- **D38–D39 are the user's decisions of 2026-09-26, round 4.** The bridge keeps
  the ACP prompt instant it already computes, so prompts Sesori sent are timed on
  all harnesses while prompts read back from a harness's own history stay undated
  (supersedes D31's "the bridge does not stamp its own time"); and the prompt list
  keeps the transcript's chronological order and opens anchored on the prompt the
  reader was nearest (supersedes D34).

See [PLAN](PLAN.md#decisions) for each one, including which are superseded.

## Guardrails

- Turns and the prompt list are derived from the rendered messages on every
  build. Nothing about turns is stored or cached.
- **The transcript never folds, never relayouts and never moves when the
  Prompts screen opens or closes.** Any change that makes the transcript
  reflow on entry or exit is a bug, not a tuning problem.
- Client code stays harness-neutral. Harness differences go into
  `docs/HARNESS_CAPABILITIES.md`, never into a client branch.
- Automation never opens a turn and is never a sticky prompt or a Prompts row.
- Platform key policy stays in the desktop shell. Shared code binds only the
  activators it is given.
- The transcript stays a reversed lazy `ListView`. No sliver or non-reversed
  rebuild. The Prompts screen is a new non-reversed `CustomScrollView` and is
  free to use pinned slivers.
- A pinch that starts while the list is detached never re-attaches it.
- Only one owner opens the Prompts screen and applies its result:
  `SessionDetailBody`'s state. It owns the open flag, the transition controller
  and the jump notifier. The pinch, the phone bar button and the desktop toolbar
  button all go through its one open method. `SessionDetailLoadedView` only
  forwards the jump notifier to the message list.
- Row numbers come from the bridge or not at all. No client-side numbering
  fallback, and no shim for an older bridge.
- Times and day headers come from `time.created` or not at all. The bridge may
  stamp only an instant it actually observed; nothing is guessed, defaulted or
  invented on either side of the wire, and an undated prompt stays undated and
  groups under "No date".
- The Prompts list is chronological, like the transcript: earlier above, later
  below, each follow-up under its opener. It opens anchored on the prompt the
  reader was nearest, and content already on screen never moves when earlier
  prompts load.
- Step 13 does not close until the pinch entry has been checked on a real
  iPhone and on a real macOS trackpad.

## Steps

Steps 1–8 have merged. Step 9 replaced the rest of the series: the original
step 9 (the always-visible desktop index pane) is dropped and deferred to a later
phase, and the original step 10 (retirement) is renumbered to step 18, as
[PLAN](PLAN.md#superseded-steps) records.

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
| 9 | `turn-navigation/prompts-view-plan` | [9](#fixed-pr-titles) | ≤ 1,500 | 8 |
| 10 | `turn-navigation/prompt-list-model` | [10](#fixed-pr-titles) | ≤ 450 | 9 |
| 11 | `turn-navigation/prompts-screen` | [11](#fixed-pr-titles) | ≤ 1,100 | 10 |
| 12 | `turn-navigation/prompts-transition` | [12](#fixed-pr-titles) | ≤ 350 | 11 |
| 13 | `turn-navigation/prompts-pinch` | [13](#fixed-pr-titles) | ≤ 400 | 12 |
| 14 | `turn-navigation/remove-fold` | [14](#fixed-pr-titles) | ≤ 1,300 | 13 |
| 15 | `turn-navigation/prompt-numbers` | [15](#fixed-pr-titles) | ≤ 900 | 11 |
| 16 | `turn-navigation/prompts-search` | [16](#fixed-pr-titles) | ≤ 900 | 15 |
| 17 | `turn-navigation/docs` | [17](#fixed-pr-titles) | ≤ 400 | 10–16 |
| 18 | `turn-navigation/retire` | [18](#fixed-pr-titles) | ≤ 250 | 2–17 |

Step 9 is documentation only; its target is the plain soft cap, and the whole
diff is this plan and this tracker. Step 3's target includes regenerated DTO output. Step 4's includes the
regenerated `SessionDetailState` output. Steps 4, 6, 8, 11, 14 and 16 include
generated localization files. Step 15's target includes regenerated shared DTO
and client state output, and it also carries D38's ACP prompt stamp: one hook
body, two deleted overrides and mapper tests, which is why its target is 900
rather than 800.

Step 14 is almost all deletion: about 1,050 lines measured from the merged
diffs of steps 4–7 (~285 production, ~580 test, ~105 localization, ~85
documentation). If the turn-model trim it also enables pushes it past target, the
trim lands as step 14.b and the series total becomes 19.

Steps 12 and 15 may run in parallel once step 11 has merged; step 13 follows
step 12, whose transition its focal point feeds. Step 14 must
follow step 13, so no PR leaves the pinch without a destination.

## Fixed PR Titles

Steps 1–8 merged as `[step N/10]`. Those titles are published history and are
left exactly as they were published; only steps 9 onwards carry `/18`.

1. `🌿 [turn-navigation] Plan folded turns, sticky prompts and pinch navigation [step 1/10]` (merged)
2. `🌿 [turn-navigation] Derive transcript turns from loaded messages [step 2/10]` (merged)
3. `⚙️ [turn-navigation] Keep Claude follow-ups and queued automation after history load [step 3/10]` (merged)
4. `⚙️ [turn-navigation] Render folded turns from the session fold state [step 4/10]` (merged, superseded by step 14)
5. `⚙️ [turn-navigation] Keep the reader's turn in place when turns fold or unfold [step 5/10]` (merged, partly superseded by step 14)
6. `🌿 [turn-navigation] Fold and unfold every turn from the bar and the keyboard [step 6/10]` (merged, superseded by step 14)
7. `⚙️ [turn-navigation] Pinch to fold and unfold turns on touch and trackpad [step 7/10]` (merged, repointed by step 13)
8. `⚙️ [turn-navigation] Pin the current turn's prompt while reading it [step 8/10]` (merged, kept)
9. `🌿 [turn-navigation] Replace the in-place fold with a separate Prompts screen in the plan [step 9/18]`
10. `🌿 [turn-navigation] Derive the session's prompt list with its follow-up children [step 10/18]`
11. `⚙️ [turn-navigation] Open a Prompts screen from the session bar [step 11/18]`
12. `🌿 [turn-navigation] Connect the transcript and the Prompts screen with one transition [step 12/18]`
13. `⚙️ [turn-navigation] Pinch the transcript to open the Prompts screen [step 13/18]`
14. `⚙️ [turn-navigation] Remove the in-place transcript fold [step 14/18]`
15. `🚧 [turn-navigation] Number and time prompts from the bridge [step 15/18]`
16. `⚙️ [turn-navigation] Search the loaded prompts from the screen's header [step 16/18]`
17. `🌱 [turn-navigation] Reconcile the turn-navigation documents with what shipped [step 17/18]`
18. `🌱 [turn-navigation] Record the L3 matrix and retire the plan [step 18/18]`

