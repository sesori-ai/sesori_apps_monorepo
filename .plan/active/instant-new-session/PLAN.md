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
- **Delivery:** eight numbered PRs. Step 1 raises this plan.
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
  serialisation point), `completeSend`, `failSend` (re-heads), `holdFailedSend`,
  `retryFailedSend` (same promptId, so the bridge dedups), `cancel(index)`.
  It is **not** DI-registered; `SessionDetailCubit` owns the only instance
  (`session_detail_cubit.dart:136`). Step 4 reuses it rather than adding a
  second queue.
- `QueuedSessionSubmission` (`cubits/session_detail/queued_session_submission.dart`)
  is the queue's item type: `promptId`, `text`, `command`, `inputMode`,
  `attachments`, `agent`, `agentModel`, `fastMode`, plus `displayText` and
  `isCommand`.
- `SessionDetailCubit.sendMessage` already **enqueues without requiring
  `SessionDetailLoaded`** (`:1985-2042`); only `_drainQueuedMessages` requires
  loaded and connected. That is the existing precedent for "accept now, send
  later", and step 4 leans on it.
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
  cross-fade (`_withPageFade`, `desktop_router.dart:270`), which between
  identical content is not a visible navigation.
- **The first bubble is released by position, not by promptId.** The initial
  input is accepted before the session exists anywhere else. So in a
  brand-new session, the first user message with renderable content, or the
  first bridge-queued prompt (Claude or Pi command and queue windows), is by
  construction the submitted input. The bubble is dropped in the same emission
  that shows that replacement. Content matching is not used. Follow-ups do not
  participate: they match on their real promptId through the existing path.
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
  single gate: the harness, agent, model, variant and worktree mode stay
  locked, because they are already committed to the request in flight, while
  text, attachments and command entry become live. Follow-ups inherit the
  launch's committed selection, which is what the session would apply anyway.
- **The create timeout rises to 180 s.** Cold budgets exceed 30 s. With the
  message visible and the composer usable, a longer honest wait is better than
  a false uncertain failure. `postWithTimeout` gains a `sensitiveResponse`
  parameter so create-failure logs keep the diagnostic body. The existing
  attachment caller stays sensitive.
- **Analytics move with the operation, unchanged in shape.**
  `sessionCreatedWithMessage` and `sessionCreationFailed` stay exactly as they
  are, but they are reported by `SessionLaunchService` rather than
  `NewSessionCubit`, because the service is now the owner that always observes
  the authoritative outcome. This is a strict improvement: today both events
  are **lost** whenever the user leaves the new-session route before the bridge
  answers, since the cubit returns early once closed. No event, parameter or
  name changes. Queued follow-ups are ordinary prompt sends once the session
  exists and are reported by the existing session path, so they need no new
  event. Revisit only if the product asks how often follow-ups are typed during
  creation.

## The Launch Owner

Introduced in step 3 and extended by steps 4, 5 and 6. One file family in
`module_core`, following the `ComposerDraftStorage`/`ComposerDraftRepository`
template for the storage and repository, and the
`RecentSessionInventoryService`/`RecentSessionsCubit` template for the service
and its adapter.

- **`SessionLaunch` (Layer 0 model, `foundation/models/session_launch/`) is
  sealed, not one class with a nullable id:**
  - `PendingSessionLaunch({launchId, projectId, pluginId, submission, followUps})`
    — the bridge has not answered. **Only this variant produces a placeholder
    row.**
  - `CreatedSessionLaunch({launchId, projectId, pluginId, sessionId, submission, followUps})`
    — `sessionId` is non-null. **Only this variant can be consumed by
    `takeForSession`.**

  `launchId` is client-generated and is the stable row key. A flattened
  `String? sessionId` would make "a created launch still drawing a placeholder
  row next to its own real session row" a representable state, prevented only by
  some consumer happening to run in time. Sealing it makes the placeholder
  provably disappear the instant a session id exists.
