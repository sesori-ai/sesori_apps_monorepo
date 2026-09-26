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
- **Delivery:** five numbered PRs. Step 1 raises this plan.
- **Architecture review (2026-09-26):** rejected with three findings, all
  applied directly:
  - The shell routing no longer reads a repository; the transition is decided
    per `onSessionCreated` call site, and each desktop route is named.
  - One launch type (`NewSessionSubmissionSnapshot`) and one shared widget
    (`SessionLaunchSubmissionView`) replace the two mappings. Both cubits'
    new dependencies are stated.
  - The handoff no longer uses `QueuedSessionSubmission`, whose queue-only
    variant and wire promptId cannot apply to a launch.

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

The real creation time does not change in phase 1, but the user no longer
waits on it before seeing the session.

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
| 1 | `NewSessionCubit.createSession` (`new_session_cubit.dart:867`) | Nothing. It emits `NewSessionPhase.sending` synchronously. | The composer unmounts and a centered `PregoLaunchStatus` with rotating copy appears (`new_session_view.dart:274`, `:492`). |
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
transcript before seeing their own message.

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

- `NewSessionSubmissionSnapshot` already captures the submitted text, voice
  spans, command, and attachments losslessly (for failure restoration).
- `QueuedMessageBubble` with `QueuedMessageBubblePresentation.sending` is the
  existing "sending" look (`session_detail/widgets/queued_message_bubble.dart`).
  After 2 s it switches to naming the harness it is waiting on.
  `new_session_view.dart` already imports `session_detail` widgets, so reusing
  it adds no new cross-feature dependency.
- `SessionDetailMessageList` already renders transient submission rows keyed by
  local promptId (`session_detail_message_list.dart:515`, `:607`).
- `hasRenderableUserContent` (`session_detail_resolvers.dart:6`) already decides
  whether a user message shows anything.
- The existing-session queue (`PromptSendQueue`, promptId dedup) needs a session
  id and a wire promptId. The first prompt has neither, and no plugin stamps a
  promptId on the initial echo. So the queue cannot own the first prompt, and
  this plan does not force it to.

## Design Decisions

- **Client only in phase 1. No wire, bridge, or plugin change.** There is no
  pending session id and no bridge-issued placeholder. The bridge already owns
  session ids, but returning one before the plugin binding commits would add a
  "creating" session state to every session route. That would be the largest
  possible change for a perception problem.
- **The perceived navigation is presentation.** While sending, `NewSessionView`
  renders a session-shaped body in place, with no route change, so it is
  instant and cannot race. On success, the route is replaced by the real
  session screen, which is pre-seeded with the same bubble. The phone
  replacement runs without a page transition. Desktop keeps its existing
  150 ms main-pane cross-fade (`_withPageFade`, `desktop_router.dart:270`),
  which between identical content is not a visible navigation.
- **One launch type, no mappings.** `NewSessionSubmissionSnapshot` (sealed
  `text({draft, attachments})` / `command({draft, command})`) already is
  exactly the launch input: it has no queue-only variant and no wire promptId.
  The creating view, the handoff, and the detail state all use it directly.
  It gains one `displayText` getter in `module_core`, so no view derives text.
  The launch row needs no id: a session has at most one, so the message list
  keys it with a constant row id and never matches it against echoes.
- **The handoff uses a single in-memory slot, not route arguments.** It is
  written in `NewSessionView`'s created listener immediately before
  `onSessionCreated`, and consumed by `SessionDetailCubit` for the matching
  session id. This covers all four surfaces without threading a new value
  through phone and desktop routers and callbacks. It holds no persistence,
  timers, or map. The next launch overwrites it and consumption clears it.
- **The bubble is released by position, not by promptId.** The initial input
  is accepted before the session exists anywhere else. So in a brand-new
  session, the first user message with renderable content, or the first
  bridge-queued prompt (Claude or Pi command and queue windows), is by
  construction the submitted input. The bubble is dropped in the same emission
  that shows that replacement. Content matching is not used.
- **Failure UX is unchanged.** Creation failure on the current route restores
  the exact draft, attachments, and command with the error and duplicate-risk
  warning. The session-shaped body simply gives way to the restored composer.
  Back during creation keeps it running in the background, with the existing
  "launching in background" alert.
- **The create timeout rises to 180 s.** Cold budgets exceed 30 s. With the
  message visible, a longer honest wait is better than a false uncertain
  failure. `postWithTimeout` gains a `sensitiveResponse` parameter so
  create-failure logs keep the diagnostic body. The existing attachment caller
  stays sensitive.
- **No analytics change.** `sessionCreatedWithMessage` and
  `sessionCreationFailed` already report the authoritative outcome in
  `NewSessionCubit`, which is unchanged.

