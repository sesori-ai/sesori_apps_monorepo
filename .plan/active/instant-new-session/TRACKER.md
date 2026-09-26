# Instant New Session: Tracker

## Steps

| Step | PR title | Status | Notes |
|---|---|---|---|
| 1/7 | 🌿 [instant-new-session] Plan opening new sessions instantly [step 1/7] | In review | Removes the superseded `instant-session-launch` plan. Reworked for Q3 and Q4, then for the settled D1–D9, then for three code-review waves |
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
| D5 | Failure after the user left the route | Remove the row and show one popup alert naming the project, from a shell-level outcome listener that only matches `SessionLaunchFailedAfterLeaving`, so a still-composing route's failure never reaches it | No |
| D6 | More than one launch at a time | Supported; each launch has its own row | No |
| D7 | Mobile voice resources during creation | Voice stays available while creating | No |
| D8 | The desktop composer moves at Send | Animated once at Send, 240 ms, none under reduced motion; the pane's idle chrome is hidden in the same movement | No |
| D9 | Options at Send | Locked at Send; only text, attachments and command entry stay live | No |
| D10 | Follow-ups and the positional release | Only the first message is released by position; **every** promptId the launch minted, accepted or not, is excluded from the predicate | n/a (plan decision) |
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
approved were later changed by the first code-review wave: follow-up delivery no
longer reuses `SessionDetailCubit`'s `PromptSendQueue` for the drain (it cannot
depend on a route existing), and the launch is sealed into three variants so the
handoff can be consumed without destroying the row association. The second wave
then stated the whole lifetime once and removed `complete`.