- `SessionLaunchStorage` (Layer 1, `api/storage/`, `@lazySingleton`): the
  process-local map `Map<String, SessionLaunch>` keyed by `launchId`, mirroring
  `ComposerDraftStorage`'s shape exactly. It is the **sole writer** of the map.
  No persistence, no timers.
- `SessionLaunchRepository` (Layer 2, `@lazySingleton`): the **sole publisher**.
  `start`, `addFollowUp`, `cancelFollowUp`,
  `promote({required String launchId, required String sessionId})` (pending →
  created), `finish({required String launchId})`,
  `takeForSession({required String sessionId})` which returns and clears only on
  a matching `CreatedSessionLaunch`, plus a broadcast stream of the current
  `PendingSessionLaunch`es for the list surfaces. Follow-ups live here and
  nowhere else.
- `SessionLaunchService` (Layer 3, `services/`, `@lazySingleton`): owns the
  **operation**, which is the reason this family exists at all. One method,
  `launch(...)`, which starts the launch in the repository, awaits
  `SessionRepository.createSessionWithMessage`, then `promote`s on success or
  `finish`es with the reason on failure, and reports
  `sessionCreatedWithMessage` / `sessionCreationFailed`. Because the service is
  a singleton, that sequence completes whether or not the composing route still
  exists. It has two collaborators (`SessionRepository`,
  `SessionLaunchRepository`) plus analytics, so it is a real service and not a
  pass-through.
- `SessionLaunchCubit` (Layer 4, `module_core/lib/src/cubits/session_launch/`):
  the thin adapter the list widgets watch, exactly as `RecentSessionsCubit`
  adapts `RecentSessionInventoryService`. Provided above the router on phone
  (`app/lib/main.dart:392-398`, beside `PendingSessionArchiveCubit`) and inside
  `DesktopCockpitCubitProvider` on desktop
  (`desktop_cockpit_shell.dart:32-52`), and re-provided by value in the sidebar
  rail popout's `MultiBlocProvider` (`desktop_sidebar.dart:472-477`), which
  renders on the root navigator.

`NewSessionCubit` therefore stops owning the create response. It calls
`SessionLaunchService.launch(...)`, keeps the `launchId` in its sending phase,
and renders the launch's submission and follow-ups from the launch owner. Its
existing `if (isClosed) return;` early exit becomes harmless, because nothing
important happens after it any more.

Launches are keyed, not a single slot. A single slot was enough while the
handoff was invisible, but a visible placeholder row makes overwriting wrong:
starting a second session (trivially easy on desktop, where the home composer
and a project composer both exist) would silently erase the first row. The map
is bounded by the number of creations actually in flight, and because the
service always reaches `promote` or `finish`, every entry is removed — which is
what makes that bound real rather than aspirational, and what keeps attachment
bytes from outliving the launch.

**Invariant, enforced by construction rather than left as a decision:** a
placeholder row and its real session row never coexist, because the list stream
carries only `PendingSessionLaunch`es and `promote` is the single transition out
of that variant.

**One source of truth for the harness name.** The launch stores `pluginId` only.
Both presentation seams that need a display name derive it the same way, through
`PregoBrandLogo.displayNameFor(pluginId)`: the sending bubble and the
placeholder row's meta line. The launch does not also store a display string.

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
- `new_session_submission_snapshot.dart` (and its freezed part) moves from
  `cubits/new_session/` to `foundation/models/composer/`, with its importers
  updated in lockstep. It happens here, in the low-risk PR that already touches
  the type, rather than inside step 3, so step 3's diff is behaviour only. A
  Layer 2 repository holds this type from step 3 onwards, so the move is
  required either way. `QueuedSessionSubmission` is not touched.
- Relay create timeout: both create paths in `SessionApi` use
  `postWithTimeout(timeout: 180 s, sensitiveResponse: false)`.
  `postWithTimeout` gains a required `sensitiveResponse`, and the existing
  caller passes `true`.