## Design

### Step 2: Session-shaped creating view (module_app_ui, plus the create timeout in module_core)

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
  scaffold (phone) and the chrome page (desktop). It is fed by the existing
  `NewSessionPhaseSending.submission` and the selected plugin's display name.
  The top bar keeps the new-session title and project. The composer stays
  unmounted, as today, so the existing failure-restoration path is untouched.
- `NewSessionSubmissionSnapshot` gains `String? get displayText`: `/cmd args`
  for a command, the text for a prompt, or null when there are only
  attachments. This mirrors `QueuedSessionSubmission.displayText`.
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

### Step 3: First-message handoff to the session screen (module_core, module_app_ui, app, desktop)

- `new_session_submission_snapshot.dart` (and its freezed part) moves from
  `cubits/new_session/` to `foundation/models/composer/`, because a Layer 2
  repository now holds it. Its importers update in lockstep.
  `QueuedSessionSubmission` is not touched.
- `SessionLaunchHandoffStorage` (Layer 1, `api/storage/`, the same pattern as
  `ComposerDraftStorage`) owns one slot
  `({String sessionId, NewSessionSubmissionSnapshot submission})?`.
  `SessionLaunchHandoffRepository` (Layer 2, `@lazySingleton`, the same
  pattern as `ComposerDraftRepository`) exposes `stash` and
  `take({required String sessionId})`, which returns and clears only on a
  match.
- `NewSessionState.created` gains
  `required NewSessionSubmissionSnapshot submission`. `NewSessionCubit` gains
  a constructor dependency on `SessionLaunchHandoffRepository`, wired in
  `cubit_composition.dart`, and a `stashLaunchHandoff()` method that stashes
  the created state's session id and submission. The created listener in
  `NewSessionView` passes the existing "route still current" guard, then calls
  `stashLaunchHandoff()`, then `onSessionCreated`. A skipped navigation
  stashes nothing, so attachment bytes never outlive the route.
- `SessionDetailCubit` gains a constructor dependency on
  `SessionLaunchHandoffRepository`, wired in `createSessionDetailCubit`, and
  takes the handoff before its initial state:
  - `SessionDetailState.loading` gains
    `required NewSessionSubmissionSnapshot? launchSubmission`, and every
    loading emission of `_loadMessages` carries it through.
  - `SessionDetailLoaded` gains the same field. It is cleared in the emission
    that first contains a user message with `hasRenderableUserContent`, or a
    non-empty `bridgeQueuedPrompts`. That applies in `_buildLoadedState`,
    `_onMessageUpdated`, `_onPartUpdated`, and the silent-refresh
    reconciliation. `SessionDetailFailed` does not carry it. A failed first
    load loses the bubble and Retry loads normally (low damage, accepted).
  - A local stop or abort of the session clears it.
- Presentation:
  - When `launchSubmission` is set, the `SessionDetailBody` loading branch
    renders `SessionLaunchSubmissionView` with `harnessName: null`. The
    plugin is not known before metadata loads, and the loaded message-list row
    already receives the harness name.
  - `SessionDetailMessageList` renders it as the oldest transient row, under
    one constant row id, as a `QueuedMessageBubble` with the `sending`
    presentation.
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
    continuity. Step 5 verifies this visually. Only an observed visible jump
    would add the same instant replacement there.
- Tests:
  - Handoff match and consume, and no stash on a skipped navigation.
  - Loading carries the bubble, and the load path's emissions preserve it.
  - Release on a snapshot, message, part, or queued prompt, each in one
    emission.
  - No "No messages yet" while the bubble is pending.
  - Ordinary opens are unchanged (null handoff).
  - Widget continuity across the replacement.

### Complexity budget

New mutable parts: **one** in-memory handoff slot. The feature cannot render
the message on the detail route before the bridge lists it without that slot,
and it is overwritten or cleared on every launch. State fields are immutable
snapshots: `submission` on `NewSessionCreated` and `launchSubmission` on the
detail loading and loaded states.

These are deliberately **not** added: pending session ids, a sidebar or recent
"creating" row, a launch registry, typing or queueing follow-ups before an id
exists, creation cancel, automatic resend, echo-correlation state, a bubble
timeout, and retaining the handoff through a failed load. Stop and ask if
implementation seems to need any of them.

## Edge Cases

- **Duplicate submit:** Send is disabled while sending, as today (`canSend`
  excludes sending).
- **Idempotency:** creation remains non-idempotent, and the duplicate-risk
  warning on uncertain failure stays. See the later phase.
- **Navigating away mid-creation:** unchanged. Creation continues, the alert
  fires, and nothing is stashed. The session appears in lists and the sidebar
  through the existing `session.created` flow when the bridge commits.