| # | Finding | Resolution |
|---|---|---|
| 1 | The launch's terminal transitions were owned by `NewSessionCubit`, which is closed mid-flight — so an abandoned launch would never send its follow-ups, never lose its placeholder row, and never free its attachment bytes | Added `SessionLaunchService` (Layer 3) owning `start → create → promote \| fail` and the two analytics events. `NewSessionCubit` renders the launch instead of awaiting the response |
| 2 | `SessionLaunch.sessionId` was a nullable coordination field, making "created launch still drawing a placeholder row" representable | Sealed variants. (The second code-review wave later moved the *row's* disappearance from the variant to the drawing surface, so at most one row per `launchId` exists and it never blinks out; see that wave's finding 3) |
| 3 | `followUps` lived both in `NewSessionPhaseSending` and in the launch, giving one list two writers | The launch is the sole owner of the follow-up **list**. (The second code-review wave found that dropping the phase's `submission` too went further than this finding asked and left the composing view with no source; the phase keeps `submission` and owns no follow-ups) |
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

## Code Review, first wave (2026-09-26)

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
| 8 | No observable terminal outcome carries the `Session` or the failure reason | Accepted. A sealed outcome stream, also used by D5's alert. (The second wave split its failure case into `…FailedWhileComposing` and `…FailedAfterLeaving`, so exactly one reader acts on each) |
| 9 | A drained follow-up in `bridgeQueuedPrompts` would release the first bubble | Accepted. The predicate excludes the launch's follow-up ids |
| 10 | Follow-ups would strand when the user leaves before creation finishes | Accepted. Delivery moves to `SessionLaunchService`; the session screen renders launch follow-ups it does not own |
| 11 | `NewSessionSelectionTracker.clearIfRevision` would be lost in the move | Accepted. The cubit clears the captured revision when it observes a successful outcome; the tracker stays with the composer |
| 12 | The diagnostic `loge` on creation failure would be lost | Accepted. The service keeps it with the original error and operation context |
| 13 | PR title and body still said a five-step series | Accepted. Title and body updated to the current total |

## Code Review, second wave (2026-09-26)

Fourteen findings after the D1–D9 rework (12 × P1, 2 × P2). Thirteen accepted,
one rejected. Four of them turned out to be one seam — the launch's lifetime — so
they are answered once, by the new "The launch's lifetime, stated once" subsection
in `PLAN.md`, rather than patched in four places.

| # | Finding | Verdict |
|---|---|---|
| 1 | The failure outcome carried no restoration payload, while `fail` removed the only copy | Accepted, narrowed. The first submission is restored from `NewSessionPhaseSending.submission`, which exists today; the **follow-ups** had no other owner, so `SessionLaunchFailedWhileComposing` carries them |
| 2 | `releaseHandoff` was defined only created → reconciling, so a pending abandon was undefined | Accepted (lifetime seam). Release is defined on any variant and drops the payload; `promote` of a released pending launch yields a reconciling launch. The cubit releases only when it never reported success |
| 3 | The row vanished at `promote` while the association produced none, leaving an emission with neither | Accepted (lifetime seam). A surface holds the placeholder it drew until its own snapshot contains the session; stated once in the lifetime rule and applied in steps 5 and 6 |
| 4 | Move the row-key reconciliation into a Cubit per the BLoC-only rule | **Rejected.** The mapping is published by `SessionLaunchRepository` and read through `SessionLaunchCubit`; what the widget holds is which key one `PregoAnimatedSliverList` item keeps. It lives in `SessionListContent` alone — the only step 5 widget using that list, composed by all three hosts — with the same precedent as `desktop_sidebar.dart`'s `_stickyActivitySessionId`/`_activitySessionIds`. The plan now names the location and scope explicitly |
| 5 | Two listeners on one broadcast failure with no claim could both fire | Accepted. The failure outcome is sealed into `…FailedWhileComposing` and `…FailedAfterLeaving`, decided by whether the payload was released. One value, one reader, no flag |
| 6 | Follow-up Retry went to the repository, which has no sender | Accepted. `SessionLaunchService.retryFollowUp(launchId:, promptId:)` re-enters the serial delivery loop; cancel stays on the repository |
| 7 | A Layer 0 `SessionLaunch` holding `QueuedSessionSubmission` from `cubits/` is a Foundation → Layer 4 dependency | Accepted. `queued_session_submission.dart` moves to `foundation/models/composer/` in step 2, beside the submission snapshot |
| 8 | The composing cubit had no source for the submission it must keep rendering | Accepted; the plan was internally inconsistent. The sending phase keeps its existing `submission` and gains `launchId`/`startedAt`; follow-ups come from the new `watch(launchId:)` in step 4 |
| 9 | Nothing re-evaluated completion after `takeHandoff` cleared the payload | Accepted (lifetime seam). `complete` is removed; the repository removes an entry when nothing is owed, after every transition it performs |
| 10 | Accepted follow-ups were dropped immediately, blanking the bubble and evading the release exclusion | Accepted. `followUpIds` retains every minted id for the predicate, and an accepted follow-up parks in the session screen's existing slot via a new `PromptSendQueue.adoptAccepted`, matching the `parkAccepted` rule the cubit already documents |
| 11 | Service-delivered follow-ups bypass `sessionMessageSent` and the positive-interaction record | Accepted; the plan's claim that "the existing session path" reports them was wrong. The service reports both, same event, same parameters |
| 12 | D1's merged attachments bypass the budget check, because restoration uses `_attachments.addAll` | Accepted. Restoration stages through `_stageAttachment`, so the existing limit and notice actually run |
| 13 | The bubble's 2 s slow-send timer restarts on each widget replacement, so "Sending to `<harness>`…" reverts | Accepted; verified per-`State` in `queued_message_bubble.dart:59-86`. The launch carries `startedAt` and the sending presentation gains `sendingSince`, so each rendering initialises from elapsed time |
| 14 | The Activity hosts relayout instantly, since they use a plain `SliverList.list` and `Column` | Accepted. Both wrap the pending rows in a 240 ms height transition, instant under reduced motion, reusing D8's idiom. The sidebar needs nothing, being an animated list already |

## Code Review, third wave (2026-09-26)

Eight findings (5 × P1, 3 × P2), all accepted. Three sharpened the lifetime rule
in `PLAN.md` ("The launch's lifetime, stated once") instead of adding branches;
the rest are local.

| # | Finding | Verdict |
|---|---|---|
| 1 | Launch follow-ups were bare `QueuedSessionSubmission`s, so a failed one could not be told from a pending one or show its reason | Accepted. Sealed `LaunchFollowUp` (queued, sending, accepted, failed), shaped like the existing `LocalSendPhase`; only the failed variant carries `PromptSendFailure`, which moves to `foundation/models/composer/` in step 2. A failed follow-up is now owed until the user retries or removes it |
| 2 | Retaining an accepted follow-up depended on a screen already being open, so one accepted before the replacement screen mounted blanked | Accepted (lifetime rule). An accepted follow-up belongs to the handoff: held on the launch until the handoff is taken (and then parked by the taker) or released, whether or not a screen existed at acceptance |
| 3 | `session.created` reaches the lists before the first activity statement, so the Activity placeholder detoured through Recent | Accepted (lifetime rule). A placeholder is held until the surface would draw the real row in its slot — the projection's Activity entry on Activity hosts, the head of Today in a session list — and the surface leaves the session out of its other sections meanwhile. A one-update bound stops a first command that never runs from leaving "Creating…" behind; the residual early-release window is recorded as a risk |
| 4 | Moving creation into the service dropped `recordPositiveInteraction` / `recordFailure` | Accepted. Both move into `SessionLaunchService` with the creation outcome; follow-up failures also record a failure |
| 5 | The empty-state check counted launches D4 hides while searching, leaving a blank page | Accepted. The empty state counts only launch rows the list actually draws |
| 6 | Unsent composer content (text, staged command, attachments) was lost at the route replacement, and the text reappeared in a later new session | Accepted. The handoff carries an `UnsentComposer`; `NewSessionCubit` hands it over before emitting `created` and clears the new-session draft key, and the detail composer starts from it |
| 7 | Sidebar Activity gates ignored pending-only launches | Accepted. The rail trigger, expanded header and popout-close gates, and the group list, count pending rows; the phone home's Activity gate does too |
| 8 | Service-owned follow-up send failures lost the detail cubit's `logw` with the original error and stack | Accepted. The service logs both failure paths with the original error, stack trace and launch/prompt/session context |