- Cleanup: the sending-branch `PregoLaunchStatus` usage and its widget-test
  expectations go. `newSessionLoadingMessage1..3` stay, because the ordinary
  session-detail load still uses them.
- Tests: the first sending frame shows the bubble with the text, command, and
  attachments. Failure restores the composer exactly as today. The chrome
  (desktop) and glass (phone) variants are covered. The timeout applies on the
  plain and attachment create paths.
- **Feel check:** the bubble is bottom-anchored in the same place the session
  screen puts it, so step 3's replacement moves nothing.

### Step 3: First-message handoff to the session screen (module_core, module_app_ui, app, desktop)

- Introduce the whole launch owner family — sealed `SessionLaunch`,
  `SessionLaunchStorage`, `SessionLaunchRepository` and `SessionLaunchService` —
  as described in "The Launch Owner". `SessionLaunchCubit` and the list-facing
  stream arrive in step 5 with their first reader; the repository's stream is
  defined here because the service already publishes to it.
- `NewSessionCubit` gains a constructor dependency on `SessionLaunchService`,
  wired in `cubit_composition.dart:92-104`. `createSession` stops awaiting the
  repository itself: it mints a `launchId`, calls
  `SessionLaunchService.launch(...)`, and emits
  `NewSessionPhase.sending(launchId: …)`. It then watches the launch owner for
  the outcome and emits `NewSessionState.created(session: …)` when the launch is
  promoted, or the existing `restoringSubmission` phase when it fails. Failure
  restoration, `_restoreStagedCommand` and
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
  `takeForSession(sessionId: …)` before its initial state:
  - `SessionDetailState.loading` gains
    `required NewSessionSubmissionSnapshot? launchSubmission` and
    `required String? launchPluginId`, and every loading emission of
    `_loadMessages` carries them through. Step 4 adds the follow-ups beside
    them, so the loading state is the one place that describes a taken launch.
  - `SessionDetailLoaded` gains the same fields. `SessionDetailFailed` does not:
    a failed first load loses the bubble and Retry loads normally (low damage,
    accepted).
  - **The release rule has exactly one owner.** A pure predicate beside
    `hasRenderableUserContent` in `session_detail_resolvers.dart` answers
    "does this state now show the launch's replacement?" — true when a user
    message with `hasRenderableUserContent` is present, or `bridgeQueuedPrompts`
    is non-empty. A single private `_emitLoaded(SessionDetailLoaded)` funnel
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
    through `buildSessionPaneTransitionPage` (`app_router.dart:142`). The call
    site switches to a new typed `replaceRouteInstantly(AppRoute)` extension
    beside `replaceRoute`. It passes a shell-private marker as go_router
    `extra`, and `buildSessionPaneTransitionPage` uses `Duration.zero` when
    that marker is present.
  - **Desktop** (`desktop_router.dart:176` new-session route,
    `desktop_session_list_screen.dart:198` → `desktop_router.dart:132`
    project-page composer, `desktop_home_pane.dart:242` → `desktop_router.dart`
    `onOpenSession` home composer): all three go through the main-pane
    `_PageFade` (150 ms cross-fade, zero under reduced motion). They stay
    unchanged, because a short cross-fade between identical content reads as
    continuity. Step 8 verifies this visually. Only an observed visible jump
    would add the same instant replacement there.
