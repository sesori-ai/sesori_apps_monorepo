# Instant New Session: Tracker

## Steps

| Step | PR title | Status | Notes |
|---|---|---|---|
| 1/7 | 🌿 [instant-new-session] Plan opening new sessions instantly [step 1/7] | In review | Removes the superseded `instant-session-launch` plan. Reworked for Q3 and Q4, then for the settled D1–D9 and the code review |
| 2/7 | ⚙️ [instant-new-session] Show the first message while a new session is created [step 2/7] | Planned | Instant screen only; composer still replaced while sending |
| 3/7 | 🚧 [instant-new-session] Hand the first message off to the session screen [step 3/7] | Planned | Introduces the launch owner, including the typed outcome stream |
| 4/7 | 🚧 [instant-new-session] Keep the composer live and queue follow-up messages [step 4/7] | Planned | Q3. Delivery is owned by `SessionLaunchService`, not the session screen |
| 5/7 | ⚙️ [instant-new-session] Show a launching row in the session lists [step 5/7] | Planned | Q4 part 1. Row is tappable (D3) and the failure alert listener lands here (D5) |
| 6/7 | ⚙️ [instant-new-session] Show a launching row in the sidebar and Activity [step 6/7] | Planned | Q4 part 2 |
| 7/7 | 🌿 [instant-new-session] Run new-session coverage and retire the plan [step 7/7] | Planned | Coverage, cleanup audit, retire |

No step is blocked: every decision is settled. Each implementation step edits the
regression documents its own PR makes true, so there is no separate
reconciliation step and no window where the regression source of truth is stale.

## Review Page Answers

Answered 2026-09-26:

| Q | Answer | Effect on the plan |
|---|---|---|
| Q1 | A — sending bubble only, "Sending to `<harness>`…" after ~2 s, top bar "New session" | None. Existing widgets and strings already do exactly this |
| Q2 | A — failure returns to the composer with everything restored, warning kept | None for the first message; opened **D1** for follow-ups |
| Q3 | B — the composer stays available; extra messages queue and send in order | **Changed the plan.** Added step 4 |
| Q4 | B — a placeholder row appears in every session-row surface and is swapped or removed | **Changed the plan.** Added steps 5 and 6 |
| Q5 | A — no harness pre-warming now; revisit after step 3 ships | Recorded in the later phase |

## Decisions

D1 to D9 were answered by the user on 2026-09-26. D10 and D11 are the plan's own
recorded decisions. Nothing is open.

| ID | Decision | Settled as | Recommendation overridden? |
|---|---|---|---|
| D1 | Queued follow-ups when creation fails | Appended into the restored composer draft, blank-line separated, in order; follow-up attachments re-staged, a command follow-up appended as literal text | **Yes** — the plan had recommended keeping them as pending bubbles |
| D2 | What the placeholder row shows | Prompt's first line as the title, animating sparkle, harness name on the meta line, no time; leads Today | No |
| D3 | Can the placeholder row be tapped | **Yes.** "Creating…" before the harness name on the same meta line as the in-row signal, plus a tap that shows one alert saying the session is still being created. No menu, no swipe, no palette entry | **Yes** — the plan had recommended an inert row |
| D4 | The placeholder vs the quick-filter chips and search | Excluded from all three chip counts; hidden while searching and in archived | No |
| D5 | Failure after the user left the route | Remove the row and show one popup alert naming the project, from a shell-level outcome listener, suppressed when the composing route already reported it | No |
| D6 | More than one launch at a time | Supported; each launch has its own row | No |
| D7 | Mobile voice resources during creation | Voice stays available while creating | No |
| D8 | The desktop composer moves at Send | Animated once at Send, 240 ms, none under reduced motion; the pane's idle chrome is hidden in the same movement | No |
| D9 | Options at Send | Locked at Send; only text, attachments and command entry stay live | No |
| D10 | Follow-ups and the positional release | Only the first message is released by position; follow-up ids are excluded from the predicate | n/a (plan decision) |
| D11 | Queued attachment bytes | No cap, matching the existing session queue | n/a (plan decision) |

## Architecture Reviews

| Pass | Date | Result | Summary |
|---|---|---|---|
| 1 | 2026-09-26 | Rejected, 3 findings, all applied | Routing no longer reads a repository; one launch type and one shared widget replace two mappings; the first message no longer reuses `QueuedSessionSubmission` |
| 2 | 2026-09-26 | Rejected, 11 findings, all applied | Re-reviewed because Q3 and Q4 changed the plan considerably. Details below |

Pass 2 confirmed as sound: the launch family's layer placement, the
first-message/follow-up split, the keyed launch map over a single slot, the
placeholder as a separate field rather than a synthetic `Session`, and the step
boundaries including the accepted step 2 / step 4 layout churn. Two things it
approved were later changed by the code review: follow-up delivery no longer
reuses `SessionDetailCubit`'s `PromptSendQueue` (it cannot depend on a route
existing), and the launch is sealed into three variants so the handoff can be
consumed without destroying the row association.