- **Navigating back to New Session:** a fresh cubit and composer. The
  in-flight creation is unaffected.
- **Deep links and restoration:** the handoff is optional. A detail route
  opened any other way has no handoff and loads as today.
- **Desktop multi-pane:** the embedded project-page and home composers use the
  same view. `desktop_session_list_screen.dart`'s `_creating` flag keeps the
  composer pane visible through creation, as today.
- **Older bridges:** no wire change, so there is nothing to negotiate. The
  release rule is client-side and bridge-version-independent.
- **Harness never echoes (turn fails before echo):** the bubble stays as
  sending until a refresh delivers the echo. The existing session status and
  error surfaces report the failure. Accepted.

## Later Phase (rough, not planned in detail)

- **Honest progress** (from the superseded plan): a client `launchId` on
  `CreateSessionRequest` plus a bridge `session.create.progress` event with
  `startingPlugin`, `preparingWorkspace`, and `creatingSession`, shown as an
  inline stage line under the bubble. This is wire plus bridge work. It is
  worth doing only if cold waits still feel opaque with the bubble in place.
- **Shorter real creation:** pre-warm the selected plugin when the new-session
  screen opens (OpenCode cold is 16.6 s and Hermes 5.8 s). Overlap the base
  branch fetch with plugin start (this needs worktree cleanup when plugin start
  fails).
- **Idempotent creation** keyed by a client id, so a retry after response
  loss cannot duplicate a session and the warning can go.

## Delivery Plan

| Step | Exact PR title | Scope |
|---|---|---|
| 1/5 | `🌿 [instant-new-session] Plan opening new sessions instantly [step 1/5]` | This plan and `TRACKER.md`; remove the superseded `instant-session-launch` plan. |
| 2/5 | `⚙️ [instant-new-session] Show the first message while a new session is created [step 2/5]` | Step 2 design: session-shaped creating view on every surface, 180 s create timeout, tests. About 400 to 600 lines. |
| 3/5 | `🚧 [instant-new-session] Hand the first message off to the session screen [step 3/5]` | Step 3 design: model relocation, handoff storage and repository, detail state and release rule, detail presentation, transition-free swap, tests. About 800 to 1,100 lines. |
| 4/5 | `🌱 [instant-new-session] Reconcile new-session regression coverage [step 4/5]` | Update the affected regression documents and complete the cleanup audit. |
| 5/5 | `🌿 [instant-new-session] Run new-session coverage and retire the plan [step 5/5]` | Run the matrix below, record it in `TRACKER.md`, and move the plan to `.plan/completed/`. |

Each implementation step is independently valid. Step 2 alone removes the first
spinner, and step 3 removes the second spinner and the empty gap.

## Verification

- **Step 2:** `module_app_ui` widget tests plus
  `dart analyze --fatal-infos`; `module_core` API tests.
- **Step 3:** `module_core` cubit, state, and repository tests;
  `module_app_ui`, `app`, and `desktop` widget and routing tests; analyze each
  touched package with `--fatal-infos`.

### Regression documents

- `docs/regression/session-creation-and-options.md` (primary). The rule "Send
  immediately replaces the composer with detail-shaped launch status" and its
  L3 row become the sending bubble, the handoff, the release rule, and the
  180 s timeout.
- `docs/regression/session-turns.md`: add the launch row to the
  transient-row ordering only if it changes that contract.
- `docs/regression/navigation-transitions.md`: the transition-free
  created-session replacement.

### Highest level and matrix

**L3 Release, client end to end.** The claim spans rendering, navigation, and
each plugin's first-message echo.

- **Client:** phone (the release-target platform) in narrow and split layouts,
  and desktop on all three creating surfaces.
- **Plugins:** every supporting production plugin, starting with a text
  prompt. The release rule must be observed on each echo family: ACP
  synthesized echo, Claude CLI replay, OpenCode backend SSE, Codex, and Pi
  queue. Also run one command start on Claude and on one ACP harness.
- **Modes:** dedicated and in-place, with warm and cold plugins.
- **Failure:** definitive rejection, and response loss or timeout, restore
  the exact draft with the warning. Also cover Back mid-creation.
- **Acceptance is structural:** the bubble appears in the first sending frame,
  and no frame between Send and the echo lacks the message or shows a spinner
  or "No messages yet".

## Risks And Accepted Limits

- Cold starts stay as slow as they are. Phase 1 changes only what the user
  sees while waiting.
- The positional release could drop the bubble early if a different user
  message echoed first. No current plugin can do that before the initial
  dispatch, and the outcome self-corrects.
- A 180 s timeout means a genuinely lost response surfaces later. Back stays
  available throughout.
- The bubble lives in client memory until the echo, so a process death during
  launch loses it, as with any unacknowledged send today.