- Tests:
  - Launch match and consume, and no consume for a different session id or for
    a still-pending launch.
  - A launch started and then abandoned (the cubit closed before the response)
    still reaches `promote` or `finish`, still reports its analytics outcome,
    and leaves no entry behind.
  - Loading carries the bubble and the plugin id, and the load path's emissions
    preserve them.
  - Release on a snapshot, message, part, or queued prompt, each in one
    emission, exercised through `_emitLoaded` so a new emission site cannot
    bypass it.
  - No "No messages yet" while the bubble is pending.
  - Ordinary opens are unchanged (no launch for that session id).
  - Widget continuity across the replacement, including the harness name.
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
  into cubit state. `NewSessionPhaseSending` already carries only the
  `launchId` (step 3), and `NewSessionCubit` exposes the follow-ups it reads
  from the launch owner's stream. `queueFollowUp({required ComposerDraft draft, required String? command, required List<ComposerAttachment> attachments})`
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
- **View.** Both sending branches keep the composer mounted in the same
  `Column` slot they use when idle, so `PromptInput` is never disposed and
  keeps its staged attachments, its text and its focus:
  - Glass/phone (`:492-544`): the sending branch becomes the same
    `Column[Expanded(pane), composer]` as the idle branch, with the pane being
    `SessionLaunchSubmissionView` instead of the options scroll.
  - Chrome/desktop (`:274-295`): the sending branch becomes
    `Column[Expanded(SessionLaunchSubmissionView), composer]`. The composer
    therefore moves from the centred column to the bottom edge at Send. See
    open decision **D8**.
  - `canSend` changes from `cubit.canCreateSession && !isSending` (`:416`) to
    `cubit.canCreateSession || cubit.canSubmitFollowUp`, and `onSend` routes
    to `createSession` or `queueFollowUp` on the same condition.
  - `SessionLaunchSubmissionView` gains
    `required List<QueuedSessionSubmission> followUps` and renders each below
    the first bubble as `QueuedMessageBubble` with
    `pending(onCancel: …)`, in order, reusing
    `_kPromptRowPrefix`-style keys so they keep identity into the session
    screen.
- **Drain.** `SessionDetailCubit`'s `takeForSession` already returns the whole
  `CreatedSessionLaunch`; it now also reads `followUps` and calls
  `_promptQueue.enqueue` for each, in order, before its first drain. From that
  point every existing behaviour applies unchanged: FIFO through `beginSend`,
  promptId dedup, `holdFailedSend`/`retryFailedSend`, cancellation by index,
  and `QueuedMessageBubble` rendering through `queuedMessages`. **No second
  queue is created.**
- **The follow-up bubbles must survive the load, not just the swap.**
  `SessionDetailLoading` gains
  `required List<QueuedSessionSubmission> launchFollowUps` beside step 3's
  `launchSubmission` and `launchPluginId`, and the loading branch renders them
  below the first bubble. Without this they would vanish from the route
  replacement until the detail load completes — a window this plan measured at
  up to about 2.5 s on Pi and Hermes, plus relay tiers — because
  `_emitQueueUpdate` only publishes the queue in loaded states. The first
  message and its follow-ups are therefore handled symmetrically in every
  state.
- **Failure.** Q2 restores the first submission into the composer exactly as
  today. What happens to the follow-ups is open decision **D1**.
- Tests: `queueFollowUp` appends in order and mints distinct promptIds;
  command-plus-attachments is refused; option pickers stay locked while
  sending; the composer keeps staged attachments across the idle→sending
  switch; the drain enqueues follow-ups in order and the existing queue sends
  them in order; cancelling a follow-up before creation completes removes it.
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
  `session_tile.dart:523-528`, so the swap changes no height. Its content is
  open decision **D2**; its interactivity is open decision **D3**.
- `SessionListContent` / `SessionListFilteredContent` gain
  `required List<PendingSessionLaunch> pendingLaunches` and insert those rows at
  the head of the **Today** heading, above running sessions, in
  `_sessionListRows` (`session_list_content.dart:64-89`) — the same place the
  heading rows are already synthesised. Their relationship to the quick-filter
  counts and the search field is open decision **D4**.
