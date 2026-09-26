# Instant New Session: Tracker

## Steps

| Step | PR title | Status | Notes |
|---|---|---|---|
| 1/8 | 🌿 [instant-new-session] Plan opening new sessions instantly [step 1/8] | In review | Removes the superseded `instant-session-launch` plan. Reworked for Q3 and Q4. |
| 2/8 | ⚙️ [instant-new-session] Show the first message while a new session is created [step 2/8] | Planned | Instant screen only; composer still unmounted while sending |
| 3/8 | 🚧 [instant-new-session] Hand the first message off to the session screen [step 3/8] | Planned | Introduces the launch owner in its minimal form |
| 4/8 | 🚧 [instant-new-session] Keep the composer live and queue follow-up messages [step 4/8] | Planned | Q3. Blocked on **D1** |
| 5/8 | ⚙️ [instant-new-session] Show a launching row in the session lists [step 5/8] | Planned | Q4 part 1. Blocked on **D2**, **D3**, **D4** |
| 6/8 | ⚙️ [instant-new-session] Show a launching row in the sidebar and Activity [step 6/8] | Planned | Q4 part 2. Blocked on **D2**, **D3** |
| 7/8 | 🌱 [instant-new-session] Reconcile new-session regression coverage [step 7/8] | Planned | |
| 8/8 | 🌿 [instant-new-session] Run new-session coverage and retire the plan [step 8/8] | Planned | |

As implementation steps merge, record their regression-document deltas here.
Step 7 reconciles them.

## Review Page Answers

Answered 2026-09-26:

| Q | Answer | Effect on the plan |
|---|---|---|
| Q1 | A — sending bubble only, "Sending to `<harness>`…" after ~2 s, top bar "New session" | None. Existing widgets and strings already do exactly this |
| Q2 | A — failure returns to the composer with everything restored, warning kept | None for the first message; opens **D1** for follow-ups |
| Q3 | B — the composer stays available; extra messages queue and send in order | **Changed the plan.** Added step 4 |
| Q4 | B — a placeholder row appears in every session-row surface and is swapped or removed | **Changed the plan.** Added steps 5 and 6 |
| Q5 | A — no harness pre-warming now; revisit after step 3 ships | Recorded in the later phase |

## Open Decisions

These are written up in `PLAN.md` under "Open Decisions" and are going onto the
next review page. Each has a recommended default; none is settled.

| ID | Decision | Recommended default | Blocks |
|---|---|---|---|
| D1 | Queued follow-ups when creation fails | Keep them queued as cancellable pending bubbles; do **not** append them into the draft, which would drop their attachments | 4/8 |
| D2 | What the placeholder row shows | Prompt's first line, running sparkle, harness name, no time; leads Today | 5/8, 6/8 |
| D3 | Can the placeholder row be tapped | No — inert, no tap, menu or swipe | 5/8, 6/8 |
| D4 | The placeholder vs the quick-filter chips and search | Excluded from counts; hidden while searching or archived | 5/8 |
| D5 | Failure after the user left the route (product half only; the owner is settled) | Remove the row and show one popup alert naming the project | 5/8, 6/8 |
| D6 | More than one launch at a time | Support several, each with its own row | 3/8 |
| D7 | Mobile voice resources during creation | Accept that they stay open while the composer is mounted | 4/8 |
| D8 | The desktop composer moves at Send | Accept, animated once at 240 ms | 4/8 |
| D9 | Options stay locked while creating | Yes; only text, attachments and command entry are live | 4/8 |
| D10 | Follow-ups and the positional release | Only the first message is released by position | 3/8, 4/8 |
| D11 | Queued attachment bytes | No cap, matching the existing session queue | 4/8 |

## Architecture Reviews

| Pass | Date | Result | Summary |
|---|---|---|---|
| 1 | 2026-09-26 | Rejected, 3 findings, all applied | Routing no longer reads a repository; one launch type and one shared widget replace two mappings; the first message no longer reuses `QueuedSessionSubmission` |
| 2 | 2026-09-26 | Rejected, 11 findings, all applied | Re-reviewed because Q3 and Q4 changed the plan considerably. Details below |

Pass 2 confirmed as sound: the launch family's layer placement, reusing
`PromptSendQueue` for follow-ups, the first-message/follow-up split, the keyed
launch map over a single slot, the placeholder as a separate field rather than a
synthetic `Session`, and the eight-step boundaries including the accepted
step 2 / step 4 layout churn.

| # | Finding | Resolution |
|---|---|---|
| 1 | The launch's terminal transitions were owned by `NewSessionCubit`, which is closed mid-flight — so an abandoned launch would never send its follow-ups, never lose its placeholder row, and never free its attachment bytes | Added `SessionLaunchService` (Layer 3) owning `start → create → promote \| finish` and the two analytics events. `NewSessionCubit` renders the launch instead of awaiting the response |
| 2 | `SessionLaunch.sessionId` was a nullable coordination field, making "created launch still drawing a placeholder row" representable | Sealed into `PendingSessionLaunch` / `CreatedSessionLaunch`; the list stream carries only pending ones |
| 3 | `followUps` lived both in `NewSessionPhaseSending` and in the launch, giving one list two writers | The launch is the sole owner; the sending phase carries only the `launchId` |
| 4 | Two missed list paths: `session_list_content.dart:212`'s `sessions.isEmpty` empty state, and `PregoAnimatedSliverList`'s `itemKey` identity across the swap | Empty state now counts pending launches; row identity resolves through the launch while it exists, with the offset assertion as the gate and a no-animation fallback |
| 5 | The phone-home membership bullet was a handwave and its premise was wrong (a new session is running and unseen, so it already enters Activity) | `SessionActivityProjection` is unchanged; launches arrive as a separate pending list beside it |
| 6 | `harnessName: null` in the detail loading branch was justified by a false claim and would have made the bubble's copy regress across the swap; `harnessDisplayName` also duplicated `pluginId` | The launch's plugin id flows into the loading branch; the launch stores `pluginId` only and both seams derive the name |
| 7 | `NewSessionCreated.submission` re-added a second carrier with no reader | Dropped |
| 8 | Follow-up bubbles would vanish for the whole detail load | `SessionDetailLoading` carries `launchFollowUps` and renders them |
| 9 | The release rule was enforced at four of fifty-plus loaded-emission sites | One pure predicate plus one `_emitLoaded` funnel |
| 10 | `generatePromptId()` had no named home and `_promptIdRandom` was unmentioned | New `foundation/identity/prompt_id.dart`, both moving together |
| 11 | D5 was blocked on the wrong step | Now blocks 5/8 and 6/8 |

Two further reviewer observations, applied: the submission-model relocation
moved from step 3 into step 2 so step 3 is behaviour only, and a pre-approved
`3.a`/`3.b` split is recorded in case step 3's real diff exceeds about
1,150 lines.