| # | Finding | Resolution |
|---|---|---|
| 1 | The launch's terminal transitions were owned by `NewSessionCubit`, which is closed mid-flight — so an abandoned launch would never send its follow-ups, never lose its placeholder row, and never free its attachment bytes | Added `SessionLaunchService` (Layer 3) owning `start → create → promote \| fail` and the two analytics events. `NewSessionCubit` renders the launch instead of awaiting the response |
| 2 | `SessionLaunch.sessionId` was a nullable coordination field, making "created launch still drawing a placeholder row" representable | Sealed variants; the row stream carries only pending launches |
| 3 | `followUps` lived both in `NewSessionPhaseSending` and in the launch, giving one list two writers | The launch is the sole owner; the sending phase carries only the `launchId` |
| 4 | Two missed list paths: `session_list_content.dart:212`'s `sessions.isEmpty` empty state, and `PregoAnimatedSliverList`'s `itemKey` identity across the swap | Empty state counts pending launches; row identity resolves through the launch, with the offset assertion as the gate and a no-animation fallback |
| 5 | The phone-home membership bullet was a handwave and its premise was wrong (a new session is running and unseen, so it already enters Activity) | `SessionActivityProjection` is unchanged; launches arrive as a separate pending list beside it |
| 6 | `harnessName: null` in the detail loading branch was justified by a false claim; `harnessDisplayName` duplicated `pluginId` | The launch's plugin id flows into the loading branch; the launch stores `pluginId` only |
| 7 | `NewSessionCreated.submission` re-added a second carrier with no reader | Dropped |
| 8 | Follow-up bubbles would vanish for the whole detail load | `SessionDetailLoading` carries `launchFollowUps` and renders them |
| 9 | The release rule was enforced at four of fifty-plus loaded-emission sites | One pure predicate plus one `_emitLoaded` funnel |
| 10 | `generatePromptId()` had no named home and `_promptIdRandom` was unmentioned | New `foundation/identity/prompt_id.dart`, both moving together |
| 11 | D5 was blocked on the wrong step | Now lands with steps 5 and 6 |

Two further reviewer observations, applied: the submission-model relocation
moved from step 3 into step 2 so step 3 is behaviour only, and a pre-approved
`3.a`/`3.b` split is recorded in case step 3's real diff exceeds about
1,200 lines.

## Code Review (2026-09-26)

Thirteen findings on the plan PR. Eleven accepted, two rejected as
disproportionate and recorded as accepted limits instead.

| # | Finding | Verdict |
|---|---|---|
| 1 | Regression docs were deferred to a later step | Accepted. Each behaviour-changing step now edits its own documents; the reconciliation step is gone and the series is seven PRs |
| 2 | The desktop handoff fade was justified by "identical content", which is false | Accepted in substance. The false rationale is replaced, the sending pane now hides its idle chrome, and the honest claim is that the bubble holds its rect while only the toolbar changes. The fade itself is kept on purpose: an instant cut would snap the differing toolbar. Verified on all three desktop surfaces in the final step |
| 3 | Carry the launch through `SessionDetailHarnessUnavailable` | Rejected as disproportionate; recorded as an accepted limit beside the failed-load case. That state additionally requires `!canInteract`, so it needs the harness to become blocked between a successful create and the first load, and the state explains its own empty transcript |
| 4 | Use `post`'s existing `timeout` instead of widening `postWithTimeout` | Accepted. `post` already takes a timeout and already reports non-sensitive responses; no client signature changes |
| 5 | A launch command producing no echo never releases the bubble | Rejected as machinery; recorded as an accepted limit with its concrete condition (a no-echo command as the very first message) and its self-correction on reopen |
| 6 | The row association is destroyed by `promote` plus `takeForSession` before the lists reconcile | Accepted. The launch is sealed into a third reconciling variant, the association is published on its own stream, `takeHandoff` takes only the payload, and each list latches the association while it draws a placeholder |
| 7 | `state.extra` is prohibited for the phone transition marker | Accepted. The marker is a route query parameter on the typed session-detail route |
| 8 | No observable terminal outcome carries the `Session` or the failure reason | Accepted. A sealed `SessionLaunchSucceeded`/`SessionLaunchFailed` outcome stream, also used by D5's alert |
| 9 | A drained follow-up in `bridgeQueuedPrompts` would release the first bubble | Accepted. The predicate excludes the launch's follow-up ids |
| 10 | Follow-ups would strand when the user leaves before creation finishes | Accepted. Delivery moves to `SessionLaunchService`; the session screen renders launch follow-ups it does not own |
| 11 | `NewSessionSelectionTracker.clearIfRevision` would be lost in the move | Accepted. The cubit clears the captured revision when it observes a successful outcome; the tracker stays with the composer |
| 12 | The diagnostic `loge` on creation failure would be lost | Accepted. The service keeps it with the original error and operation context |
| 13 | PR title and body still said a five-step series | Accepted. Title and body updated to the current total |