- **The empty state must count launches.**
  `session_list_content.dart:212`'s `if (loaded.sessions.isEmpty)` renders
  `SessionEmptyState` / `archivedEmptyState`. Because launches never enter
  `sessions`, leaving that condition alone would draw the placeholder row **and**
  the "no sessions yet" empty state together for the first session of a project
  — the single most common instant-new-session path — and the empty state would
  then vanish when the real row lands, moving the list and breaking feel
  property 3. The condition becomes "no sessions **and** no pending launches".
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

  The mechanism: `CreatedSessionLaunch` carries both `launchId` and `sessionId`,
  so the launch owner knows the association. While a launch entry exists, the
  list resolves that session's row key **through the launch**, so the
  placeholder and the real row are one item whose content changed and whose
  height is unchanged (**D2** fixes the geometry). The entry is removed by
  `finish` on failure, or after `promote` once the real session is present in
  `sessions`, so the key only reverts to `ValueKey(session.id)` in a frame where
  the row already renders the real session and nothing visible changes.

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
- Tests: a launch adds exactly one row at the top of Today; the placeholder and
  the real row never both appear, which the sealed variants make structural; its
  removal on failure leaves the list as it was; a project whose only item is a
  launch shows the row and **not** the empty state; archived lists never show
  it; the row's height equals `SessionTile`'s at standard and accessibility
  text.
- **Feel check:** the swap test asserts the y offset of the row below the
  placeholder is identical before and after, which is the mechanical proof of
  property 3.

### Step 6: The pending-launch row in the sidebar and Activity rows (Q4, part 2) (module_app_ui, desktop)

The remaining row surfaces use two other widgets, so they are a separate PR.

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
- **Activity rows** (`ActivityTile`, used by the phone project list
  `project_list_view.dart:436` and the desktop home pane
  `desktop_home_pane.dart:297`): a matching pending variant in `ActivityTile`
  geometry.
- **Phone home and desktop home.** `SessionActivityProjection` is **unchanged**.
  A launch cannot become a `SessionActivityEntry`, because that type requires a
  real `Session` and this plan does not synthesise one. Instead the launches
  reach the Activity hosts the same way they reach every other surface: as a
  separate pending list passed beside the projection's groups, rendered above
  them by the pending `ActivityTile` variant, in `project_list_view.dart:436`
  and `desktop_home_pane.dart:297`.

  No membership rule changes, and the earlier draft's justification for changing
  one was wrong: `inMotion = isRunning || ((isAwaitingInput || isUnseen) && !isSetAside)`
  (`session_activity_projection.dart:81`), and a freshly created session is both
  running and unseen, so the **real** row already enters Activity as soon as the
  first status event lands. Only the pre-bridge window needs the placeholder.
- The desktop command palette (`desktop_command_palette.dart:48-55`) reads a
  snapshot at open time and lists real sessions only. Launches are **not**
  added there: a row you cannot open is not a useful palette entry.
- Tests: each of the three row widgets renders a launch above its real rows;
  the sidebar never treats a launch as selected, sticky or menu-bearing; the
  phone home shows the launch and drops it on completion;
  `SessionActivityProjection`'s existing tests are untouched, which is the proof
  that the projection did not change.

### Step 7: Reconcile regression coverage

Update the affected documents and complete the cleanup audit (below).

### Step 8: Run coverage and retire

Run the level and matrix recorded here, record the result in `TRACKER.md`, and
move the plan to `.plan/completed/`.

### Complexity budget

New mutable parts: **one** — the `SessionLaunchStorage` map of launches, with
its repository as sole publisher, its service as sole driver of the operation,
and its cubit adapter. Everything else is immutable: sealed `SessionLaunch`
values, and `launchSubmission` / `launchPluginId` / `launchFollowUps` on the
detail loading and loaded states.

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

Explicitly **not** added: a second send queue (step 4 reuses `PromptSendQueue`),
a second copy of the follow-up list, a `submission` field on
`NewSessionCreated`, a promptId for the first message, a synthetic `Session`, a
`String? sessionId` on one flattened launch class, a pending session id or wire
change, a launch progress protocol, creation cancel, automatic resend,
echo-correlation state, a bubble timeout, persistence or timers of any kind, a
byte cap on the launch queue (see **D11**), and retaining the launch through a
failed first load. Stop and ask if implementation seems to need any of them.

## Open Decisions (for the next review page)

