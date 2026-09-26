# Instant New Session

## Status

- **Plan slug:** `instant-new-session`
- **Status:** Proposed (2026-09-26)
- **Implementation base:** `main` at `654519baf1`
- **Supersedes:** `.plan/active/instant-session-launch/` (planned 2026-08-31,
  never implemented). This plan is removed in the same PR. Its client-side
  design (showing the first message as a chat bubble, handing it off to the
  session screen, and releasing it by position) carries over in a simpler
  form. Its wire and bridge work (`launchId` and `session.create.progress`
  stages) moves to the rough later phase below. That plan also predates
  desktop session creation and the move of the new-session view into
  `module_app_ui`.
- **Delivery:** seven numbered PRs. Step 1 raises this plan.
- **Review page answers applied (2026-09-26).** The user answered five
  questions. Two of them changed the shape of this plan:
  - **Q1 A** — while creating, the page shows only the user's message as a
    sending bubble; after about 2 s a muted line reads "Sending to
    `<harness>`…"; the top bar reads "New session". Already satisfied by
    existing widgets (see Current Flow).
  - **Q2 A** — creation failure returns to the composer with text,
    attachments and slash command restored exactly as today, and keeps
    today's duplicate-risk warning when the outcome is uncertain.
  - **Q3 B (changed the plan)** — the composer **is** available while the
    session is being created. Extra messages typed then are queued and sent
    in order once the session exists. Added as step 4.
  - **Q4 B (changed the plan)** — a placeholder row appears immediately
    wherever session rows appear, is swapped for the real row when the bridge
    saves the session, and is removed if creation fails. Added as steps 5
    and 6.
  - **Q5 A** — do not plan harness pre-warming now; revisit after step 3
    ships.
- **Architecture review (2026-09-26, first pass):** rejected with three
  findings, all applied:
  - The shell routing no longer reads a repository; the transition is decided
    per `onSessionCreated` call site, and each desktop route is named.
  - One launch type and one shared widget replace the two mappings.
  - The handoff no longer reuses `QueuedSessionSubmission` for the **first**
    message, whose queue-only variant and wire promptId cannot apply to a
    launch. Follow-ups added by Q3 are a different case and do use it; see
    "Two submission kinds, on purpose".
- **Architecture review (2026-09-26, second pass):** the Q3/Q4 rework is
  considerable, so the plan was reviewed again. Rejected with eleven findings,
  all applied directly. The three structural ones:
  - the launch's outcome is now owned by a Layer 3 `SessionLaunchService`, not
    by the route-scoped `NewSessionCubit` that is closed mid-flight;
  - `SessionLaunch` is sealed into pending and created variants instead of
    carrying a nullable `sessionId`;
  - the follow-up list has one owner (the launch) instead of being mirrored
    into cubit state.

  All eleven findings and their resolutions are tabulated in `TRACKER.md`.
- **Decisions D1 to D9 answered by the user (2026-09-26).** Nothing in this plan
  is open any more. The "Decisions" section records each answer and its
  consequences; D10 and D11 remain the plan's own recorded decisions and were
  never user questions. Two answers overrode this plan's recommendation and the
  plan now follows the answer, not the recommendation:
  - **D1** — failed-creation follow-ups are appended into the restored composer
    draft, separated by blank lines.
  - **D3** — the placeholder row **is** tappable, tells the user the session is
    still being created, and carries a visible in-progress signal of its own.
- **Code review applied (2026-09-26, 13 findings).** Eleven changed the plan:
  regression documents now move with the step that changes behaviour (which
  removes the old step 7 and makes the series seven PRs), creation reuses
  `RelayHttpApiClient.post`'s existing `timeout` argument instead of widening
  `postWithTimeout`, the phone transition travels as a route query parameter
  rather than `state.extra`, the launch owner publishes a typed terminal
  outcome and keeps the launch↔session association past the handoff,
  follow-up **delivery** belongs to `SessionLaunchService` instead of the
  detail route, the release predicate ignores follow-up prompt ids, and the
  service keeps both the selection-revision clear and the diagnostic failure
  log. Two findings were rejected as disproportionate and are recorded as
  accepted limits instead: the harness-unavailable state dropping the bubble,
  and a first message that is a command producing no transcript echo.
- **Code review applied (2026-09-26, second wave, 14 findings).** Thirteen
  changed the plan; one was rejected. The launch's lifetime is now stated once,
  in "The Launch Owner", because four findings turned out to be the same seam:
  when an entry is removed, when its payload dies, who is allowed to release it,
  and how long its row is owed. The other changes: `QueuedSessionSubmission`
  moves out of `cubits/` so a Layer 0 launch can hold it, the sending phase keeps
  its existing `submission` field (an earlier sentence wrongly said it carried
  only the `launchId`), the failure outcome is sealed into a restorable and an
  abandoned variant so exactly one reader acts on it, follow-up retry goes
  through the service that owns delivery, an accepted follow-up is parked rather
  than dropped, the bubble's slow-send state is carried across the handoff, the
  merged restored attachments go through the composer's budget check, the
  service reports `sessionMessageSent` for the follow-ups it sends, and the
  Activity hosts get an insertion/removal transition. The rejected finding asked
  to move the animated-list row key into a cubit; see step 5 for why it is
  render identity in two named widgets rather than domain state.
- **Code review applied (2026-09-26, third wave, 8 findings).** All eight changed
  the plan, and three of them sharpened the lifetime rule rather than adding
  branches. The three rule changes: an accepted follow-up now belongs to the
  handoff, whether or not a screen existed when it was accepted; the handoff
  also carries the composer's unsent draft, so text typed but not sent during
  creation reaches the session screen; and a placeholder row is held until its
  surface would draw the real row *in its place*, not merely until the session is
  somewhere in that surface's data. The other five: launch follow-ups are sealed
  into queued, sending, accepted and failed variants; the service keeps the
  creation feedback records and the follow-up failure log; the list's empty state
  counts only launch rows it actually draws; and the sidebar's and phone home's
  Activity gates count pending rows.

## Primary Goal: How This Must Feel

This feature exists only to change how starting a session feels, so the feel
rules in the root `AGENTS.md` are the acceptance criteria, not a footnote:

1. **Opening is instant.** On the next frame after Send, the page is
   session-shaped and shows the user's message. No spinner, no second
   loading screen, no "No messages yet" gap.
2. **The sending bubble must not jump when the real message replaces it.**
   The bubble and the delivered user message are the same widget in the same
   position; the replacement happens in one emission, with no intermediate
   frame that has neither.
3. **The placeholder-to-real row swap must not move the list.** The
   placeholder occupies exactly the slot the real row will occupy, in the
   same row geometry, so the swap changes the row's content and not the
   list's layout.

Any step that cannot hold these three properties is wrong, however correct
its state handling is.

## Goal

Once the user sends the first message of a new session, the app must look like
the session screen at once, on every surface that creates sessions, for every
harness:

1. On the next frame after Send, the page shows the user's message as a
   **sending** bubble. This is the same `QueuedMessageBubble` sending
   presentation that existing sessions use. The page never shows a bare
   spinner.
2. When creation succeeds, the real session screen takes over without a
   visible second navigation. It also skips the second loading screen and the
   "No messages yet" gap. The bubble stays until the harness's own transcript
   shows the message.
3. The composer stays usable throughout. Extra messages typed while the
   session is being created are queued and sent in order once it exists.
4. Every list that shows session rows shows the launch immediately, as a
   placeholder row that becomes the real row.

The real creation time does not change in this plan, but the user no longer
waits on it before seeing the session, and no longer waits on it to keep
typing.

## Current Flow (verified 2026-09-26)

Every creating surface composes the shared `NewSessionView`
(`client/module_app_ui/lib/src/features/new_session/new_session_view.dart`):

- the phone new-session route (`client/app/lib/features/new_session/new_session_screen.dart`);
- the desktop new-session route (`client/desktop/lib/core/routing/desktop_router.dart:176`);
- the desktop project page's embedded composer (`client/desktop/lib/features/sessions/desktop_session_list_screen.dart:186`);
- the desktop home composer (`client/desktop/lib/features/home/desktop_home_pane.dart:236`).

Stages the user sees:

| # | Stage | What it waits for | UI shown |
|---|---|---|---|
| 1 | `NewSessionCubit.createSession` (`new_session_cubit.dart:867`) | Nothing. It emits `NewSessionPhase.sending` synchronously (`:913`). | The composer unmounts and a centered `PregoLaunchStatus` with rotating copy appears (`new_session_view.dart:384`, `:492`). |
| 2 | `POST /session/create` through the relay (`session_api.dart:83`) | One relay round trip plus the whole bridge create. The client times out after 30 s (`relay_http_client.dart:15`). | Launch status |
| 2a | Bridge `ensurePluginRoutable` (`session_creation_service.dart:65`) | Lazy start of the plugin runtime (process spawn, health, ACP `initialize`) | Launch status |
| 2b | Bridge `_prepareWorktree` (`:69`), dedicated mode (the default) | `git fetch` of the base branch (30 s budget), then `git worktree add` | Launch status |
| 2c | Bridge `_resolveWorktreeState` (`:70`), in-place mode | `git rev-parse HEAD` | Launch status |
| 2d | Plugin `createSession` (`session_repository.dart:210`) | Backend session plus first-prompt **acceptance**. Claude spawns a CLI child per session and waits for its `initialize`. Codex waits for `thread/start` and `turn/start`. OpenCode v1 calls `POST /session` then `prompt_async`, and v2 makes 2 to 6 serial HTTP calls. ACP harnesses call `session/new` and dispatch the prompt in the background. Pi admits the turn to a queue. Copilot and Pi may run a catalog probe when the cache is cold. | Launch status |
| 2e | Durable `ses_` binding commit, enrich, response | Database work only | Launch status |
| 3 | `NewSessionCreated`, then `onSessionCreated` and `replaceRoute(sessionDetail)` | Nothing | Platform page transition |
| 4 | `SessionDetailCubit._loadMessages` (`session_detail_cubit.dart:322`) | `/session/detail`, then messages and children, then questions, permissions, statuses, queued prompts, options, and plugins. That is at least three relay round-trip tiers. | The **same** centered `PregoLaunchStatus` again (`session_detail_body.dart:348`) |
| 5 | Loaded | The first user message usually is **not** in the snapshot yet | Empty transcript ("No messages yet") until the echo event lands |

So the user goes through two full-screen loading states and then an empty
transcript before seeing their own message. The composer is inert throughout,
and no list shows the session until the bridge commits it.

### What already satisfies Q1

- The glass scaffold already titles the page `loc.sessionListNewSession`
  ("New session") and already switches `titleMode` to `inline` while sending
  (`new_session_view.dart:480-491`). **No change needed** for Q1's top bar.
- `QueuedMessageBubble` already owns the two-stage sending copy:
  `_slowSendDelay = Duration(seconds: 2)` (`queued_message_bubble.dart:57`),
  then `loc.sessionDetailSendingToHarness(harnessName)` instead of
  `loc.sessionDetailSendingMessage` (`:107-128`). Both strings exist.