Each has a recommended default. None is settled.

### D1. Queued follow-ups when creation fails

**Recommended: keep them queued and visible as cancellable pending bubbles.**
The first submission is restored into the composer exactly as Q2 asks, the
error banner and duplicate-risk warning appear as today, and the follow-ups
stay on screen above the composer as `pending(onCancel:)` bubbles. Pressing
Send again starts a new launch that carries them, in order, behind the first
message. Nothing is lost and nothing is merged.

The user's suggested default — append the extras into the same composer draft
below the first message, separated by blank lines — **loses data**, which is
why I do not recommend it: an extra message can carry attachments, and text
concatenation has nowhere to put them, so images typed into follow-ups would
be silently dropped. It also merges turns the user deliberately separated,
and a follow-up that was a slash command cannot be appended to a text draft at
all.

Dropping them is worse still and should not be considered.

Cost of the recommendation: the failed launch keeps its `followUps` while the
route is current, which is strictly **less** work than converting them to
text, because step 4 already renders exactly these bubbles. They are discarded
when the user leaves the route, as an abandoned draft is today.

### D2. What the placeholder row shows

**Recommended: the same row shape as a real session row, with the first line
of the prompt as the title, the running sparkle in the status slot, the harness
name on the meta line, and no time.**

- **Title** — the first line of `submission.displayText`, or `/command` for a
  command start, or the localised attachment-only fallback. Real rows show
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

**Recommended: no. It is inert — no tap, no menu, no swipe actions.** There is
no session to open, and `sessionMenuEntries` requires a real `Session`.
Alternative worth weighing: tapping returns to the new-session route so the
user can watch the bubble and keep typing. That is genuinely nicer, but the
route may no longer exist, so it needs a re-created route seeded from the
launch — real work for a rare tap. I would ship it inert and add the tap later
only if the row's inertness actually annoys.

### D4. The placeholder, the quick-filter chips and search

`docs/regression/projects-and-sessions.md` says the All/Running/Unread chips
carry "exact counts from the loaded list", and the phone search field "narrows
the loaded titles without a request".

**Recommended: the placeholder is excluded from all three chip counts, and is
hidden while a search query is active or the archived filter is on.** It is not
a loaded session, so counting it would make the chips disagree with the list
they describe; and a row that ignores the user's search would read as a bug.
Alternative: count it under Running and match it against the query by its
prompt text. That is defensible but adds the launch to three count paths and a
filter path for a row that lives for a few seconds.

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

**Only the product half of this is an open question.** The architectural half is
already settled in the plan and is not up for review: the observer of a late
outcome is `SessionLaunchService`, not the closed `NewSessionCubit`. Without
that, neither option below could be implemented, because nothing would be alive
to notice.

**Recommended: remove the row and show one popup alert naming the project**,
through the existing `popupAlertPresenter`, with one new localised string. A row
that appears and then silently vanishes is the kind of unexplained change the
feel rules forbid. Alternative: stay silent and just remove the row — cheaper,
and arguably fine because the user chose to leave.

### D6. More than one launch at a time

**Recommended: support several concurrent launches, each with its own row.**
Desktop makes this easy to reach (the home composer and a project composer are
separate surfaces), and the cost is a map instead of a field. The alternative,
a single slot, would make the second launch erase the first's row and queue.
The map is bounded by real in-flight creations and is emptied by success or
failure.

### D7. Mobile voice resources during creation

Unmounting the composer at Send is today how mobile voice resources get
released during launch — the comment at `new_session_view.dart:550-556` says
so explicitly. Keeping the composer mounted (Q3) keeps the voice cubit alive
through creation.

**Recommended: accept it.** The composer being usable is the point of Q3, and
the resources are released when the route is replaced or the user leaves, which
is within seconds. Alternative: keep voice specifically disabled while sending
— but then the user can type a follow-up and not dictate one, which is a
confusing partial capability.

### D8. The desktop composer moves at Send

On desktop the idle composer sits inline in a centred, scrolling column
(`new_session_view.dart:274-295`), while a session screen's composer is
bottom-anchored. With Q3 keeping it mounted, it must move from the centre to
the bottom at Send.

**Recommended: accept the move and animate it once**, as the transition that
explains "this is now a session", using the standard 240 ms and
`Duration.zero` under reduced motion. The move is unavoidable — the composer
has to end up at the bottom — so the only question is whether it happens
visibly at Send or invisibly during the later route replacement. Doing it at
Send, animated, is the honest version. Phone is unaffected: its composer is
already bottom-anchored in both branches.

### D9. Options stay locked while creating

**Recommended: yes, locked** — harness, agent, model, variant and worktree
mode cannot change once Send commits them to the request in flight, and
follow-ups inherit them. Only text, attachments and command entry are live.
This also keeps the existing behaviour where an options refresh arriving
mid-send is dropped. The alternative, letting the user change the model for the
queued follow-ups only, would mean the page shows one selection while two
different ones are in flight.

### D10. Follow-ups do not use the positional release

**Recommended: only the first message is released by position**; follow-ups
carry real promptIds and settle through the existing promptId matching in
`SessionDetailMessageList`. Stated here because it is easy to get wrong during
implementation: applying the positional rule to follow-ups would drop the
wrong bubble.

### D11. Queued attachment bytes are not capped

`ComposerAttachment` holds decoded bytes with a 50 MB cap **per prompt**
(`composer_attachment.dart:10`), and the existing `PromptSendQueue` puts no
ceiling on the total across queued items. N follow-ups can therefore pin N ×
up to 50 MB while creation runs.

**Recommended: add no cap**, matching the existing session queue exactly.
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
  `promote` or `finish` either way. The placeholder row stays in the lists until
  it does, the queued follow-ups still drain when the session screen is opened
  later, and the analytics outcome is still reported — none of which is true
  today. The existing alert still fires. Failure handling is **D5**.
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
- **A follow-up fails after the session exists:** it is an ordinary queued send
  by then, so the existing `holdFailedSend` / retry / remove surfaces own it.

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
| 1/8 | `🌿 [instant-new-session] Plan opening new sessions instantly [step 1/8]` | This plan and `TRACKER.md`; remove the superseded `instant-session-launch` plan. | docs only |
| 2/8 | `⚙️ [instant-new-session] Show the first message while a new session is created [step 2/8]` | Step 2 design: session-shaped creating view on every surface, `displayText`, the submission-model relocation, 180 s create timeout, tests. | 500–700 |
| 3/8 | `🚧 [instant-new-session] Hand the first message off to the session screen [step 3/8]` | Step 3 design: the launch owner family including `SessionLaunchService`, `NewSessionCubit` handing creation over, detail state, the single release funnel, detail presentation, transition-free phone swap, tests. | 850–1,150 |
| 4/8 | `🚧 [instant-new-session] Keep the composer live and queue follow-up messages [step 4/8]` | Step 4 design: gate split, follow-ups owned by the launch, shared `generatePromptId`, composer mounted in both sending branches, follow-ups carried through the detail load, drain into `PromptSendQueue`, tests. | 700–950 |
| 5/8 | `⚙️ [instant-new-session] Show a launching row in the session lists [step 5/8]` | Step 5 design: launch stream and cubit, shell providers, `PendingSessionLaunchTile`, the three `SessionTile` hosts, tests. | 550–750 |
| 6/8 | `⚙️ [instant-new-session] Show a launching row in the sidebar and Activity [step 6/8]` | Step 6 design: two sidebar rows, pending `ActivityTile` variant, rail popout provider, the phone and desktop home hosts, tests. | 450–650 |
| 7/8 | `🌱 [instant-new-session] Reconcile new-session regression coverage [step 7/8]` | Update the affected regression documents and complete the cleanup audit. | 150–300 |
| 8/8 | `🌿 [instant-new-session] Run new-session coverage and retire the plan [step 8/8]` | Run the matrix below, record it in `TRACKER.md`, and move the plan to `.plan/completed/`. | docs only |

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