- Note for precision: the existing widget shows a small activity indicator and
  the word "Sending" from the **first** frame, and only swaps the text at 2 s.
  `docs/regression/session-turns.md` documents exactly that ("A send still in
  flight after two seconds says 'Sending to `<harness>`…'; before that, and
  when the harness name is unknown, it says 'Sending'"). Q1 is therefore
  satisfied by reusing the widget unchanged; this plan does **not** add a
  new-session-only variant that hides the status for the first 2 s, because
  that would diverge new sessions from every existing session for no gain.

### Measured on a local slot-2 bridge (debug server, no relay, in-place, non-git project, 2026-09-26)

| Harness | `/session/create` | Loads after create | First user message in the snapshot right after create |
|---|---|---|---|
| OpenCode | **16.6 s cold** (server spawn), 66 ms warm | all under 40 ms warm (`/session/detail` 821 ms cold) | no |
| Claude | 0.92 s cold, 0.65 s warm | `/session/options` 1.2 s cold | no |
| Codex | 1.26 s | all under 40 ms | no |
| Pi | 0.24 s | **`/session/messages` 2.47 s**, `/session/options` 0.52 s | no |
| Hermes (ACP) | **5.76 s** (agent spawn) | **`/session/messages` 2.37 s** | yes (synthesized echo) |

Dedicated-worktree mode adds a real `git fetch` of the monorepo (about
0.8 s) and a `git worktree add` (about 0.5 s) in series. Over the relay, each
client request also pays an encrypted round trip, typically 100 to 300 ms, so
stage 4 costs at least three tiers of that. Cold plugin starts dominate, and
their worst-case budgets exceed the client's 30 s create timeout. In that case
a slow creation that still succeeds is reported as an uncertain failure with
the duplicate-risk warning.

## Existing Machinery Reused

- `NewSessionSubmissionSnapshot`
  (`cubits/new_session/new_session_submission_snapshot.dart`) already captures
  the submitted text, voice spans, command, and attachments losslessly, and is
  what failure restoration replays today. Sealed:
  `NewSessionTextSubmissionSnapshot({draft, attachments})` and
  `NewSessionCommandSubmissionSnapshot({draft, command})`. It has no
  `promptId`, no agent/model/fastMode, and no `displayText`.
- `QueuedMessageBubble` with `QueuedMessageBubblePresentation.sending` is the
  existing "sending" look
  (`session_detail/widgets/queued_message_bubble.dart`). Its `pending(onCancel:)`
  presentation is the existing "queued, cancellable" look. `new_session_view.dart`
  already imports `session_detail` widgets, so reusing them adds no new
  cross-feature dependency.
- `PromptSendQueue` (`cubits/session_detail/prompt_send_queue.dart`) is the
  existing FIFO local send queue: `enqueue`, `beginSend` (the single
  serialisation point), `completeSend`, `parkAccepted(epoch:)` and
  `settleAwaitingAbsent` / `reconcileBridgeQueue` (the accepted-but-not-yet-echoed
  slot that keeps a bubble on screen), `failSend` (re-heads), `holdFailedSend`,
  `retryFailedSend` (same promptId, so the bridge dedups), `cancel(index)`.
  It is **not** DI-registered; `SessionDetailCubit` owns the only instance
  (`session_detail_cubit.dart:136`), so it exists only while a session screen
  does. That lifetime is why step 4 keeps it for sends made **from** the session
  screen and does **not** route launch follow-ups through it: their delivery
  cannot depend on a route being open. It stays the reference for the bubble
  presentations, the FIFO rule and the retry vocabulary the launch reuses.
- `QueuedSessionSubmission` (today at
  `cubits/session_detail/queued_session_submission.dart`, moved to
  `foundation/models/composer/` in step 2) is the queue's item type: `promptId`,
  `text`, `command`, `inputMode`, `attachments`, `agent`, `agentModel`,
  `fastMode`, plus `displayText` and `isCommand`. It is already a pure sealed
  value whose only imports are `composer_attachment.dart` and
  `composer_draft.dart`; only its directory is wrong for a Layer 0 holder.
- `SessionDetailCubit.sendMessage` already **enqueues without requiring
  `SessionDetailLoaded`** (`:1985-2042`); only `_drainQueuedMessages` requires
  loaded and connected. That is the existing precedent for "accept now, send
  later"; step 4 applies the same idea one lifetime up, where the session does
  not exist yet either.
- `SessionDetailMessageList` already renders transient submission rows under
  `_kPromptRowPrefix = "session-detail-prompt-"` so one prompt keeps one row
  identity from queued → sending → bridge-queued → delivered
  (`session_detail_message_list.dart:163`, `:482-513`, `:521-524`). That is
  precisely property 2 of the feel goal, already implemented.
- `hasRenderableUserContent` (`session_detail_resolvers.dart:6`) already decides
  whether a user message shows anything.
- `PendingSessionArchiveCubit` is the working template for a cross-shell,
  app-lifetime, presentation-neutral overlay over session lists: defined in
  `module_core`, exported from its barrel, provided above the router on phone
  (`app/lib/main.dart:392-398`) and above the cockpit on desktop
  (`desktop/lib/core/widgets/desktop_cockpit_shell.dart:43`), and read from
  `module_app_ui` widgets. Steps 5 and 6 copy this shape exactly.
- `SessionListService.visibleSessions`
  (`services/session_list_service.dart:32-77`) is the single owner of list
  order: **running sessions first** (`lastUserActivityAt` desc, tie `id` asc),
  then the rest by `time.updated` desc, tie `id` asc. Presentation then forces
  a running session into the **Today** heading whatever its stored time
  (`session_list_content.dart:36`). Steps 5 and 6 depend on this: it is why a
  placeholder row and the real row it becomes occupy the same slot.
- `PregoSkeletonListTile` (`module_prego/lib/components/loaders/prego_skeleton.dart:222`)
  already matches `SessionTile` geometry line for line (24 px title box, 20 px
  detail box, `PregoSpacing.lg` padding). It is the reference for placeholder
  row metrics, not a widget the placeholder uses directly.

## Design Decisions

- **Client only. No wire, bridge, or plugin change in any step.** There is no
  pending session id and no bridge-issued placeholder. The bridge already owns
  session ids, but returning one before the plugin binding commits would add a
  "creating" session state to every session route, every list query, and the
  wire contract. That would be the largest possible change for a perception
  problem.
- **One owner for an in-flight launch, and it is not a route-scoped cubit.**
  Q3 and Q4 both need launch facts to outlive the new-session route: the queue
  must survive the route replacement that hands over to the session screen, and
  the placeholder row must survive the user pressing Back. Creation itself
  already outlives the route — `NewSessionCubit` does `if (isClosed) return;`
  before it handles the response, so a user who leaves mid-create gets no
  success or failure handling at all today. That is tolerable while the only
  casualty is a draft, but with Q3 and Q4 it would mean follow-ups that never
  send and a placeholder row that never disappears. So the **operation** moves
  to a Layer 3 service that outlives every route, and the route-scoped cubit
  becomes a renderer of it. Rather than three separate carriers (a handoff slot,
  a queue, a list overlay), one owner in `module_core` holds one immutable value
  per launch. This is the single most important structural decision in the plan;
  the complexity budget below counts it honestly.
- **Two submission kinds, on purpose.** The **first** message cannot be a
  `QueuedSessionSubmission`: it travels on `POST /session/create`, which
  carries no `promptId`, and no plugin stamps a promptId on the initial echo.
  It therefore stays a `NewSessionSubmissionSnapshot` and is released by
  position (see below). **Follow-ups** are ordinary prompts for a session that
  merely does not exist yet; they get a client-generated `prm_` promptId at
  the moment they are typed and are `QueuedSessionSubmission`s from birth, so
  the existing queue, its dedup, its retry and its rendering all apply
  unchanged. Do not unify these two; the first message genuinely has no wire
  identity and the follow-ups genuinely do.
- **The perceived navigation is presentation.** While sending, `NewSessionView`
  renders a session-shaped body in place, with no route change, so it is
  instant and cannot race. On success, the route is replaced by the real
  session screen, which is pre-seeded with the same bubble. The phone
  replacement runs without a page transition, which is also what
  `docs/regression/navigation-transitions.md` already requires ("The
  new-session page changes in place without a fade … when its first prompt
  turns it into the session"). Desktop keeps its existing 150 ms main-pane
  cross-fade (`_withPageFade`, `desktop_router.dart:270`). The two sides there
  are **not** identical: the destination has a session toolbar, and an embedded
  composer's pane still carries its own chrome (`DesktopFileAccessCard` and the
  home sections on the home pane, the catalog header on a project page). Two
  things make the fade continuity rather than a second navigation, and both are
  required: while sending, the chrome page **hides its `topBar` and `footer`**
  so the pane is already session-shaped (step 4, where the composer also reaches
  the bottom edge), and the bubble occupies the same rect on both sides, so the
  one element the user is reading cross-fades with itself while only the
  surrounding toolbar changes. Reduced motion already makes this instant. An
  instant cut is deliberately **not** chosen: it would snap the differing
  toolbar. The final step verifies this on all three desktop creating surfaces,
  and an observed second-navigation feel is what would switch those routes to an
  instant replacement.
- **The first bubble is released by position, not by promptId.** The initial
  input is accepted before the session exists anywhere else. So in a
  brand-new session, the first user message with renderable content, or the
  first bridge-queued prompt (Claude or Pi command and queue windows), is by
  construction the submitted input. The bubble is dropped in the same emission
  that shows that replacement. Content matching is not used. Follow-ups do not
  participate: they match on their real promptId through the existing path, and
  they are **excluded from the predicate itself**. A follow-up delivered while
  the first message still has no echo appears in `bridgeQueuedPrompts` with a
  promptId the launch already knows, and treating it as the first message's
  replacement would make the first bubble vanish until its own echo arrived. The
  predicate therefore ignores prompts whose id is one of the launch's follow-up
  ids.
- **The placeholder row is not a `Session`.** It is a separate field beside
  `sessions`, never an entry inside it. Synthesising a `Session` with a
  sentinel id would make an impossible state representable and would leak into
  `updateActionSession`, `sessionMenuEntries`, `activeSessionIds`,
  `unseenBySessionId`, `deferredSessions`, the sticky-activity sets, and the
  palette. It would also flip `desktop_session_list_screen.dart:104`'s
  `loaded.sessions.isEmpty`, which currently keeps the embedded composer
  mounted. A separate field keeps every one of those paths untouched.
- **Options lock at Send; only the composer stays live.** Today
  `NewSessionPhaseSending` makes the whole page inert: `canCreateSession`
  (`:597`), `_canEditComposer` (`:560`), `canRefreshOptions` (`:585`),
  `needsHarnessDiscovery` (`:574`), `_canApplyLoad` (`:550`) and
  `_onConnectionStatusChanged` (`:89`) all early-return. Step 4 splits that
  single gate (**D9**, settled): the harness, agent, model, variant and worktree mode stay
  locked, because they are already committed to the request in flight, while
  text, attachments and command entry become live. Follow-ups inherit the
  launch's committed selection, which is what the session would apply anyway.
- **The create timeout rises to 180 s.** Cold budgets exceed 30 s. With the
  message visible and the composer usable, a longer honest wait is better than
  a false uncertain failure. Both create paths keep calling
  `RelayHttpApiClient.post` and simply pass its existing `timeout` argument
  (`relay_http_client.dart:47`); `post` already reports non-sensitive responses
  (`:56`), so failure logs keep the diagnostic body and **no client signature
  changes**. `postWithTimeout` and its attachment caller are untouched.
- **Analytics move with the operation, unchanged in shape.**
  `sessionCreatedWithMessage` and `sessionCreationFailed` stay exactly as they
  are, but they are reported by `SessionLaunchService` rather than
  `NewSessionCubit`, because the service is now the owner that always observes
  the authoritative outcome. This is a strict improvement: today both events
  are **lost** whenever the user leaves the new-session route before the bridge
  answers, since the cubit returns early once closed. No event, parameter or
  name changes. The same applies to the two feedback-prompt records that sit
  beside those events today: `NewSessionCubit` calls
  `_feedbackPromptService.recordPositiveInteraction()` on success and
  `recordFailure()` on failure (`new_session_cubit.dart:972-976`), and both move
  into the service with the outcome, so creations keep counting towards
  feedback-prompt eligibility exactly as they do now.

  **The service also reports the follow-ups it sends.** An earlier draft said
  queued follow-ups "are reported by the existing session path"; that was wrong.
  `sessionMessageSent` is reported by
  `SessionDetailCubit._reportAcceptedSubmission` (`session_detail_cubit.dart:2509-2519`)
  and the positive interaction by `_feedbackPromptService.recordPositiveInteraction()`
  (`:2210`), both only after **that cubit's own** repository send. A follow-up the
  service sends never passes through either. So `SessionLaunchService` reports
  `sessionMessageSent` itself on each accepted follow-up, with the same event and
  the same `AnalyticsSubmission` mapping, and records the same positive
  interaction through `FeedbackPromptService`
  (`module_core/lib/src/services/feedback_prompt_service.dart`), and on a real
  follow-up send failure it calls `recordFailure()`, as the detail cubit does at
  `:2238-2240`. Still no event,
  parameter or name changes — only the reporter moves, which is the same move the
  create events make. That makes `FeedbackPromptService` a third collaborator;
  the alternative, instrumenting a UI proxy in the composer, is what the
  analytics rules forbid. No new event is needed for "a follow-up was typed
  during creation"; revisit only if the product asks for that specifically.

## The Launch Owner

Introduced in step 3 and extended by steps 4, 5 and 6. One file family in
`module_core`, following the `ComposerDraftStorage`/`ComposerDraftRepository`
template for the storage and repository, and the
`RecentSessionInventoryService`/`RecentSessionsCubit` template for the service
and its adapter.

- **`SessionLaunch` (Layer 0 model, `foundation/models/session_launch/`) is
  sealed, not one class with a nullable id.** Every variant carries
  `launchId`, `projectId`, `pluginId`, `startedAt` and `followUpIds`:
  - `PendingSessionLaunch({…, title, submission, followUps})` — the bridge has not
    answered. **Only this variant produces a placeholder row.** `String? title`
    is the first line of `submission.displayText` (**D2**; null for an
    attachment-only start), snapshotted at `start` so the row keeps it after
    `releaseHandoff` drops `submission` (then null).
  - `CreatedSessionLaunch({…, session, submission, unsentComposer, followUps})` —
    the bridge answered with a real `Session`. **Only this variant can hand over**,
    through `takeHandoff`. `unsentComposer` is null until the composing cubit
    hands over what the user had typed but not sent (step 4); null also means
    there was nothing.
  - `ReconcilingSessionLaunch({…, session, followUps})` — the handoff has been
    taken by the session screen or released by the composing route, and the
    entry is retained only while a follow-up is still owed (the lists latched
    its `launchId`↔`session.id` association at `promote`, step 5). It has no submission field at all, so "a launch
    whose payload was already consumed but still looks unconsumed" is not
    representable.

  `followUps` is a `List<LaunchFollowUp>`, not a list of bare submissions,
  because a follow-up has a delivery state the session screen must render and a
  `QueuedSessionSubmission` is only the authored payload. `LaunchFollowUp`
  (`foundation/models/session_launch/`) is sealed exactly like the detail
  queue's existing `LocalSendPhase` (`cubits/session_detail/local_send_phase.dart`),
  each variant wrapping the submission:
  - `QueuedLaunchFollowUp` — not sent yet; rendered `pending(onCancel:)`;
  - `SendingLaunchFollowUp` — the one the service is sending now; rendered
    `sending`, with no cancel, because the request is already in flight;
  - `AcceptedLaunchFollowUp` — the bridge accepted it; held only for the
    handoff (see "The launch's lifetime");
  - `FailedLaunchFollowUp({submission, required PromptSendFailure failure})` —
    the only variant with failure data; rendered as the existing failed bubble
    with Retry and remove.

  `PromptSendFailure` is today a pure enum in `repositories/models/`, so step 2
  moves it to `foundation/models/composer/` with the two composer models, for
  the same Layer 0 reason.

  `launchId` is client-generated and is the stable row key. A flattened
  `String? sessionId` would make "a created launch still drawing a placeholder
  row next to its own real session row" a representable state, prevented only by
  some consumer happening to run in time. Sealing it makes the placeholder
  provably disappear the instant a session exists, and the third variant is what
  lets the payload be consumed while follow-ups are still owed (see "The
  launch's lifetime").

  Two fields are on every variant on purpose, because they are the only launch
  facts that must survive the payload:
  - `startedAt` — the instant Send committed, so the sending bubble's slow-send
    state can be reconstructed rather than restarted on each of the two widget
    replacements the handoff performs (step 3).
  - `followUpIds` — **every** promptId this launch has ever minted, accepted or
    not, which is what the positional release predicate excludes. `followUps`
    shrinks as follow-ups are accepted and handed over; `followUpIds` does not, because a
    bridge-queued statement for an already-accepted follow-up arrives *after*
    acceptance and would otherwise be read as the first message's replacement
    (step 4).

- `SessionLaunchStorage` (Layer 1, `api/storage/`, `@lazySingleton`): the
  process-local map `Map<String, SessionLaunch>` keyed by `launchId`, mirroring
  `ComposerDraftStorage`'s shape exactly. It is the **sole writer** of the map.
  No persistence, no timers.
- `SessionLaunchRepository` (Layer 2, `@lazySingleton`): the **sole publisher**.
  `start`, `addFollowUp`, `cancelFollowUp`,
  `promote({required String launchId, required Session session})` (pending →
  created, or pending → reconciling when the payload was already released),
  `handOverComposer({required String launchId, required UnsentComposer content})`
  (step 4),
  `takeHandoff({required String sessionId})` which returns the handoff once — the
  first-message payload, the accepted follow-ups and the unsent composer — and
  moves created → reconciling,
  `releaseHandoff({required String launchId})` which discards the handoff on
  whichever variant holds it, `followUpSending`, `followUpAccepted` and
  `followUpFailed({launchId, promptId, failure})`, and
  `fail({required String launchId, required RemoteFailureReason reason})`.
  Follow-ups live here and nowhere else. There is no `complete`: removal is the
  repository's own consequence of nothing being owed, per "The launch's lifetime".

  It publishes four things, deliberately separate because they have different
  lifetimes and different readers:
  - a broadcast stream of current `PendingSessionLaunch`es — the placeholder
    rows;
  - a broadcast stream of `launchId`→`session` associations covering the created
    **and** reconciling variants — the list row keys, which a list latches from
    the emission `promote` produces (step 5), so the entry need not outlive the
    handoff for them;
  - a broadcast stream of typed terminal outcomes, sealed as **three** variants
    rather than two, so exactly one reader acts on each:
    - `SessionLaunchSucceeded({launchId, session})` — read by the composing cubit
      for its `created` state;
    - `SessionLaunchFailedWhileComposing({launchId, reason, followUps})` (the
      follow-ups as their submissions; nothing was sent, so all are queued) —
      published when the launch's payload had **not** been released, which is
      precisely the case where a composing route is still attached. It carries the
      follow-ups because `fail` removes their only owner in the same act and
      **D1** requires them in the restored draft; the first submission itself is
      already on `NewSessionPhaseSending.submission`, exactly as
      `NewSessionPhaseRestoringSubmission` consumes it today
      (`new_session_state.dart:122-127`);
    - `SessionLaunchFailedAfterLeaving({launchId, projectId, reason})` —
      published when the payload had been released, so no composer can restore
      anything. This is the **only** variant the shell-level **D5** listener acts
      on, and it carries the `projectId` that alert names.

    Splitting the failure is what removes the need for a claim or handled flag
    between the two listeners: the owner already knows whether a composer is
    attached, because detaching *is* releasing the payload, and it therefore
    decides the single destination at publication rather than asking two
    independent listeners to infer which of them should act.
  - a per-launch view, `watch({required String launchId})`, read by the composing
    cubit for the launch's follow-ups (step 4), and a per-session view,
    `watchForSession(sessionId)`, read by the session screen, so the detail cubit
    renders follow-ups that are still being delivered instead of taking a one-shot
    snapshot of them.
- `SessionLaunchService` (Layer 3, `services/`, `@lazySingleton`): owns the
  **operation**, which is the reason this family exists at all. `launch(...)`
  starts the launch in the repository, awaits
  `SessionRepository.createSessionWithMessage`, then `promote`s on success or
  `fail`s with the reason on failure, and reports
  `sessionCreatedWithMessage` / `sessionCreationFailed`, with the feedback-prompt
  record that accompanies each today. On failure it also keeps
  today's `loge("New session creation failed", error)` with the original
  `ApiError` and the operation context, because the published outcome carries
  only a `RemoteFailureReason` and would otherwise discard the response detail
  and stack.

  It also owns **delivery of the follow-ups**: after `promote` it sends each
  retained follow-up in order, awaiting one before starting the next, through the
  same `SessionRepository` prompt send the session screen uses, reusing the
  promptId the follow-up was born with so the bridge dedups a resend. Each
  follow-up moves queued → sending → accepted or failed; what happens to an
  accepted or failed one afterwards is the lifetime rule's, not the service's
  (its promptId stays in `followUpIds` forever either way).

  **A failed send keeps its diagnostic log.** The detail cubit logs every
  follow-up it fails to send today —
  `logw("Failed to send queued session submission", error)` for an
  `ErrorResponse` and the same with the stack trace for a thrown error
  (`session_detail_cubit.dart:2231-2241`). The service path bypasses that cubit,
  and `FailedLaunchFollowUp` carries only the presentation-safe
  `PromptSendFailure`, so the service logs both cases itself with the original
  `ApiError` or thrown error, the stack trace where there is one, and the
  `launchId`, `promptId` and session id as context — never the prompt text.
  Delivery lives here, and not in `SessionDetailCubit`,
  for the same reason the operation does: a user who leaves before creation
  finishes must not have their queued messages stranded until they happen to
  reopen that session. Nothing calls `complete`; removal follows from the
  lifetime rule above.

  Because the service owns the only sender, it also owns **retry**:
  `retryFollowUp({required String launchId, required String promptId})` turns a
  `FailedLaunchFollowUp` back into a queued one at the head of the launch's
  unsent follow-ups and re-enters the same serial delivery loop. A Retry that only wrote to the
  repository would change the item's state with no send ever happening, because
  the post-promotion drain has already finished by then. `cancelFollowUp` stays on
  the repository, because cancelling is only a removal.

  Because the service is a singleton, all of that runs whether or not the
  composing route still exists. It has three collaborators (`SessionRepository`,
  `SessionLaunchRepository`, `FeedbackPromptService`) plus analytics, so it is a
  real service and not a pass-through.
- `SessionLaunchCubit` (Layer 4, `module_core/lib/src/cubits/session_launch/`):
  the thin adapter the list widgets watch, exactly as `RecentSessionsCubit`
  adapts `RecentSessionInventoryService`. Provided above the router on phone
  (`app/lib/main.dart:392-398`, beside `PendingSessionArchiveCubit`) and inside
  `DesktopCockpitCubitProvider` on desktop
  (`desktop_cockpit_shell.dart:32-52`), and re-provided by value in the sidebar
  rail popout's `MultiBlocProvider` (`desktop_sidebar.dart:472-477`), which
  renders on the root navigator.

`NewSessionCubit` therefore stops owning the create response. It calls
`SessionLaunchService.launch(...)` and **adds** the `launchId` to its sending
phase, which keeps the `submission` field it already has today
(`new_session_state.dart:122`) — that field is how the sending bubble is rendered
in step 2 and how `restoringSubmission` is fed today, and removing it would leave
the composing view with no source for the one thing it must keep on screen. The
launch holds its own copy for the handoff; two immutable copies of one submitted
value, with distinct readers and distinct lifetimes, is not the shared-mutable
state the single-owner rule is about. The **follow-up list** is still not
duplicated: the cubit reads it from `watch(launchId:)` (step 4).

It watches the **outcome stream** for its own `launchId`:
`SessionLaunchSucceeded` becomes `NewSessionState.created(session:)` and also
clears the captured selection revision through the existing
`NewSessionSelectionTracker.clearIfRevision` (`new_session_cubit.dart:909-963`),
which must not be lost in the move — otherwise a deliberately chosen agent,
model, variant or fast-mode value would be reapplied the next time this
project's composer opens. `SessionLaunchFailedWhileComposing` becomes the existing
`restoringSubmission` phase, using the phase's own `submission` plus the outcome's
`followUps` and the composer's unsent content (**D1**, step 4). Before emitting `created`, it hands the composer's unsent
content to the launch with `handOverComposer` (step 4), so the handoff the
session screen takes is complete by the time the route is replaced.
`SessionLaunchFailedAfterLeaving` is never seen by a cubit,
by construction. The tracker stays in the cubit rather than becoming a service
collaborator, because a selection belongs to the composer that made it; when the
route is already gone the revision is not cleared, exactly as today.

In `close()`, a cubit that has **not** reported a successful outcome to its view
calls `releaseHandoff` — that is, while the launch is still pending, or after a
failure. It must not release after success, because the payload then belongs to
the detail route that is replacing it, and the two dispositions are not ordered
against each other. Releasing while pending is the commonest case (the user
pressed Back mid-create), which is why the lifetime rule defines release on the
pending variant too: the payload and its attachment bytes go immediately, and the
launch that eventually arrives is already reconciling. Its existing
`if (isClosed) return;` early exit becomes harmless, because nothing important
happens after it any more.

Launches are keyed, not a single slot. A single slot was enough while the
handoff was invisible, but a visible placeholder row makes overwriting wrong:
starting a second session (trivially easy on desktop, where the home composer
and a project composer both exist) would silently erase the first row. That is
also what **D6** settles: concurrent launches are supported, each with its own
row. The map is bounded by the number of creations actually in flight plus
those with a failed follow-up the user has not acted on yet, and because the
service always reaches `promote` or `fail` and every other debt is then
discharged, every entry is removed once the user has retried or removed its
failed follow-ups — which is what makes that bound real rather than
aspirational. Attachment bytes are bounded twice over: a failed launch's
payload goes with the entry, and an unclaimed successful launch's payload goes
when the composing route closes without handing it over — or earlier, when the
route closes before the response arrives at all.

**Invariant, enforced by construction rather than left as a decision:** a
placeholder row and its real session row never coexist, because at most one row
is drawn per `launchId` and it is the placeholder only until the drawing surface
would draw the associated session in the placeholder's slot (see "The launch's
lifetime" and steps 5 and 6). The association stream produces **no rows of its own**; it
only tells a list which key one row should keep across that content change.

**One source of truth for the harness name.** The launch stores `pluginId` only.
Both presentation seams that need a display name derive it the same way, through
`PregoBrandLogo.displayNameFor(pluginId)`: the sending bubble and the
placeholder row's meta line. The launch does not also store a display string.

### The launch's lifetime, stated once

Four separate review findings turned out to be this one seam — when an entry is
removed, when its payload dies, who may release it, and how long its row is owed —
so the rule lives here and every step refers back to it instead of restating it.
An entry exists from `start` until **nothing is owed**, and each of the three
things a launch can owe is discharged independently:

1. **A session.** Owed while `PendingSessionLaunch`. Discharged by `promote`, or
   the whole entry goes with `fail`.
2. **The handoff.** Everything the session screen continues from the composing
   surface: the first-message `submission`, the unsent composer content once the
   composing cubit has handed it over (step 4), and every follow-up accepted
   before the handoff was taken. Owed while a `submission` is present.
   Discharged by `takeHandoff` (the session screen took it) or by
   `releaseHandoff` (the composing route will not).

   **An accepted follow-up belongs to the handoff, whoever is on screen when it is
   accepted.** Its bubble must not blank between acceptance and the bridge's
   queue statement, delivered message or authoritative refresh, and the only
   thing that can wait for those is a session screen's existing parked slot
   (`PromptSendQueue.parkAccepted`). So while the handoff is owed, an accepted
   follow-up stays on the launch as `AcceptedLaunchFollowUp` and `takeHandoff`
   hands it over with the first message, to be parked by the taker
   (`adoptAccepted`, step 4) before its first load. Once the handoff has been
   taken, the taker is already watching the launch, so a later acceptance goes
   straight to whichever session screen is watching and leaves the launch. Once
   it has been released, no screen can ever take this launch over: a screen
   opened later starts from an authoritative load and never drew the bubble, so
   the accepted follow-up leaves the launch at acceptance. In all three cases
   the follow-up is held until something accounts for it or nothing ever drew
   it — never dropped while a bubble for it is, or is about to be, on screen.
   `releaseHandoff({required String launchId})` is defined on **any** variant, not
   only on created: a user who leaves while the launch is still pending must be
   able to detach, and that is the commonest way this path is reached. On a
   pending launch it drops the submission immediately (the placeholder keeps its
   `title` snapshot), and the later `promote`
   then produces a `ReconcilingSessionLaunch` directly rather than a
   `CreatedSessionLaunch` whose payload nobody could ever take and whose
   attachment bytes nothing would free. Release is also what makes the failure
   outcome's two variants decidable: payload still present means a composer is
   attached, payload released means one is not.
3. **Follow-up delivery.** Owed while any follow-up is queued, sending or failed.
   A queued or sending one is discharged by acceptance (it then follows the
   handoff rule above) or by cancel. A failed one is owed until the user retries
   or removes it, because its failure is something the user must see: any session
   screen opened for that session renders it from `watchForSession`, whether or
   not a screen existed when it failed. `followUpIds` is not a debt; it is
   retained for the whole entry because the release predicate needs it (step 3).

**Removal is a consequence, not a call.** The repository re-evaluates "is
anything owed?" after every transition it performs — `promote`, `takeHandoff`,
`releaseHandoff`, `followUpAccepted`, `cancelFollowUp` — and removes the entry
the moment the answer is no. There is deliberately no `complete(launchId:)` for a
caller to remember: on the ordinary happy path with no follow-ups, the last debt
is discharged inside `takeHandoff`, which runs on the detail route long after
`SessionLaunchService` finished its own work, so no service call site could have
been the right place to ask. Removal never takes the association from a list
that needs it: `promote` publishes it before any removal, and a list drawing the
placeholder latches it from that emission (step 5).

**The row is owed until the surface drawing it would draw the real row in its
place.** The one thing the owner deliberately does not decide is when a
placeholder row stops being drawn, because that answer differs per surface: each
surface learns about the new session through its own independently delivered
events, which can arrive after the create response that triggered `promote`.
Dropping the row at `promote` would leave an emission with neither the
placeholder nor the real row — a row blinking out and back, which is exactly the
jump feel property 3 forbids, and it would also leave the row-key latch nothing
to latch onto.

"In its place" matters as much as "has the session". `session.created` usually
reaches a client before the first activity statement for that session: the
client's `SseEventTracker` takes activity only from project summaries, and
`SessionUnseenTracker` applies only `SesoriSessionUpdated`. In that window the
session is in the surface's data but not yet running, so a session list sorts it
below any running session and `SessionActivityProjection` classifies it as
Recent. Releasing the placeholder then would send the row somewhere else and
bring it back when the activity statement lands.

So a surface that drew a placeholder keeps drawing it until it would draw the
real session in the placeholder's slot — at the head of Today in a session list
(step 5), in its Activity position on an Activity host (step 6) — and then draws
the real row there, under the `launchId` key where the surface has row identity.
While it holds the placeholder, it leaves the associated session out of every
other position it would otherwise draw it in, so one surface never shows two rows
for one launch. The hold has one bound: if the surface's next update after the
one that first brought the session in still does not place it in the
placeholder's slot, the session has settled elsewhere without running on this
client (a first command that starts no turn is the known case), and the row goes
where the session now belongs as an ordinary state change. Steps 5 and 6 own
that mechanism and name the widgets it lives in.

## Design

### Step 2: Session-shaped creating view (module_app_ui, plus the create timeout in module_core)

Lands the instant screen on its own, before the queue and the placeholder row,
because it is independently valuable and independently verifiable: it removes
the first spinner with no new state at all.

- A new shared widget, `SessionLaunchSubmissionView`
  (`module_app_ui/lib/src/features/session_detail/widgets/session_launch_submission_view.dart`),
  takes `required NewSessionSubmissionSnapshot submission` and
  `required String? harnessName`. It renders the session-shaped transcript
  area: the submission as a bottom-anchored `QueuedMessageBubble` with
  `presentation: sending(harnessName: …)`. The text comes from the snapshot's
  new `displayText` getter and the local attachments from its text variant.
  The step 3 detail loading branch reuses this widget unchanged.
- The `NewSessionView` sending branch replaces the full-screen
  `PregoLaunchStatus` with `SessionLaunchSubmissionView` on both the glass
  scaffold (phone, `:492-497`) and the chrome page (desktop, `:274`). It is
  fed by the existing `NewSessionPhaseSending.submission` and the selected
  plugin's display name. The top bar already reads "New session" with
  `titleMode: inline`; that stays. The composer stays unmounted in this step,
  as today, so the existing failure-restoration path is untouched.
- `NewSessionSubmissionSnapshot` gains `String? get displayText`: `/cmd args`
  for a command, the text for a prompt, or null when there are only
  attachments. This mirrors `QueuedSessionSubmission.displayText`.
- **Two composer models and one send-failure enum move down a layer, in this PR,
  for the same reason.** All three are held by a Layer 0 `SessionLaunch` from
  step 3 or 4 onwards, so a Layer 0
  model would otherwise import from `cubits/` — a Foundation → Layer 4
  dependency, whatever the file's own contents.
  - `new_session_submission_snapshot.dart` (and its freezed part) moves from
    `cubits/new_session/` to `foundation/models/composer/`.
  - `queued_session_submission.dart` moves from `cubits/session_detail/` to
    `foundation/models/composer/`, where its own imports
    (`composer_attachment.dart`, `composer_draft.dart`) already point. The file
    is a pure sealed value with no cubit dependency, so the move is a path change
    plus its importers, not a redesign; `SessionLaunch.followUps` is the reason it
    can no longer live under `cubits/`.
  - `prompt_send_failure.dart` (`PromptSendFailure`, a pure two-value enum with
    no imports) moves from `repositories/models/` to
    `foundation/models/composer/`, because `FailedLaunchFollowUp` carries it (a
    Foundation → Layer 2 dependency otherwise). It stays exported from the
    barrel.

  All three happen here, in the low-risk PR, rather than inside step 3, so step 3's
  diff is behaviour only. `PromptSendQueue` stays where it is: it is genuinely
  cubit-scoped machinery, not a model.
- Relay create timeout: both create paths in `SessionApi` pass
  `timeout: Duration(seconds: 180)` to the `post` call they already make. No
  client method gains or loses a parameter.
- Cleanup: the sending-branch `PregoLaunchStatus` usage and its widget-test
  expectations go. `newSessionLoadingMessage1..3` stay, because the ordinary
  session-detail load still uses them.
- Tests: the first sending frame shows the bubble with the text, command, and
  attachments. Failure restores the composer exactly as today. The chrome
  (desktop) and glass (phone) variants are covered. The timeout applies on the
  plain and attachment create paths.
- **Regression documents, in this PR:**
  `docs/regression/session-creation-and-options.md` — Send now shows the
  submitted message as a sending bubble instead of detail-shaped launch status,
  at the same unresolved route, with the composer still replaced and duplicate
  Send still blocked, and creation now waits up to 180 s before reporting an
  uncertain failure.
- **Feel check:** the bubble is bottom-anchored in the same place the session
  screen puts it, so step 3's replacement moves nothing.

### Step 3: First-message handoff to the session screen (module_core, module_app_ui, app, desktop)

- Introduce the whole launch owner family — sealed `SessionLaunch`,
  `SessionLaunchStorage`, `SessionLaunchRepository` and `SessionLaunchService` —
  as described in "The Launch Owner", including the lifetime rule stated there:
  release is defined on the pending variant, and removal is the repository's own
  consequence of nothing being owed rather than a `complete` call. This step
  defines the streams it has readers for: the three-variant outcome stream (read
  by `NewSessionCubit`, and by step 5's shell listener for its third variant) and
  `watchForSession` (read by `SessionDetailCubit`). `watch(launchId:)` arrives in
  step 4, and the placeholder-row stream, the association stream and
  `SessionLaunchCubit` in step 5, each with its first reader.
- `NewSessionCubit` gains a constructor dependency on `SessionLaunchService`,
  wired in `cubit_composition.dart:92-104`. `createSession` stops awaiting the
  repository itself: it mints a `launchId`, calls
  `SessionLaunchService.launch(...)`, and emits
  `NewSessionPhase.sending(submission: …, launchId: …)` — the sending phase
  **keeps** the `submission` it carries today (`new_session_state.dart:122`) and
  gains the `launchId` beside it. It then watches the owner's **typed
  outcome stream** for that `launchId`: `SessionLaunchSucceeded` becomes
  `NewSessionState.created(session: …)` and clears the captured selection
  revision, `SessionLaunchFailedWhileComposing` becomes the existing
  `restoringSubmission` phase with the carried reason and the phase's own
  submission (see "The Launch Owner"). Failure restoration,
  `_restoreStagedCommand` and
  `acknowledgeRestoredSubmission` are otherwise unchanged.
  `NewSessionState.created` is **not** given a `submission` field: the created
  listener's only job is still `onSessionCreated(session:)`, and the handoff
  payload now travels through the launch owner, so a second carrier would have
  no reader.
- The created listener in `NewSessionView` (`:447-461`) keeps its existing
  "route still current" guard and then calls `onSessionCreated`. A skipped
  navigation no longer strands anything: the service has already promoted the
  launch, and the detail route consumes it whenever the session is opened.
- `SessionDetailCubit` gains a constructor dependency on
  `SessionLaunchRepository`, wired in `createSessionDetailCubit`
  (`cubit_composition.dart:41-70`), and calls
  `takeHandoff(sessionId: …)` before its initial state. In this step the handoff
  is the first message only; step 4 adds the accepted follow-ups and the unsent
  composer to the same value. Taking it moves
  the launch to its reconciling variant while any follow-up is still owed
  (step 4), and otherwise removes it (the lists latched the association at
  `promote`, step 5):
  - `SessionDetailState.loading` gains
    `required NewSessionSubmissionSnapshot? launchSubmission` and
    `required String? launchPluginId`, and every loading emission of
    `_loadMessages` carries them through. Step 4 adds the follow-ups beside
    them, so the loading state is the one place that describes a taken launch.
  - `SessionDetailLoaded` gains the same fields. `SessionDetailFailed` and
    `SessionDetailHarnessUnavailable` do not. A failed first load loses the
    bubble and Retry loads normally; the harness-unavailable state
    (`session_detail_cubit.dart:419-429`, which additionally requires
    `!_interaction.canInteract`, so it needs the harness to become blocked
    between a successful create and the first load) shows its own explanation of
    why the transcript is empty. Both are accepted low-damage losses of a
    client-side bubble, not of the message, which the bridge already accepted.
    Carrying the launch through two more states to cover them would add state to
    the path that always runs for a path that almost never does.
  - **The release rule has exactly one owner.** A pure predicate beside
    `hasRenderableUserContent` in `session_detail_resolvers.dart` answers
    "does this state now show the launch's replacement?" — true when a user
    message with `hasRenderableUserContent` is present, or `bridgeQueuedPrompts`
    contains a prompt whose id is **not** in the launch's `followUpIds`. The
    exclusion matters: a follow-up can be delivered and appear in that list while
    the first message still has no echo, and treating it as the replacement would
    make the first bubble disappear and come back.
    It is `followUpIds` — every promptId the launch ever minted — and not the
    current `followUps`, because the bridge's queued statement for a follow-up
    arrives **after** the HTTP acceptance that took it off `followUps`. Excluding
    only undelivered follow-ups would therefore let the most likely event of all —
    the queue statement for the follow-up that just succeeded — read as the first
    message's replacement.
    A first message that is a command producing no transcript entry at all (a
    Pi notification-only command is the known case) therefore never reaches a
    replacement, and its bubble stays "Sending" until the session screen is
    reopened, when there is no launch left to seed it. That is an accepted limit
    rather than a reason to add echo correlation or a bubble timeout: it needs a
    no-echo command as the very first message, the session itself is correct, and
    it self-corrects on reopen.
    A single private `_emitLoaded(SessionDetailLoaded)` funnel
    applies it to **every** loaded emission and is the only way the cubit emits
    a loaded state. This matters because the cubit emits loaded state through
    `copyWith` at over fifty sites, all of which would otherwise preserve
    `launchSubmission` by default; enforcing the rule at four named call sites
    would make the plan's central correctness claim depend on four
    hand-maintained places. A local stop or abort also clears it, through the
    same funnel.
- Presentation:
  - When `launchSubmission` is set, the `SessionDetailBody` loading branch
    renders `SessionLaunchSubmissionView` with the harness name derived from
    `launchPluginId`. The plugin **is** known — it came from the launch — so
    passing null here would make the bubble read "Sending to `<harness>`…"
    before the route replacement and revert to "Sending" after it, which is
    exactly the one frame feel property 2 forbids.
  - **The slow-send state has to travel too, and the harness name alone does not
    carry it.** `_QueuedMessageBubbleState` owns a private `_slowSendTimer`
    started from `initState` (`queued_message_bubble.dart:59-86`), and
    `didUpdateWidget` re-syncs it only when the presentation's *sending-ness*
    changes (`:69-73`). The handoff constructs that `State` twice more — once in
    the detail loading branch, once again in `SessionDetailMessageList` when the
    load completes — so on any create longer than 2 s the copy already reading
    "Sending to `<harness>`…" would revert to "Sending" and count to 2 s again,
    twice. That is the same reverting text feel property 2 forbids, arrived at from
    the other direction.

    Fix: `QueuedMessageBubble` gains `DateTime? sendingSince` on its **sending**
    presentation, and `_syncSlowSendTimer` schedules
    `_slowSendDelay - elapsed`, firing immediately when that is already past.
    `null` keeps today's behaviour exactly, so every existing caller is unchanged.
    The launch's `startedAt` is the value. It is carried on
    `SessionDetailState.loading`/`Loaded` beside `launchPluginId`, and on
    `NewSessionPhaseSending`, which gains `startedAt` beside `launchId` — the same
    instant the cubit hands to `launch(...)`. `SessionLaunchSubmissionView`
    therefore takes `required DateTime? sendingSince` beside its harness name and
    passes it through. All three renderings of the same bubble then derive one
    deadline from one instant. No timer state and no elapsed counter is stored
    anywhere; one `DateTime` is.
  - `SessionDetailMessageList` renders it as the oldest transient row, under
    one constant row id, as a `QueuedMessageBubble` with the `sending`
    presentation. It needs no promptId: a session has at most one launch
    submission, so it is never matched against echoes.
  - The empty-state check in `session_detail_loaded_view.dart` treats it as
    content.
- Transition, decided at each `onSessionCreated` call site with no repository
  read in routing:
  - **Phone** (`client/app/lib/features/new_session/new_session_screen.dart:49`):
    today, `replaceRoute` animates the platform push, or a fade in split view,
    through `buildSessionPaneTransitionPage` (`app_router.dart:142`). The
    session-detail route type gains an optional flag that serialises as a
    **query parameter** (`?fromLaunch=1`), the call site sets it when it replaces
    the new-session route, and `buildSessionPaneTransitionPage` uses
    `Duration.zero` when it is present. `state.extra` is **not** used:
    `client/app/AGENTS.md:93` requires path/query route state and forbids it, and
    a query parameter needs no new shell-local mutable state to carry a one-shot
    marker. The flag is inert on every other route entry, so a deep link or a
    restored route transitions exactly as today.
  - **Desktop** (`desktop_router.dart:176` new-session route,
    `desktop_session_list_screen.dart:198` → `desktop_router.dart:132`
    project-page composer, `desktop_home_pane.dart:242` → `desktop_router.dart`
    `onOpenSession` home composer): all three go through the main-pane
    `_PageFade` (150 ms cross-fade, zero under reduced motion) and stay
    unchanged. The two sides are not identical content, so the reason is the one
    given under Design Decisions: the bubble holds its rect across the fade while
    only the toolbar changes, and step 4 hides the embedded panes' own chrome
    while sending so there is less left to change. The final step verifies this on
    all three desktop surfaces, and an observed second-navigation feel is what
    would switch them to the same instant replacement the phone uses.
- Tests:
  - `takeHandoff` matches and returns once, returns nothing for a different
    session id or a still-pending launch, and leaves the association behind.
  - A launch started and then abandoned (the cubit closed before the response)
    still reaches `promote` or `fail`, still reports its analytics outcome, and
    leaves no entry behind once its payload is released and its follow-ups are
    delivered.
  - The outcome stream carries the created `Session` on success and the
    `RemoteFailureReason` on failure, a successful outcome clears the captured
    selection revision, and a failed create still logs the original error.
  - A failure publishes `SessionLaunchFailedWhileComposing` while the payload is
    unreleased and `SessionLaunchFailedAfterLeaving` once it has been released,
    never both.
  - `releaseHandoff` on a **pending** launch drops the payload, and the later
    `promote` yields a reconciling launch with no submission, which leaves no
    entry behind.
  - The entry is removed with no `complete` call: a success with no follow-ups
    disappears at `takeHandoff`.
  - Loading carries the bubble, the plugin id and `startedAt`, and the load
    path's emissions preserve them.
  - A bubble rendered with `sendingSince` more than 2 s ago reads
    "Sending to `<harness>`…" on its **first** frame, in the loading branch and
    again in the loaded message list, so the handoff never restarts the slow-send
    copy.
  - Release on a snapshot, message, part, or queued prompt, each in one
    emission, exercised through `_emitLoaded` so a new emission site cannot
    bypass it.
  - No "No messages yet" while the bubble is pending.
  - Ordinary opens are unchanged (no launch for that session id).
  - Widget continuity across the replacement, including the harness name.
- **Regression documents, in this PR:**
  `docs/regression/session-creation-and-options.md` — the created session now
  takes over with no second launch status and no "No messages yet" gap, and the
  bubble stays until the harness's own transcript shows the message;
  `docs/regression/session-turns.md` — the launch bubble's place in the
  transient-row ordering and its positional release;
  `docs/regression/navigation-transitions.md` — confirm the phone replacement is
  transition-free, which its existing rule already requires.
- **Feel check:** the bubble must occupy the same offset before and after the
  route replacement. The test asserts the rendered bubble's global rect is
  unchanged across the swap, which is the only mechanical way to prove
  property 2.

### Step 4: The composer stays live and follow-ups queue (Q3) (module_core, module_app_ui)

- **`NewSessionCubit` gate split.** `canCreateSession` keeps meaning "a
  launch may start" and stays false while sending. A new
  `bool get canSubmitFollowUp` is true only while
  `phase is NewSessionPhaseSending`. `_canEditComposer` becomes true while
  sending so text, attachments and command entry work. The option gates
  (`canRefreshOptions`, `needsHarnessDiscovery`, `_canApplyLoad`) stay false
  while sending, because the request in flight already committed those values.
  `_emitDiscoverySuccess` (`:185-190`) and `_emitDiscoveryError` (`:225-230`)
  currently **drop the whole config update** while sending; they keep dropping
  it, which is now a deliberate statement rather than a side effect of
  inertness, and is commented as such.
- **Follow-ups have exactly one owner: the launch.** They are **not** mirrored
  into cubit state. `NewSessionPhaseSending` carries the first `submission`, the
  `launchId` and `startedAt` (step 3) and no follow-up list; `NewSessionCubit`
  subscribes to `SessionLaunchRepository.watch(launchId:)` — added in this step,
  with this as its first reader — and exposes the follow-ups it reads from there.
  `queueFollowUp({required ComposerDraft draft, required String? command, required List<ComposerAttachment> attachments})`
  builds a `QueuedSessionSubmission` with a fresh promptId and the launch's
  committed `agent`/`agentModel`/`fastMode`, and writes it through
  `SessionLaunchRepository.addFollowUp` only. It refuses
  command-plus-attachments exactly as `createSession` does (`:885-888`).
  `cancelFollowUp({required String promptId})` goes to
  `SessionLaunchRepository.cancelFollowUp`. Keeping a second copy in the
  sending phase would give one list two writers, which is the shape this
  plan's own single-owner decision exists to avoid.
- **Shared promptId generation.** `SessionDetailCubit._generatePromptId()`
  (`:2501-2510`) and its companion `static final Random _promptIdRandom`
  (`:2501`) move together into a new file
  `client/module_core/lib/src/foundation/identity/prompt_id.dart` (a new
  `identity/` subdirectory beside the existing `io/`, `models/`,
  `persistence/` and `platform/`), exposing a top-level `generatePromptId()`
  with the random source private to that file. Both cubits then mint the same
  `prm_` shape from one implementation, and the cubit's private copies are
  deleted.
- **View.** Neither sending branch disposes `PromptInput`, so it keeps its
  staged attachments, its text and its focus:
  - Glass/phone (`:492-544`): the sending branch becomes the same
    `Column[Expanded(pane), composer]` as the idle branch, with the pane being
    `SessionLaunchSubmissionView` instead of the options scroll.
  - Chrome/desktop (`:274-295`): the sending branch becomes
    `Column[Expanded(SessionLaunchSubmissionView), composer]`, and the page
    chrome's `topBar` and `footer` are hidden while sending, so an embedded
    composer's pane (the home pane's `DesktopFileAccessCard` and home sections, a
    project page's catalog header) becomes session-shaped instead of a home page
    with a bubble in it. The composer therefore moves from the centred column to
    the bottom edge at Send. That changes its ancestors (today it sits under
    `Expanded → Center → SingleChildScrollView → … → Column`, `:274-295`), so the
    view gives the composer one `GlobalKey` held in its state, and Flutter
    reparents the same `PromptInput` state into the new slot (and back on a
    failure restore) instead of disposing it. **D8**, settled: that move is animated **once**, at
    240 ms, and is instant under reduced motion — the transition that explains
    "this is now a session".
  - `canSend` changes from `cubit.canCreateSession && !isSending` (`:416`) to
    `cubit.canCreateSession || cubit.canSubmitFollowUp`, and `onSend` routes
    to `createSession` or `queueFollowUp` on the same condition.
  - `SessionLaunchSubmissionView` gains
    `required List<LaunchFollowUp> followUps` and renders each below
    the first bubble as `QueuedMessageBubble` with the presentation its variant
    names (queued → `pending(onCancel: …)`, sending → `sending`, failed → the
    failed bubble), in order, reusing
    `_kPromptRowPrefix`-style keys so they keep identity into the session
    screen.
- **Delivery does not wait for a route.** `SessionLaunchService` sends the
  follow-ups as soon as the launch is promoted, in order, awaiting one before
  starting the next (see "The Launch Owner"). Draining them through
  `SessionDetailCubit`'s `PromptSendQueue` instead would strand every queued
  message whenever the user leaves before creation finishes, because no detail
  cubit exists at promote time — which would contradict both the promise that
  follow-ups send once the session exists and the lifetime argument that moved
  the operation out of the route in the first place.

  The session screen therefore **renders** follow-ups it does not own:
  `watchForSession(sessionId)` gives it the launch's queued, sending and failed
  follow-ups, drawn with the presentation each `LaunchFollowUp` variant names —
  the same `QueuedMessageBubble` presentations as its own queue, including the
  failure reason and Retry only on a failed one — and matched by promptId, so a
  delivered follow-up's bubble becomes the
  real row without moving. `_promptQueue` keeps owning everything typed **in** the
  session screen. **No second send queue type is created**, and the follow-up list
  still has exactly one owner.

  Two points about that handover, both corrections rather than restatements:

  - **Retry goes to the service, not the repository.** Cancel is a removal, so it
    goes to `SessionLaunchRepository.cancelFollowUp`. Retry is a *send*, and the
    only sender is `SessionLaunchService`'s serial delivery loop, which has already
    finished by the time a rejected bubble is on screen. A Retry written to the
    repository alone would flip the item back to undelivered and then sit there
    forever. It therefore calls `SessionLaunchService.retryFollowUp(launchId:, promptId:)`,
    which re-enters the same loop (see "The Launch Owner").
  - **An accepted follow-up is parked, not dropped.** The bridge's queued-prompt
    statement and the transcript echo are
    delivered independently of the send's HTTP response, so acceptance routinely
    outruns them. `SessionDetailCubit` already solves exactly this for its own
    sends and says so at the call site: `_promptQueue.parkAccepted(epoch: ++_parkEpoch)`,
    "the bubble keeps rendering from the parked slot until the bridge's queue
    statement, its delivered message, or an authoritative refresh accounts for the
    prompt, so acceptance outrunning those never blanks the row"
    (`session_detail_cubit.dart:2199-2209`). A launch follow-up that simply left
    the launch on acceptance would blank its bubble and then bring it back, because
    the detail cubit's queue never held it.

    So an accepted follow-up ends in the **existing** parked slot instead of in
    nothing: `PromptSendQueue` gains one operation,
    `adoptAccepted({required QueuedSessionSubmission submission})`, which parks an
    item the queue never sent. `SessionDetailCubit` calls it for each
    `AcceptedLaunchFollowUp` it receives — in the handoff it takes, and from
    `watchForSession` for a follow-up accepted after that. From then on
    `reconcileBridgeQueue` and `settleAwaitingAbsent` release it on exactly the same
    conditions as a locally sent prompt, and recovery from a later failure is the
    ordinary path. How long the launch itself holds an accepted follow-up is the
    handoff rule in "The launch's lifetime": until the handoff is taken or
    released, **whether or not a session screen existed at acceptance**. That is
    what covers the likeliest race — a follow-up accepted in the moment between
    `promote` and the replacement screen mounting — which an earlier draft, by
    dropping any acceptance no screen was watching, turned into a bubble that
    blanked during the handoff.
- **Voice stays available (**D7**, settled).** Keeping the composer mounted keeps
  the voice cubit alive through creation, and dictating a follow-up works exactly
  like typing one. The resources are released when the route is replaced or the
  user leaves.
- **The follow-up bubbles must survive the load, not just the swap.**
  `SessionDetailLoading` gains
  `required List<LaunchFollowUp> launchFollowUps` beside step 3's
  `launchSubmission` and `launchPluginId`, fed by `watchForSession` rather than a
  one-shot snapshot so a follow-up delivered mid-load updates in place, and the
  loading branch renders them below the first bubble. The follow-ups the cubit
  has already adopted into its parked slot are rendered there too, ahead of the
  launch's own, because they were accepted first; otherwise an adoption during the
  load would blank the very bubble adoption exists to keep. Without this they would vanish from the route
  replacement until the detail load completes — a window this plan measured at
  up to about 2.5 s on Pi and Hermes, plus relay tiers — because
  `_emitQueueUpdate` only publishes the queue in loaded states. The first
  message and its follow-ups are therefore handled symmetrically in every
  state.
- **Unsent composer content goes with the handoff.** **D9** keeps text,
  attachments and command entry live while creating, so at success the composer
  can hold content the user has not sent: typed text, a staged command, staged
  attachments. None of it is in `followUps`. Today the route replacement would
  dispose that `PromptInput` and lose the attachments and command outright, while
  the text, which `saveComposerDraft` persists under the `new-session:<projectId>`
  key (`composer_draft_repository.dart:8`), would resurface in the *next* new
  session for that project instead of this one.

  So the handoff carries it. `PromptInput` reports its staged attachments through
  an `onAttachmentsChanged` callback, the same way it already reports
  `onDraftChanged`, and `NewSessionCubit` keeps the latest list beside the
  `_composerDraft` and staged command it already holds. On
  `SessionLaunchSucceeded`, before emitting `created`, the cubit calls
  `SessionLaunchRepository.handOverComposer` with an `UnsentComposer({draft,
  command, attachments})` — a small Layer 0 value beside `SessionLaunch`, holding
  exactly what the composer holds (`command` nullable because a composer may hold
  none) — and clears the new-session draft key. The detail cubit receives it in
  `takeHandoff`, saves its draft under the session's key before its composer first
  reads `composerDraft`, stages the command through its existing `stageCommand`
  (`session_detail_cubit.dart:2880`) in its first loaded emission, and passes the
  attachments as the
  composer's `initialAttachments` (today `const []`,
  `session_detail_composer_controls.dart:69`), which step 4's budget-checked
  restoration then stages. An empty composer hands over nothing. When the created
  listener skips navigation because its route is no longer current, the composing
  route still holds its own composer, so nothing is lost there either.
- **Failure (D1, settled).** Q2 restores the first submission into the composer
  exactly as today, and the queued follow-ups are **appended into that same
  restored draft**, in the order they were typed, each separated by a blank line.
  Three consequences, stated plainly because this plan had recommended the other
  option: a follow-up's staged attachments are re-staged on the restored composer
  beside the first submission's, so nothing is silently dropped, and the merged set
  is put through the composer's existing budget check — which today it would not be,
  see below; a follow-up that was a slash command is
  appended as its literal `/cmd args` text, because the composer holds one command
  intent and that one belongs to the restored first submission; and the turns the
  user had separated arrive merged, which the user accepted as the cost of having
  everything in one editable draft. Whatever the user had typed but not yet sent
  when the failure lands — the text, command and attachments `NewSessionCubit`
  already keeps for the success handoff — is appended last under the same rules,
  because the restoration replaces the composer's content and clears its strip
  (`prompt_input.dart:492-499`). The restoration consumes the launch's
  follow-up list, so pressing Send again is an ordinary single submission. If the
  composing route is already gone there is nothing to restore into, and the
  follow-ups go with the launch while **D5** reports the failure.
- **The merged attachments must go through the budget check, which the restoration
  path bypasses today.** `PromptInput._restoreInitialAttachments` does
  `_attachments.addAll(widget.initialAttachments)`
  (`prompt_input.dart:279-281`), while the 50 MB aggregate limit and its notice
  live only in `_stageAttachment` (`:1851-1858`, `maxComposerPromptAttachmentBytes`
  plus `_showComposerNotice(sessionDetailAttachmentBudgetExceeded)`). That is fine
  today, because the only thing restored is one submission that already passed the
  check. **D1** breaks that assumption: it merges the attachments of several
  individually valid prompts into one, which can exceed the limit, and the current
  path would stage the over-limit set silently and leave it sendable.

  So `_restoreInitialAttachments` stages the restored list through
  `_stageAttachment` in order instead of `addAll`, stopping at the first one that
  does not fit and surfacing the existing notice. The user then sees the same
  rejection they would get from pasting one image too many, on the same surface,
  with the rest of their draft intact. No new limit, no new string, no partitioning
  across prompts: the honest rejection **D1** already promised, made true.
- Tests: `queueFollowUp` appends in order and mints distinct promptIds;
  command-plus-attachments is refused; option pickers stay locked while
  sending; the composer keeps staged attachments across the idle→sending
  switch; the service delivers follow-ups in order after promote **with no
  session screen ever opened**; a rejected follow-up is retained as
  `FailedLaunchFollowUp` with its `PromptSendFailure`, rendered by the session
  screen with Retry, and keeps its launch entry until the user retries or removes
  it; a rejected or thrown follow-up send logs the original error, with the stack
  trace when thrown, and records a feedback failure; retrying a rejected follow-up
  produces another `SessionRepository` send; cancelling a follow-up before delivery
  removes it; an accepted follow-up's bubble is still rendered after acceptance
  and before the bridge's queue statement, and disappears only once that statement
  or an authoritative refresh accounts for it — including a follow-up accepted
  **before** the replacement screen mounted, which arrives in the taken handoff;
  text, a staged command and staged attachments left unsent in the composer at
  success appear in the session screen's composer, and the new-session draft key
  is empty afterwards; the release predicate ignores a
  bridge-queued prompt whose id is an **already accepted** follow-up's; a creation
  failure appends the follow-ups into the restored draft in
  order, blank-line separated, with their attachments re-staged and a command
  follow-up appended as text; restoring a merged attachment set over the 50 MB
  budget shows the existing notice and stages only what fits.
- **Regression documents, in this PR:**
  `docs/regression/session-creation-and-options.md` — Send now keeps the
  composer, a second Send queues a follow-up instead of being blocked while a
  second *creation* is still blocked, options lock at Send, and a creation failure
  restores the first submission with the follow-ups appended into the draft;
  `docs/regression/session-turns.md` — follow-ups typed before a session id
  exists are delivered by the launch owner in order, independently of the session
  screen being open, a failed one waits with Retry until the user acts, and
  anything left unsent in the composer when the session opens is still in its
  composer there.
- **Feel check:** the composer must not lose focus, text, attachments or
  keyboard when the pane behind it changes at Send. The widget test asserts
  the same `PromptInput` `State` instance survives the phase change.

### Step 5: The pending-launch row in `SessionTile` lists (Q4, part 1) (module_core, module_app_ui, app, desktop)

- `SessionLaunchRepository` gains its broadcast stream, and
  `SessionLaunchCubit` is added and provided on both shells as described in
  "The Launch Owner".
- A new shared `PendingSessionLaunchTile`
  (`module_app_ui/lib/src/features/session_list/pending_session_launch_tile.dart`)
  renders one launch in `SessionTile` geometry: the same status slot, title
  line, meta line and paddings, taken from `session_row_metrics.dart` and
  `session_tile.dart:523-528`, so the swap changes no height.
  - **Content (D2, settled).** The launch's `title` snapshot — the first line of
    `submission.displayText` (or `/command`), taken at `start` so it survives
    `releaseHandoff` — as the title, the localised attachment-only fallback
    resolved by the tile when it is null, the
    animating sparkle `SessionTile._state` (`:370-396`) already shows for a
    running session in the status slot, the harness display name on the meta line
    via `PregoBrandLogo.displayNameFor(pluginId)`, and **no time** — which
    `SessionTile._time` already supports, since it returns null when
    `session.time == null`.
  - **Tappable, and it says why (D3, settled).** The user overrode the inert
    recommendation: an unresponsive row reads as a bug, so the row must both
    answer a tap and show that it is mid-creation. The lightest thing that does
    both, and the whole of it:
    - the meta line reads the localised "Creating…" **before** the harness name,
      on the same single line in the same style, so the row says what is happening
      without a second line, without a badge, and without changing its height; the
      sparkle in the status slot is the motion that backs it up, and the trailing
      slot stays empty, as **D2** requires;
    - the row is tappable and answers with the ordinary press feedback a real row
      gives, then one `PregoPopupAlertPresenter.show` (the presenter these views
      already use) with one new localised string saying the session is still being
      created and cannot be opened yet. Nothing navigates, nothing in the list
      moves, and the row stays exactly where it was, so a tap costs the reader
      nothing.
    - On the swap, "Creating…" drops off the meta line and the time appears in the
      trailing slot, in the same row, at the same height. The sparkle does not
      change at all, because the real running row already shows it — the row
      settles rather than being replaced.
    - Still excluded: no context menu, no swipe actions, no palette entry.
      `sessionMenuEntries` and `updateActionSession` require a real `Session` and
      are untouched.
- `SessionListContent` / `SessionListFilteredContent` gain
  `required List<PendingSessionLaunch> pendingLaunches` and insert those rows at
  the head of the **Today** heading, above running sessions, in
  `_sessionListRows` (`session_list_content.dart:64-89`) — the same place the
  heading rows are already synthesised. **D4, settled:** a launch is excluded from
  the All/Running/Unread counts, which keep describing the loaded list exactly,
  and the row is hidden while a search query is active and in the archived filter.
  No count path and no filter path learns about launches.
- **The empty state must count launches.**
  `session_list_content.dart:212`'s `if (loaded.sessions.isEmpty)` renders
  `SessionEmptyState` / `archivedEmptyState`. Because launches never enter
  `sessions`, leaving that condition alone would draw the placeholder row **and**
  the "no sessions yet" empty state together for the first session of a project
  — the single most common instant-new-session path — and the empty state would
  then vanish when the real row lands, moving the list and breaking feel
  property 3. The condition becomes "no session rows **and** no launch rows
  drawn" — counting only the launch rows this list actually draws, not every
  pending launch it was given. **D4** hides launches while a search query is
  active or in the archived filter, so a project whose only item is a launch,
  searched, draws no rows at all; counting that hidden launch would suppress the
  empty state and leave a blank page. Both inputs come from the same row list
  `_sessionListRows` builds, so the empty state and the rows cannot disagree.
  The same audit applies to `session_list_panel.dart` and
  `session_list_scaffold.dart`, which compose this widget and pass its empty
  states in.
- **Row identity is preserved across the swap, or the swap is not animated.**
  `session_list_content.dart:159` renders through `PregoAnimatedSliverList`
  with `itemKey: … ValueKey(session.id)`. A placeholder keyed by `launchId` and
  a real row keyed by `sessionId` are two identities, so the animated list would
  play a removal plus an insertion — collapsing one row's height and expanding
  another's — which moves every row below it. That is feel property 3 failing in
  the one moment the whole step exists to get right, so the plan must name a
  mechanism rather than assume the keys work out.

  The mechanism has two halves, and the second exists because the first is not
  enough on its own.

  **Published at `promote`, latched from that emission.** `promote` publishes the
  `launchId`→`session` association on its own stream, before any removal it or a
  later transition causes. A list drawing the placeholder latches it from that
  emission through a listener that sees every state, not a builder that can skip
  one. `promote` precedes the success outcome that navigates, so the normal
  instant-navigation path — whose `takeHandoff` removes an entry with nothing
  else owed, often before `session.created` reaches a session list — cannot take
  the association from a list that is about to need it.

  **Latched where the jump would happen.** A list surface that is currently drawing
  a placeholder for `launchId` records that association in its own state when it
  arrives, keeps drawing the placeholder until it would draw that session in the
  placeholder's slot — the head of Today, which a new session takes once its
  first activity statement makes it running (running sessions lead, newest user
  activity first), or at once when nothing else in the list is running — and keys
  the real session's row by `launchId` from then on. Until then it leaves that
  session out of its rows, and the one-update bound in "The launch's lifetime"
  covers a session that never runs here. So the
  placeholder and the real row are one item whose content changed and whose height
  did not (**D2** fixes the geometry), and the animated list plays no removal and
  no insertion.

  **Both halves of the latch matter, and the "keeps drawing" half is the one a
  first draft gets wrong.** `promote` and the `session.created` that puts the
  session into `loaded.sessions` are delivered independently, and `promote` comes
  from the create response the client is already awaiting, so it usually lands
  first. If the row followed the pending variant alone it would vanish at `promote`
  and reappear when the list caught up, producing an emission with neither row —
  a row blinking out and back, which is a worse failure of property 3 than the
  collapse-and-reinsert this mechanism exists to prevent, and it would also leave
  the latch nothing to hold. Holding the placeholder until the session actually
  sits in the placeholder's slot of this list's snapshot makes the swap a single
  content change with no gap at either end and no detour below running sessions. This is the surface-local half of the lifetime rule in "The Launch
  Owner".

  **Where the latch lives, and why it is not a cubit.** In
  `SessionListContent` only. It is the one widget in this step that renders session
  rows through `PregoAnimatedSliverList` (`:159`), and it is the widget all three
  hosts compose, so there is exactly one implementation. The domain fact — which
  `launchId` became which session — is **not** computed here; it is published by
  `SessionLaunchRepository`'s association stream and read through
  `SessionLaunchCubit` like any other state. What the widget holds is which key one
  animated-list item keeps, which is render identity: the same class of local state
  as `desktop_sidebar.dart`'s `_stickyActivitySessionId` and `_activitySessionIds`
  (`:393-419`), which exist for exactly this reason, and it cannot move into a
  cubit because "this list already drew that row" and "this list's snapshot now has
  that session" are facts only the mounted list has. Of step 6's surfaces, only the
  desktop sidebar renders session rows through an animated list
  (`PregoAnimatedList`, `desktop_sidebar.dart:670`, `:763`), so only it applies the
  same `launchId` key there; the phone and desktop home have no item identity to
  preserve and need only the "keep drawing until the session arrives" half. Step 6
  says so explicitly.

  `fail` removes the entry on failure, so no association is ever published for a
  launch that produced no session, and the latch drops with it.

  This is the most delicate mechanism in the plan and it is the only place where
  a plausible implementation could satisfy the state rules and still fail the
  feel rule. Step 5's offset assertion is therefore the gate, not a nicety: if
  the association approach cannot hold the neighbours still, fall back to
  suppressing the animation for this one transition (`Duration.zero` for the
  swapping pair) rather than shipping a list that jumps.
- Hosts pass the project-scoped launches: `session_list_scaffold.dart`,
  `session_list_panel.dart`, `desktop_session_list_screen.dart`. The archived
  list (`archived_sessions_view.dart`) passes none.
- `desktop_session_list_screen.dart:104`'s
  `showComposer = loaded.sessions.isEmpty || _creating` is untouched, because
  launches never enter `sessions`. Confirmed as the reason for the separate
  field.
- **Failure after the user has left (D5, settled).** A shell-level listener on the
  outcome stream — provided beside `SessionLaunchCubit` on both shells, so it
  lives as long as the app — removes the row and shows **one**
  `PregoPopupAlertPresenter` alert naming the project, through one new localised
  string. A row that appeared and then silently vanished is exactly the
  unexplained change the feel rules forbid.

  **The alert cannot double up, because the two readers see different values.**
  The listener matches `SessionLaunchFailedAfterLeaving` and nothing else; the
  composing cubit matches `SessionLaunchSucceeded` and
  `SessionLaunchFailedWhileComposing` and nothing else. Which of the two failure
  variants is published is decided once, by the owner, on a fact it already holds:
  whether the launch's payload had been released, which is exactly what "a
  composing route is still attached" means (see "The launch's lifetime"). An earlier
  draft said only that "the listener skips an outcome the composing cubit
  restored", which is not implementable — two independent listeners on one
  broadcast stream cannot infer each other's ordering — so no acknowledgement,
  claim or handled flag is needed or added: the stream delivers one value and one
  reader recognises it. The `projectId` the alert names travels on the variant.
- Tests: a launch adds exactly one row at the top of Today; the placeholder and
  the real row never both appear, which the sealed variants make structural; its
  removal on failure leaves the list as it was; a project whose only item is a
  launch shows the row and **not** the empty state, while the same project with a
  search query active shows the empty state and not a blank page; archived lists
  and an active search never show it; the chips' counts are unchanged by a launch; tapping the
  row shows the "still being created" alert and neither navigates nor moves the
  list; the row's height equals `SessionTile`'s at standard and accessibility
  text, with and without the "Creating…" prefix; a failure after the route is gone
  removes the row and shows one alert naming the project, and a failure while the
  route is still composing shows **no** alert; a promote whose session has not yet
  reached `loaded.sessions` still shows exactly one row, and the row below it does
  not move when that session arrives; with another session running, a new session
  that arrives before its first activity statement is not drawn below the running
  one, and the placeholder becomes its row in place when the statement lands; and
  a session still not running after the next update leaves the head of Today as an
  ordinary change rather than keeping "Creating…".
- **Regression documents, in this PR:**
  `docs/regression/projects-and-sessions.md` — the launching row: where it
  appears, that it leads Today, that tapping it reports the session is still being
  created while it carries no menu or swipe actions, that it is excluded from the
  chip counts and hidden while searching or archived, that a project whose only
  item is a launch shows the row rather than the empty state, that it never
  coexists with its own real row, and that a failure removes it with one alert
  naming the project.
- **Feel check:** the swap test asserts the y offset of the row below the
  placeholder is identical before and after, which is the mechanical proof of
  property 3.

### Step 6: The pending-launch row in the sidebar and Activity rows (Q4, part 2) (module_app_ui, desktop)

The remaining row surfaces use two other widgets, so they are a separate PR. Each
carries the same settled content and behaviour as step 5's row, in its own
geometry: the prompt's first line, the animating sparkle, "Creating…" before the
harness name where the row has a meta line, no time, a tap that shows the "still
being created" alert, and no menu or swipe.

- **Desktop sidebar** (`desktop/lib/core/widgets/desktop_sidebar.dart`): the
  project group's `_SidebarSessionRow` list (`:766`) and the Activity group's
  `_SidebarActivitySessionRow` list (`:975-1105`) each gain a pending-launch
  row above their real rows, in their own geometry (signals box, title, time
  slot). The launch is never added to `_activitySessionIds` (`:419`), never
  becomes `_stickyActivitySessionId` (`:391-404`), never reaches
  `entry.rows(selectedSessionId:)` (`:737`), and never reaches
  `updateActionSession` or `sessionMenuEntries`, because it is not a
  `Session`. The rail popout's `MultiBlocProvider` (`:472-477`) gains
  `SessionLaunchCubit` by value.

  **The Activity section's three emptiness gates count pending rows**, or a
  launch in a project with no real Activity has nowhere to appear: the rail
  trigger is built only when `activitySessions.isNotEmpty` (`:452`), the
  expanded header collapses to `kAlwaysDismissedAnimation` when
  `projection.activityGroups.isEmpty` (`:504`), and an open popout closes itself
  on the same condition (`:629`). All three become "no real Activity rows and no
  pending Activity rows". The section's group list (`:513`, `:638`) likewise
  includes a project whose only Activity content is a pending launch, whose
  group then draws the pending row alone. The header and rail counts
  (`desktopSidebarActivity(n)`) count the rows the section draws, pending
  included, so the count never reads 0 above a visible row; **D4**'s exclusion is
  about the session list's All/Running/Unread chips, which describe the loaded
  list, and is unaffected.
- **Activity rows** (`ActivityTile`, used by the phone project list
  `project_list_view.dart:436` and the desktop home pane
  `desktop_home_pane.dart:297`): a matching pending variant in `ActivityTile`
  geometry.
- **Phone home and desktop home.** `SessionActivityProjection` is **unchanged**.
  A launch cannot become a `SessionActivityEntry`, because that type requires a
  real `Session` and this plan does not synthesise one. Instead the launches
  reach the Activity hosts the same way they reach every other surface: as a
  separate pending list passed beside the projection's groups, rendered by the
  pending `ActivityTile` variant, in `project_list_view.dart:436`
  and `desktop_home_pane.dart:297`. Each pending row is drawn in the slot its
  real row will take — among the running rows, at its project's position in
  project order and ahead of that project's running sessions (after the Needs You
  rows on the phone and in desktop home's separate Running section) — so the
  projection taking it over is a content change, not a move. The phone's
  Activity gate (`if (activity.isEmpty) return const []`, `project_list_view.dart:417`)
  counts pending rows like the sidebar's gates do, and the phone home's title
  filter hides pending rows while its query is active, as **D4** does for the
  session list.

  No membership rule changes. `inMotion = isRunning || ((isAwaitingInput || isUnseen) && !isSetAside)`
  (`session_activity_projection.dart:81`), so the **real** row enters Activity
  once the session's first activity statement makes it running. Until then — and
  `session.created` usually arrives first, because `SseEventTracker` takes
  activity only from project summaries and `SessionUnseenTracker` applies only
  `SesoriSessionUpdated` — the projection classifies the new session as Recent.
  That window is why the release condition below is the projection, not the
  source list.
- **The Activity hosts must animate the row in and out, because neither of them
  animates anything today.** The phone project list renders Activity through a
  plain `SliverList.list` (`project_list_view.dart:433-448`) and the desktop home
  pane through a plain `Column` (`desktop_home_pane.dart:276-305`) — unlike step 5's
  `PregoAnimatedSliverList` host, these grow and shrink instantly. So the first
  launch appearing, and a failed launch disappearing, would relayout everything
  below with no transition at all: a section heading and a row popping into the
  middle of what the user is reading, which is precisely the unexplained change the
  feel rules forbid, and there is no animated list here to prevent it.

  Both hosts therefore wrap the pending rows in a height transition using the same
  idiom **D8** already establishes for this feature: 240 ms, and no animation under
  reduced motion (the same `MediaQuery.disableAnimations` check the existing
  `_PageFade` and `PregoAnimatedSliverList` already respect, so the reduced-motion
  behaviour is an instant cut, not a shorter animation). Nothing else about these
  sections changes, and the real rows keep behaving exactly as they do today.

  The desktop sidebar's groups are not in this: their session rows already render
  through `PregoAnimatedList` (`desktop_sidebar.dart:670`, `:763`, keyed by
  `session.id`), so an inserted or removed pending row animates there for free,
  with the item key being the `launchId`.
- **Step 6's surfaces also hold the row until the real row would take its
  place.** Only the sidebar renders session rows through an animated list, so
  only it keys the swapped row by `launchId` as step 5's latch does (the same kind
  of render state as its `_stickyActivitySessionId`); the phone and desktop home
  need no row key. All of them need the other half of the same rule
  in "The launch's lifetime", because all of them can receive `promote` before
  the session reaches their own data. On the sidebar's project group the slot is
  the head of the project's rows, as in step 5. On an Activity host (the phone
  home, the desktop home and the sidebar's Activity group) the slot is the
  session's Activity entry, so the hold lasts until `SessionActivityProjection`
  places the session in Activity, not merely until the source list contains it;
  meanwhile the host leaves that session out of its other sections — desktop
  home's Recent (`desktop_home_pane.dart:274`) is the one that would otherwise
  draw it — so a launch never has two rows on one surface. No new state is
  involved: the host already builds the projection it checks, and it already
  holds the association it latched. The one-update bound from the lifetime rule
  applies unchanged, so a first command that never runs cannot leave "Creating…"
  behind.
- The desktop command palette (`desktop_command_palette.dart:48-55`) reads a
  snapshot at open time and lists real sessions only. Launches are **not**
  added there: a row you cannot open is not a useful palette entry.
- Tests: each of the three row widgets renders a launch above its real rows;
  tapping any of them shows the alert and selects nothing; the sidebar never
  treats a launch as selected, sticky or menu-bearing; the
  phone home shows the launch and drops it on completion;
  `SessionActivityProjection`'s existing tests are untouched, which is the proof
  that the projection did not change; the Activity hosts animate the row's
  insertion and removal over 240 ms and cut instantly under reduced motion; a
  promote that arrives before the session reaches the host's snapshot leaves the
  row in place rather than blanking it; a session that reaches the source before
  its first activity statement keeps the placeholder in Activity, is **not**
  drawn in desktop home's Recent, and becomes the Activity row in place when the
  statement lands; with no real Activity sessions, a pending launch still shows
  the sidebar's rail trigger, expanded header and popout (which stays open), and
  the phone home's Activity section; and a searched phone home hides the pending
  row.
- **Regression documents, in this PR:**
  `docs/regression/desktop-cockpit-shell.md` — the sidebar's launching row in the
  project and Activity groups, and that it is never the selected or sticky
  session; `docs/regression/projects-and-sessions.md` — the launching row in the
  phone home and desktop home Activity groups, and that it animates in and out
  rather than appearing instantly.
- **Feel check:** record the phone home and desktop home on a real device while a
  launch appears and while one fails, and confirm nothing below the Activity
  section jumps.

### Step 7: Run coverage and retire

Run the level and matrix recorded here, record the result in `TRACKER.md`, and
move the plan to `.plan/completed/`.

There is deliberately **no** separate regression-reconciliation step. Each
behaviour-changing step edits the regression documents its own PR makes true, as
the repository requires, so no implementation PR can merge while the regression
source of truth still describes the behaviour it just replaced. This step only
confirms that the merged documents match what shipped and closes the cleanup
audit below.

### Complexity budget

New mutable parts: **one** — the `SessionLaunchStorage` map of launches, with
its repository as sole publisher, its service as sole driver of the operation,
and its cubit adapter. Everything else is immutable: sealed `SessionLaunch`
values, sealed launch outcomes, and `launchSubmission` / `launchPluginId` /
`launchStartedAt` / `launchFollowUps` on the detail loading and loaded states. The
one addition beyond that is the row-key association a list surface latches while
it is drawing a placeholder (`SessionListContent`, step 5); it is local widget
state in the one widget that drew the row, and it exists because that widget is
the only thing that knows it drew one.

The second review wave added no new part. It added fields to values that already
existed (`startedAt` and `followUpIds` on `SessionLaunch`, `sendingSince` on the
bubble's sending presentation), split one sealed failure outcome into two so a
single reader recognises each, and **removed** one thing: `complete(launchId:)` is
gone, because removal is now the repository's own consequence of nothing being
owed rather than a call some collaborator has to remember at the right moment.

The third review wave added no new part either. It added two small immutable
values — the sealed `LaunchFollowUp`, shaped exactly like the detail queue's
existing `LocalSendPhase`, and `UnsentComposer` — and one repository operation,
`handOverComposer`. `NewSessionCubit` mirrors the composer's staged attachments
beside the draft and staged command it already mirrors, through a callback of
the same shape as `onDraftChanged`. The rest of the wave changed rules, not
parts: an accepted follow-up belongs to the handoff, a failed one is owed until
the user acts on it, and a placeholder is held until the real row would take its
slot, with a one-update bound; the Activity hosts check that slot against the
projection they already build.

Justification for the one part: Q3 needs the queue to survive the route
replacement, and Q4 needs the row to survive Back. Nothing already in the app
outlives both, and the alternative is three carriers instead of one. It is keyed
rather than a single slot only because a visible row makes silent overwriting a
user-visible bug (see "The Launch Owner").

The service is not extra machinery, it is where the machinery already had to be:
creation already outlives the route today, and today's consequence is merely a
dropped analytics event. Q3 and Q4 raise the cost of that gap to unsent messages
and a permanent phantom row, so the owner moves to match the lifetime the
operation always had.

Explicitly **not** added: a second send queue type (the launch's own follow-up
list is the only carrier until the bridge accepts a prompt, `PromptSendQueue`
keeps owning sends made in the session screen and gains one operation,
`adoptAccepted`, so an accepted launch follow-up parks in the existing slot
instead of in a new one), a claim, acknowledgement or handled flag between the
outcome stream's two readers (the sealed variant decides the reader),
a second copy of the follow-up list, a `submission` field on
`NewSessionCreated`, a promptId for the first message, a synthetic `Session`, a
`String? sessionId` on one flattened launch class, a pending session id or wire
change, a launch progress protocol, creation cancel, automatic resend,
echo-correlation state, a bubble timeout, persistence or timers of any kind, a
byte cap on the launch queue (see **D11**), and retaining the launch through a
failed first load. Stop and ask if implementation seems to need any of them.

## Decisions (all settled, 2026-09-26)

The user answered D1 to D9 on 2026-09-26. D10 and D11 were never user questions;
they are the plan's own recorded decisions, restated here so the implementer finds
every decision in one place. Nothing in this plan is open. Where an answer went
against this plan's recommendation — **D1** and **D3** — the plan follows the
answer, the recommendation is recorded as rejected, and the consequences are
spelled out rather than softened.

### D1. Queued follow-ups when creation fails

**Decided: append the follow-ups into the restored composer draft, separated by
blank lines.** Neither discarding them nor retrying automatically was chosen.

The failed launch's first submission is restored exactly as Q2 asks — text, voice
spans, command intent, attachments — and each queued follow-up's text is appended
below it in order, separated by a blank line, so the user ends up with one
editable draft holding everything they had typed.

The recommendation (keeping them as cancellable pending bubbles) is **rejected**.
It was argued for on the grounds that appending loses data; the plan carries that
concern into the implementation rather than leaving it to be discovered:

- **Attachments are re-staged, not dropped, and the merged set is checked.** A
  follow-up's staged attachments are restored onto the composer beside the first
  submission's. The existing per-prompt limit then applies to the merged set
  through the composer's existing rejection surface, so an over-limit merge is
  something the user sees and edits, never a silent loss.

  That required one correction, because it was not true as written: the
  restoration path is `PromptInput._restoreInitialAttachments`, which does
  `_attachments.addAll(widget.initialAttachments)` (`prompt_input.dart:279-281`)
  and so never reaches the aggregate check in `_stageAttachment` (`:1851-1858`).
  Restoring one already-valid submission could not exceed the budget, so nothing
  noticed; merging several can. Step 4 therefore routes restoration through
  `_stageAttachment`, which keeps the existing limit, the existing notice and the
  existing surface, and adds no new ones.
- **A command follow-up is appended as its literal `/cmd args` text.** The
  composer holds one command intent and it belongs to the restored first
  submission. The text stays editable and re-sendable.
- **Merged turns are the accepted cost.** The user chose one draft over several
  bubbles, and this plan follows that.

If the route is already gone there is no composer to restore into; the follow-ups
go with the launch and **D5** reports the failure.

### D2. What the placeholder row shows

**Decided: the same row shape as a real session row, with the first line
of the prompt as the title, the sparkle in the status slot, the harness
name on the meta line, and no time.** **D3** adds one localised word before the
harness name on that same meta line; nothing else about this changes.

- **Title** — the first line of `submission.displayText`, or `/command` for a
  command start (snapshotted into the launch at `start` so a released handoff
  does not blank it), or the localised attachment-only fallback, which the tile
  resolves when that snapshot is null. Real rows show
  `session.title ?? loc.sessionListUntitled`, and a generated title arrives
  later through `session.updated`, so the prompt's first line is the closest
  honest stand-in and usually resembles the title that follows.
- **Status slot** — `PregoAiLoader` animating: exactly what
  `SessionTile._state` (`:370-396`) already shows for a running session. This
  is the spinner the user asked for, and reusing the running mark means the
  slot does not change at all on the swap.
- **Meta line** — the harness display name via
  `PregoBrandLogo.displayNameFor(pluginId)`. The plugin is chosen before Send,
  so this is known and identical to what the real row will show. Since
  `docs/regression/projects-and-sessions.md` fixes rows at 70 px because
  "every row names its harness", omitting it would change the height and
  break property 3.
- **Time** — omitted. `SessionTile._time` already returns null when
  `session.time == null`, so this is an existing, supported shape, and it
  avoids inventing a timestamp. The real row then shows a time, which changes
  the trailing slot's content but not the row's height.
- **Where it appears** — the launch's project only, in: the phone full session
  list, the phone split-view list pane, the desktop project page list, the
  desktop sidebar project group, and cross-project in the desktop sidebar
  Activity group, the desktop home pane and the phone home Activity group.
  Never in an archived list and never in the command palette.
- **How it sorts** — at the very top. `SessionListService.visibleSessions`
  puts running sessions first, and `session_list_content.dart:36` forces
  running rows into the **Today** heading whatever their stored time. A launch
  is the newest running thing, so it leads Today; the real session then also
  leads Today, in the same slot. That is why the swap does not move the list,
  and it is the reason this design works at all.

### D3. Can the placeholder row be tapped?

**Decided: yes, it is tappable, and it also says on the row that it is being
created.** The inert recommendation is **rejected** in the user's own words: an
unresponsive row "will seem like a bug", so the row must (a) tell a tapping user
that the session is being created and cannot be opened yet, and (b) signal that
state in the row itself. Only the tap is in scope; swipe actions and a context
menu remain out.

The lightest design that honestly satisfies both, and all of it:

- **The row says it.** The meta line reads a localised "Creating…" immediately
  before the harness name, on the same single line, in the same style. It adds no
  second line, no badge and no height, so **D2**'s geometry and the 70 px row
  contract hold, and the trailing slot stays empty as **D2** requires — no
  invented time. The sparkle already animating in the status slot is the motion
  that backs the word up.
- **The tap answers.** The row takes a tap with the same press feedback a real row
  gives — so the finger gets a reaction, which is the actual complaint about
  inertness — and then shows one `PregoPopupAlertPresenter` alert with one new
  localised string: the session is still being created and cannot be opened yet.
  Nothing navigates, nothing scrolls, nothing in the list moves, so the reader
  loses their place for exactly nothing.
- **How the swap feels.** When the real row lands, "Creating…" drops off the meta
  line and a time appears in the trailing slot. The sparkle does not change,
  because a freshly created session is running and already shows it. The row
  settles into itself instead of being replaced, and the rows below it do not move.
- **Still excluded:** no context menu, no swipe actions, no command-palette entry.
  `sessionMenuEntries` and `updateActionSession` keep requiring a real `Session`.
- **Not chosen:** re-creating the new-session route from the launch so a tap could
  return to the composer. It needs a rebuilt route for a rare tap, and **D4** keeps
  this row out of search and archived views anyway. It stays available later if
  the alert proves annoying.

### D4. The placeholder, the quick-filter chips and search

`docs/regression/projects-and-sessions.md` says the All/Running/Unread chips
carry "exact counts from the loaded list", and the phone search field "narrows
the loaded titles without a request".

**Decided: the placeholder is excluded from all three chip counts, and is
hidden while a search query is active or the archived filter is on.** It is not
a loaded session, so counting it would make the chips disagree with the list
they describe; and a row that ignores the user's search would read as a bug. The
alternative — counting it under Running and matching it against the query — is
**not** taken: it would add the launch to three count paths and a filter path for a
row that lives for a few seconds.

Related and **not** optional: the list's **empty state** must treat a pending
launch as content, because a project's first session is the commonest path
through this feature and showing "no sessions yet" above a launching row would
be plainly wrong. That is settled in step 5 rather than asked here; only the
chips and the search field are genuinely a matter of taste.

### D5. Failure after the user has left the route

Today, leaving mid-creation shows `newSessionLaunchingInBackground` ("Your new
session will appear in the list once it's launched") and a later failure is
silent, because nothing had been promised. With Q4 a row is now visibly
promising that session in every list.

Only the product half of this was ever a question. The architectural half was
already settled in the plan: the observer of a late outcome is the launch owner,
not the closed `NewSessionCubit`. Without that, neither option below could be
implemented, because nothing would be alive to notice.

**Decided: remove the row and show one popup alert naming the project**,
through the existing `PregoPopupAlertPresenter`, with one new localised string. A
row that appears and then silently vanishes is the kind of unexplained change the
feel rules forbid. Staying silent is **not** chosen. The alert is shown by a
shell-level listener on the launch outcome stream (step 5) and only ever fires for
`SessionLaunchFailedAfterLeaving`, which the owner publishes exactly when no
composer is attached to the launch any more. A user who never left therefore sees
their restored draft and no alert, and one who left sees the alert and no draft,
with no coordination between the two listeners (see step 5).

### D6. More than one launch at a time

**Decided: support several concurrent launches, each with its own row.**
Desktop makes this easy to reach (the home composer and a project composer are
separate surfaces), and the cost is a map instead of a field. The alternative,
a single slot, would make the second launch erase the first's row and queue.
The map is bounded by real in-flight creations, plus any launch holding a failed
follow-up the user has not acted on, and each entry leaves once nothing is owed
(see "The launch's lifetime").

### D7. Mobile voice resources during creation

Unmounting the composer at Send is today how mobile voice resources get
released during launch — the comment at `new_session_view.dart:550-556` says
so explicitly. Keeping the composer mounted (Q3) keeps the voice cubit alive
through creation.

**Decided: voice stays available while creating.** The composer being usable is
the point of Q3, and the resources are released when the route is replaced or the
user leaves, which is within seconds. Disabling voice specifically while sending is
**not** chosen: being able to type a follow-up but not dictate one is a confusing
partial capability.

### D8. The desktop composer moves at Send

On desktop the idle composer sits inline in a centred, scrolling column
(`new_session_view.dart:274-295`), while a session screen's composer is
bottom-anchored. With Q3 keeping it mounted, it must move from the centre to
the bottom at Send.

**Decided: the move happens at Send and is animated once**, as the transition
that explains "this is now a session", at 240 ms, with no animation under reduced
motion. The move is unavoidable — the composer has to end up at the bottom — so
the only question was whether it happens visibly at Send or invisibly during the
later route replacement, and doing it at Send, animated, is the honest version.
The page chrome the pane carries while idle is hidden in the same moment (step 4),
so the pane becomes session-shaped in one movement rather than two. Phone is
unaffected: its composer is already bottom-anchored in both branches.

### D9. Options stay locked while creating

**Decided: locked at Send** — harness, agent, model, variant and worktree
mode cannot change once Send commits them to the request in flight, and
follow-ups inherit them. Only text, attachments and command entry stay live.
This also keeps the existing behaviour where an options refresh arriving
mid-send is dropped. Letting the user change the model for the queued follow-ups
only is **not** chosen: the page would show one selection while two different ones
were in flight.

### D10. Follow-ups do not use the positional release

**Recorded (plan decision, not a user question): only the first message is
released by position**; follow-ups
carry real promptIds and settle through the existing promptId matching in
`SessionDetailMessageList`. Stated here because it is easy to get wrong during
implementation: applying the positional rule to follow-ups would drop the
wrong bubble.

### D11. Queued attachment bytes are not capped

`ComposerAttachment` holds decoded bytes with a 50 MB cap **per prompt**
(`composer_attachment.dart:10`), and the existing `PromptSendQueue` puts no
ceiling on the total across queued items. N follow-ups can therefore pin N ×
up to 50 MB while creation runs.

**Recorded (plan decision, not a user question): add no cap**, matching the
existing session queue exactly.
Adding one here would invent a limit new sessions have and existing sessions
do not, for a window of a few seconds, with no observed failure. Recorded so a
later reviewer does not reopen it without evidence.

## Edge Cases

- **Duplicate submit of the *first* message:** still blocked —
  `canCreateSession` stays false while sending. A second Send is a follow-up,
  not a second creation.
- **Idempotency:** creation remains non-idempotent, and the duplicate-risk
  warning on uncertain failure stays. See the later phase.
- **Navigating away mid-creation:** creation continues in
  `SessionLaunchService`, which outlives the route, so the launch reaches
  `promote` or `fail` either way. The placeholder row stays in the lists until it
  does, the queued follow-ups are delivered by the service without needing any
  screen to be open, and the analytics outcome is still reported — none of which
  is true today. The existing alert still fires. Failure handling is **D5**: the
  row goes and one alert names the project.
- **Navigating back to New Session:** a fresh cubit and composer. The in-flight
  launch is unaffected and keeps its own row.
- **Deep links and restoration:** the launch lookup is by session id and
  optional. A detail route opened any other way finds no launch and loads as
  today.
- **Desktop multi-pane:** the embedded project-page and home composers use the
  same view. `desktop_session_list_screen.dart`'s `_creating` flag keeps the
  composer pane visible through creation, as today, and launches never enter
  `sessions`, so its `sessions.isEmpty` branch is unaffected.
- **Older bridges:** no wire change in any step, so there is nothing to
  negotiate. The release rule and the placeholder are client-side and
  bridge-version-independent.
- **Harness never echoes (turn fails before echo):** the bubble stays as
  sending until a refresh delivers the echo. The existing session status and
  error surfaces report the failure. Accepted.
- **Process death during launch:** the launch, its bubble, its queue and its
  row are all in memory only, so they are lost, exactly as an unacknowledged
  send is today. No persistence is added.
- **A follow-up is rejected before the bridge accepts it:** it stays on the
  launch as `FailedLaunchFollowUp` until the user acts, the service logs the
  original error, and any session screen for that session renders it as a failed
  bubble whose remove cancels it on the launch and whose retry calls
  `SessionLaunchService.retryFollowUp`, because the service owns the only sender.
  Once accepted, it follows the handoff rule in "The launch's lifetime": held for
  the handoff while that is owed, parked by the taker (`adoptAccepted`), after
  which the existing `holdFailedSend` / retry / remove surfaces own it; if the
  handoff was released it leaves the launch, keeping only its promptId in
  `followUpIds`.
- **Text typed but not sent when creation succeeds:** carried to the session
  screen's composer with its staged command and attachments, and cleared from
  the new-session draft (step 4).
- **A bridge queue statement for an already-accepted follow-up:** ignored by the
  first bubble's release predicate, because the exclusion is over every promptId
  the launch ever minted, not only the undelivered ones. Without that, the single
  most likely event in the whole flow would read as the first message's echo.
- **A creation failure with follow-ups queued:** **D1** — the first submission is
  restored and the follow-ups are appended into the same draft, blank-line
  separated, with their attachments re-staged.

## Cleanup Assessment

Directly caused by this change, and included in the step that causes it:

- The sending-branch `PregoLaunchStatus` usage and its widget-test
  expectations (step 2). `newSessionLoadingMessage1..3` stay, because the
  ordinary session-detail load still uses them.
- `SessionDetailCubit._generatePromptId()` and `_promptIdRandom` are deleted
  when the shared `generatePromptId()` replaces them (step 4).
- `NewSessionCubit`'s own `await` of `createSessionWithMessage`, its
  post-response `isClosed` early return, and its inline analytics reporting go
  when `SessionLaunchService` takes over the operation (step 3). The analytics
  calls move rather than disappear.
- The `!isSending` half of the composer's `canSend` (`:416`) and the
  now-redundant sending checks that the gate split subsumes (step 4).
- Old assertions that the sending phase renders a spinner, that the composer
  is unmounted while sending, and that Send is blocked while sending, across
  `module_app_ui`, `app` and `desktop` tests (steps 2 and 4).

No obsolete database columns, wire fields, caches, flags, jobs or
compatibility paths were found: no step changes persistence or the wire.

## Later Phase (rough, not planned in detail)

- **Honest progress** (from the superseded plan): a client `launchId` on
  `CreateSessionRequest` plus a bridge `session.create.progress` event with
  `startingPlugin`, `preparingWorkspace`, and `creatingSession`, shown as an
  inline stage line under the bubble, and on the placeholder row. This is wire
  plus bridge work. It is worth doing only if cold waits still feel opaque with
  the bubble and the row in place.
- **Shorter real creation.** Per Q5, deliberately **not** planned now.
  Revisit after step 3 ships, when we can judge whether the perceived fix is
  enough. The candidates remain: pre-warm the selected plugin when the
  new-session screen opens (OpenCode cold is 16.6 s and Hermes 5.8 s), and
  overlap the base branch fetch with plugin start (which needs worktree
  cleanup when plugin start fails).
- **Idempotent creation** keyed by a client id, so a retry after response loss
  cannot duplicate a session and the warning can go. This would also let **D5**
  offer Retry instead of only reporting failure.

## Delivery Plan

| Step | Exact PR title | Scope | Size |
|---|---|---|---|
| 1/7 | `🌿 [instant-new-session] Plan opening new sessions instantly [step 1/7]` | This plan and `TRACKER.md`; remove the superseded `instant-session-launch` plan. | docs only |
| 2/7 | `⚙️ [instant-new-session] Show the first message while a new session is created [step 2/7]` | Step 2 design: session-shaped creating view on every surface, `displayText`, the relocation of **two** composer models out of `cubits/` (the submission snapshot and `QueuedSessionSubmission`) and of `PromptSendFailure` out of `repositories/models/`, all three needed by a Layer 0 launch, 180 s create timeout, tests, its regression-document edits. | 650–900 |
| 3/7 | `🚧 [instant-new-session] Hand the first message off to the session screen [step 3/7]` | Step 3 design: the launch owner family including `SessionLaunchService` and the typed outcome stream, `NewSessionCubit` handing creation over with its analytics and feedback records, detail state, the single release funnel, the `sendingSince` slow-send carry, detail presentation, transition-free phone swap, tests, its regression-document edits. | 950–1,250 |
| 4/7 | `🚧 [instant-new-session] Keep the composer live and queue follow-up messages [step 4/7]` | Step 4 design: gate split, follow-ups owned by the launch, shared `generatePromptId`, composer mounted in both sending branches with the desktop move and chrome hiding, sealed `LaunchFollowUp`, service-owned delivery with its retry, failure log and the handoff-held accepted follow-ups, the unsent-composer handoff, the restoration budget check, failure appending into the draft, tests, its regression-document edits. | 1,000–1,300 |
| 5/7 | `⚙️ [instant-new-session] Show a launching row in the session lists [step 5/7]` | Step 5 design: row and association streams, `SessionLaunchCubit`, shell providers and the failure alert listener, `PendingSessionLaunchTile` with its tap, the three `SessionTile` hosts, the row-key latch and the hold-until-in-its-slot rule, the visible-rows empty state, tests, its regression-document edits. | 700–900 |
| 6/7 | `⚙️ [instant-new-session] Show a launching row in the sidebar and Activity [step 6/7]` | Step 6 design: two sidebar rows, pending `ActivityTile` variant, rail popout provider, the Activity emptiness gates, the phone and desktop home hosts with their 240 ms insertion transition and the projection-based hold, tests, its regression-document edits. | 600–800 |
| 7/7 | `🌿 [instant-new-session] Run new-session coverage and retire the plan [step 7/7]` | Run the matrix below, record it in `TRACKER.md`, confirm the merged regression documents match what shipped, and move the plan to `.plan/completed/`. | docs only |

Regression documents travel with the step that changes behaviour, which is why
there is no separate reconciliation PR: each implementation PR leaves the
regression source of truth true about the app as merged.

Every implementation step is independently valid and independently valuable:

- step 2 alone removes the first spinner;
- step 3 removes the second spinner and the empty gap;
- step 4 removes the wait before you can keep typing;
- step 5 makes the launch visible in the lists that matter most;
- step 6 finishes the remaining row surfaces.

Steps 2 and 4 both touch the two sending branches of `NewSessionView`, so step
4 partly rewrites layout step 2 introduced. That churn is accepted on purpose:
merging them would put the instant screen and the live composer in one PR of
roughly 1,100 to 1,500 lines covering both presentation and new cubit state,
and would delay the most valuable and least risky half of the feature behind
the more contentious half.

Every step is inside the ~1,500-line soft cap, and steps 3 and 4 are
deliberately held near 1,000 to 1,300 because they carry the cross-layer and
state-machine risk. The second review wave raised each estimate by roughly 100 to
250 lines; step 2 absorbs the second model relocation, which is import churn
rather than logic. The third wave raised step 4 by about 150 to 200 lines (the
sealed follow-up, the failure log and the unsent-composer handoff) and steps 5
and 6 by about 50 each (the in-slot hold and the emptiness gates). If step 4's
real diff passes about 1,300 lines, the clean cut is to land the shared
`generatePromptId` extraction and the restoration budget check first as their own
PR, since neither depends on the live composer, and renumber the series and
update `TRACKER.md` as the step 3 split below describes; that is a pre-approved
split of already approved work.

**Pre-approved split if step 3 runs long.** Step 3 is the largest step and now
carries the launch-owner family as well as the detail-side handoff. If the real
diff passes about 1,200 lines, split it into `3.a` (the launch owner family plus
`NewSessionCubit` handing creation over to the service, with the new-session
surface as its first reader) and `3.b` (the detail-side handoff: state fields,
the release funnel, presentation, and the phone transition), renumber the series
to eight steps, and update this table and `TRACKER.md`. A clean split of already
approved work needs no permission. The two halves are not merged the other way
round: the owner family without any reader would be dead code.

## Verification

- **Step 2:** `module_app_ui` widget tests plus `dart analyze --fatal-infos`;
  `module_core` API tests.
- **Step 3:** `module_core` cubit, state, and repository tests;
  `module_app_ui`, `app`, and `desktop` widget and routing tests.
- **Step 4:** `module_core` cubit and queue tests; `module_app_ui` widget tests
  including the composer-identity assertion.
- **Step 5:** `module_core` repository/cubit tests; `module_app_ui`, `app` and
  `desktop` widget tests including the row-offset assertion, which is the gate
  on the swap mechanism, and the empty-state case.
- **Step 6:** `desktop` and `module_app_ui` widget tests.
- Every step analyses each touched package with `--fatal-infos`.

### Regression documents

Each document is edited by the step that makes its new text true, named in that
step's design above. Nothing here waits for a later PR.

- `docs/regression/session-creation-and-options.md` (primary; steps 2, 3 and 4).
  Three existing rules change materially:
  - "Send immediately replaces the composer with detail-shaped launch status
    while the unresolved URI remains `/projects/<projectId>/sessions/new`.
    Duplicate Send is blocked." — Send now shows the sending bubble and
    **keeps** the composer; a second Send queues a follow-up instead of being
    blocked, while a second *creation* is still blocked.
  - "A creation failure on the still-current route restores the exact submitted
    text/voice spans, command intent, and memory-only attachment identities
    once …" — extended by **D1**: any queued follow-ups are appended into that
    same restored draft, blank-line separated and in order, with their
    attachments re-staged and a command follow-up appended as literal text.
  - The L3 row's "Send immediately renders launch status at the unresolved
    route, blocks duplicate submit, and replaces with the durable session"
    becomes the sending bubble, the launch handoff, the positional release, the
    follow-up queue and the 180 s timeout.
- `docs/regression/projects-and-sessions.md` (steps 5 and 6): the launching row,
  where it appears, that it leads Today, that tapping it reports the session is
  still being created while it carries no menu or swipe actions and never becomes
  the selected session, that its meta line names the harness after "Creating…" and
  shows no time, that a project whose only item is a launch shows the row rather
  than the empty state, that it never coexists with its own real row, that it is
  excluded from the chip counts and hidden while searching or archived (**D4**),
  and that a failure removes it with one alert naming the project (**D5**).
- `docs/regression/session-turns.md` (steps 3 and 4): the launch bubble in the
  transient-row ordering and its positional release, and that follow-ups typed
  before a session id exists are delivered in order by the launch owner whether or
  not the session screen is open.
- `docs/regression/navigation-transitions.md` (step 3): the transition-free
  created-session replacement. Its existing rule already requires the
  new-session page to change in place without a fade when its first prompt
  turns it into the session, so this is a confirmation rather than a new claim.
- `docs/regression/desktop-cockpit-shell.md` (step 6): the sidebar's launching
  row.
- `docs/HARNESS_CAPABILITIES.md`: no entry. Nothing here is harness-specific;
  every harness gets all of it.

### Highest level and matrix

**L3 Release, client end to end.** The claim spans rendering, navigation,
list composition, and each plugin's first-message echo.

- **Client:** phone (the release-target platform) in narrow and split layouts,
  and desktop on all three creating surfaces, plus the sidebar, the desktop
  home pane and the phone home Activity group.
- **Plugins:** every supporting production plugin, starting with a text
  prompt. The release rule must be observed on each echo family: ACP
  synthesized echo, Claude CLI replay, OpenCode backend SSE, Codex, and Pi
  queue. Also run one command start on Claude and on one ACP harness.
- **Modes:** dedicated and in-place, with warm and cold plugins. A cold
  OpenCode start is the best case for watching the bubble, the live composer
  and the placeholder row all at once.
- **Follow-ups:** queue two follow-ups during a cold create, confirm they send
  in order after the session exists, confirm one can be cancelled before it does,
  and repeat the run leaving the route immediately after queueing them — they must
  still send, with no session screen ever opened.
- **The launching row:** tap it and confirm the alert says the session is still
  being created, that nothing navigates and the list does not move, and that the
  row reads "Creating…" before the harness name until the real row takes over.
- **Failure:** definitive rejection, and response loss or timeout, restore the
  exact draft with the warning and remove the placeholder row; with follow-ups
  queued, confirm they arrive appended into that draft in order with their
  attachments re-staged (**D1**). Also cover Back mid-creation, and failure after
  leaving the route, which must remove the row and show exactly one alert naming
  the project (**D5**).
- **Acceptance is structural:** the bubble appears in the first sending frame;
  no frame between Send and the echo lacks the message or shows a spinner or
  "No messages yet"; the bubble's rect, its harness name **and its "Sending to
  `<harness>`…" text** are unchanged across the route replacement and across the
  loading→loaded swap (a cold OpenCode create is the run for this, being far
  longer than the 2 s threshold); no frame shows neither the placeholder row nor
  the real row; and the row below the placeholder does not move when the real row
  replaces it.
- **Abandoned launches:** start a create on a cold harness, leave the route
  immediately, and confirm the row still resolves, the follow-ups still send
  when the session is opened, and the analytics outcome is still reported. Confirm
  the follow-ups' `sessionMessageSent` events arrive in the debug analytics log,
  since the service, not the session screen, reports them.

## Risks And Accepted Limits

- Cold starts stay as slow as they are. This plan changes only what the user
  sees and can do while waiting. Q5 defers the real fix.
- The positional release could drop the first bubble early if a different user
  message echoed first. No current plugin can do that before the initial
  dispatch, and the outcome self-corrects.
- Two accepted losses of the bubble, both client-side only and neither losing the
  message itself: a first message that is a command producing no transcript entry
  (a Pi notification-only command) leaves the bubble reading "Sending" until the
  session screen is reopened, and a first load that ends in the failed or
  harness-unavailable state drops the bubble, in a state that explains itself. No
  echo correlation, bubble timeout or extra state is added for either.
- **D1** merges turns on a failed creation. The follow-ups arrive appended into one
  draft rather than as separate messages, and a command follow-up arrives as text.
  This is the user's decision, taken with the trade-off stated.
- A 180 s timeout means a genuinely lost response surfaces later. Back stays
  available throughout, and the placeholder row makes the wait visible
  elsewhere in the app.
- The launch, its bubble, its queued follow-ups and its row live in client
  memory until the session exists, so a process death during launch loses them,
  as with any unacknowledged send today.
- Queued follow-ups can pin substantial attachment memory for the duration of a
  create (**D11**). Accepted, matching the existing session queue.
- Steps 5 and 6 touch four different row widgets across two shells. That is the
  real cost of Q4, and it is why the row work is two PRs rather than one.
- Step 3 moves the create call out of `NewSessionCubit` into a service, and step 4
  moves follow-up delivery there too. That is the largest behavioural risk in the
  plan, because it touches the success, failure, restoration and analytics paths of
  the one flow that creates sessions, and it makes the service, not a screen,
  responsible for messages actually being sent. It is also what makes Q3 and Q4
  implementable at all. The mitigation is that the observable contract does not
  change: the same phases, the same restoration, the same selection cleanup, the
  same two analytics events with the same parameters, and the same failure log.
- The placeholder-to-real row swap depends on animated-list item identity, which
  is the one mechanism in this plan that could pass every state test and still
  visibly jump. It now rests on three things that have to hold together: the
  association being latched from `promote`'s emission, `SessionListContent` holding it while it
  draws a placeholder, and the row being held until that list would draw the
  session in the placeholder's slot so there is never an emission with neither
  row. Step 5's offset assertion is the gate, and a no-animation fallback for the
  swapping pair is named.
- The hold's one-update bound is a judgement, not a proof. If an unrelated update
  for the same project lands between `session.created` and the new session's
  first activity statement, the placeholder is released one update early and the
  row takes the short detour the hold exists to prevent — the pre-fix behaviour,
  in a narrower window. The alternative, holding until the session is seen
  running, would leave "Creating…" on screen indefinitely for a first command that
  never runs, which is worse. No activity-classification state is added to close
  the gap.
- Step 6 adds a height transition to two sections that animate nothing today
  (`project_list_view.dart`'s Activity `SliverList.list`, `desktop_home_pane.dart`'s
  `Column`). That is the smallest way to stop a row popping into content the user is
  reading, but it is new motion on two shared surfaces, so it is verified by
  recording rather than by a widget test alone.
- `QueuedMessageBubble` gains `sendingSince` on its sending presentation. It is
  optional and `null` reproduces today's behaviour exactly, so every existing
  caller is unaffected; the risk is limited to the three launch renderings that
  pass it.