Every step is comfortably inside the ~1,500-line soft cap, and steps 3 and 4
are deliberately held near 1,000 because they carry the cross-layer and
state-machine risk.

**Pre-approved split if step 3 runs long.** Step 3 is the largest step and now
carries the launch-owner family as well as the detail-side handoff. If the real
diff passes about 1,150 lines, split it into `3.a` (the launch owner family plus
`NewSessionCubit` handing creation over to the service, with the new-session
surface as its first reader) and `3.b` (the detail-side handoff: state fields,
the release funnel, presentation, and the phone transition), renumber the series
to nine steps, and update this table and `TRACKER.md`. A clean split of already
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

- `docs/regression/session-creation-and-options.md` (primary). Three existing
  rules change materially:
  - "Send immediately replaces the composer with detail-shaped launch status
    while the unresolved URI remains `/projects/<projectId>/sessions/new`.
    Duplicate Send is blocked." — Send now shows the sending bubble and
    **keeps** the composer; a second Send queues a follow-up instead of being
    blocked, while a second *creation* is still blocked.
  - "A creation failure on the still-current route restores the exact submitted
    text/voice spans, command intent, and memory-only attachment identities
    once …" — extended by whatever **D1** settles.
  - The L3 row's "Send immediately renders launch status at the unresolved
    route, blocks duplicate submit, and replaces with the durable session"
    becomes the sending bubble, the launch handoff, the positional release, the
    follow-up queue and the 180 s timeout.
- `docs/regression/projects-and-sessions.md`: the launching row, where it
  appears, that it leads Today, that it is not selectable or actionable, that a
  project whose only item is a launch shows the row rather than the empty state,
  that it never coexists with its own real row, and its relationship to the
  chips and search (**D4**).
- `docs/regression/session-turns.md`: the launch row in the transient-row
  ordering, and that follow-ups queued before a session id exists drain through
  the ordinary local queue.
- `docs/regression/navigation-transitions.md`: the transition-free
  created-session replacement. Its existing rule already requires the
  new-session page to change in place without a fade when its first prompt
  turns it into the session, so this is a confirmation rather than a new claim.
- `docs/regression/desktop-cockpit-shell.md`: the sidebar's launching row.
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
  in order after the session exists, and confirm one can be cancelled before
  it does.
- **Failure:** definitive rejection, and response loss or timeout, restore the
  exact draft with the warning and remove the placeholder row. Also cover Back
  mid-creation, and failure after leaving the route (**D5**).
- **Acceptance is structural:** the bubble appears in the first sending frame;
  no frame between Send and the echo lacks the message or shows a spinner or
  "No messages yet"; the bubble's rect and its harness name are unchanged across
  the route replacement; and the row below the placeholder does not move when the
  real row replaces it.
- **Abandoned launches:** start a create on a cold harness, leave the route
  immediately, and confirm the row still resolves, the follow-ups still send
  when the session is opened, and the analytics outcome is still reported.

## Risks And Accepted Limits

- Cold starts stay as slow as they are. This plan changes only what the user
  sees and can do while waiting. Q5 defers the real fix.
- The positional release could drop the first bubble early if a different user
  message echoed first. No current plugin can do that before the initial
  dispatch, and the outcome self-corrects.
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
- Step 3 moves the create call out of `NewSessionCubit` into a service. That is
  the largest behavioural risk in the plan, because it touches the success,
  failure, restoration and analytics paths of the one flow that creates
  sessions. It is also what makes Q3 and Q4 implementable at all. The mitigation
  is that the observable contract does not change: the same phases, the same
  restoration, the same two analytics events with the same parameters.
- The placeholder-to-real row swap depends on animated-list item identity, which
  is the one mechanism in this plan that could pass every state test and still
  visibly jump. Step 5's offset assertion is the gate, and a fallback is named.
