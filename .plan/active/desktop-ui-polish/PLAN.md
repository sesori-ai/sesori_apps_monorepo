# Desktop UI Polish — one coherent, delimited cockpit

## Status

- **Plan slug:** `desktop-ui-polish`
- **Status:** Proposed
- **Plan date:** 2026-09-19
- **Repository:** `sesori-ai/sesori_apps_monorepo`
- **Implementation base:** `main` at `bf14d7c0f3`
- **Delivery:** 22 numbered PRs (17 until the 2026-09-21 amendment, see
  D20); step 1 raises this plan before production work. State lives in
  [TRACKER](TRACKER.md).
- **Architecture review:** rejected 2026-09-19 on one seam (ownership and
  commit path of the pending-archive cubit); the findings were applied
  directly. See [Plan Review](#plan-review).

Planned directly after `desktop-ux` retired (#1551). The design was agreed
with the user over a four-round UI review on 2026-09-19 (a local HTML page
with real screenshots next to mockups; it contains private screenshots and is
deliberately not committed). Every agreed outcome is restated here in words,
so this plan does not depend on that file.

One part is deliberately **not** designed yet and carries an explicit approval
gate: the look of the composer's model/effort selectors and the redesign of the
sub-agents bar. See [Approval Gate](#approval-gate-composer-selectors-and-sub-agents-bar).

## Goal

Make the desktop app read as one designed product instead of a phone UI in a
window:

- a sidebar whose Activity list means exactly one thing and never moves
  sessions around;
- surfaces that are visibly delimited: a floating sidebar panel and a unified
  macOS title bar;
- pointer-sized pages that share one toolbar anatomy;
- right-click menus and confirmations that follow desktop conventions;
- a composer strip without pseudo-agents.

The work is client-side except one bridge-plugin change (harness modes stop
being presented as agents). No wire, relay, or database change.

## User Report

After `desktop-ux` shipped the user called the app "confusing and not
attractive as a whole… simply ugly, not properly delimited" and asked for a
UI-first review before any plan. Statements that shaped the design:

- The Running/Today split on the project page and the Activity/"All sessions"
  behaviour in the sidebar are confusing: sessions appear to move around.
- "Loudest button = rarest action — SPOT ON. Literally I keep on pressing it by
  mistake when I want new session" (the blue **New project** button).
- The sidebar should look like a floating, elevated panel.
- Keep the current loading/finished indicators ("the star shaped things").
- The archive/delete confirmation "feels wrong on desktop".
- The first composer dropdown (agent) "is often not needed… unless the user
  explicitly has more available let's not even show that entry"; "plan mode and
  question mode that we mapped as agents shouldn't be shown at all anymore".
- The "All tasks completed" bar should be "a lot less intrusive and lower
  width. That's actually covering subagents, rather than tasks. A subagent can
  get back alive."
- The File changes screen is out of scope entirely.

## Current Behavior And Findings

Verified in code on 2026-09-19 (paths relative to the repository root).

### Sidebar and Activity

- The whole sidebar is `client/desktop/lib/core/widgets/desktop_sidebar.dart`
  (one file, private widgets). Its only header button is a `FilledButton`
  **New project**. There is no sidebar-level "New session": creation is a
  hover-revealed `+` per project row, plus a "New task" floating button on the
  project page (`SessionListScaffold`, `sessionListNewTask`).
- Activity membership is a pure projection,
  `DesktopSidebarSessionProjection.from`
  (`client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_session_projection.dart`):
  a session is in Activity iff `isRunning || isUnseen`. Sessions placed in
  Activity are **removed** from their project's nested rows
  (`ordinaryRows` → `RecentSessionsResolvers.rows(excludingSessionIds:)`). That
  is the relocation the user sees.
- "Unread" is one bridge-authoritative boolean (`Session.unseen`, live through
  `SesoriSessionUnseenChanged`, mirrored by `SessionUnseenTracker`). The bridge
  computes it from timestamps; nothing on the wire says *why* a session is
  unseen. "The agent just finished" and "I marked it unread to keep it for
  later" are indistinguishable today, so both are pinned on top.
- Opening a session marks it seen through the view declaration
  (`SessionViewingService.setViewingSession`), so a clicked Activity row
  vanishes from under the cursor.
- Nested rows are capped at three plus the selected session by the shared
  resolver `RecentSessionsResolvers.rows` (`take(3)`); its only consumer is the
  desktop sidebar. "All sessions · N" is a `TextButton` that navigates to the
  same page the project name opens.
- The collapsed rail is the same widget at `expansion: 0`; Activity sessions
  render as their project's initials, so the rail shows rows of identical
  chips.
- The sidebar is a flush `Material(color: bgSecondary)` with no border, radius
  or elevation; a `VerticalDivider` resize handle abuts it
  (`desktop_cockpit_shell.dart`, `compactWidth = 56`, width 200–420, default
  260, auto-collapse under 760).

### Window chrome and shortcuts

- Before step 7, no title-bar customisation existed on any platform:
  `client/desktop/lib/core/platform/flutter_window_host.dart` built
  `WindowOptions` without a `titleBarStyle`, and `MainFlutterWindow.swift` only
  supported hidden launch. `window_manager ^0.5.2` was already a dependency.
- The in-app theme (`AppearanceCubit` → `MaterialApp.themeMode`) is never
  pushed to the native window, so the native title bar disagrees with the
  content whenever the in-app theme differs from the OS appearance.
- `Cmd/Ctrl+N` is registered in `desktop_router.dart` and silently does
  nothing without a project in the route. Other bindings: `Cmd/Ctrl+,`,
  `Cmd/Ctrl+B`, Escape dismissal.

### Pages, menus and confirmations

- The project page, session page and new-session page are phone screens from
  `client/module_app_ui` hosted by thin desktop screens
  (`DesktopSessionListScreen`, `DesktopSessionDetailScreen`,
  `DesktopNewSessionScreen`): phone row heights, a floating "New task" button,
  a session title drawn over the transcript without a backing surface,
  full-width text lines, and right-click menus that dim the window and lift
  the row (the iOS long-press pattern).
- Session actions come from one seam, `SessionListActionDispatcher`
  (`client/module_app_ui/lib/src/features/session_list/`); desktop holds one
  instance in `desktop_router.dart` (`_desktopSessionActions`) and the sidebar
  reuses it. The session page has no session actions besides the diff button.
- Archive and delete confirm through a phone bottom sheet
  (`session_cleanup_dialogs.dart` via `showPregoBottomSheet`) with a "Delete
  worktree" checkbox, no default button, then a success toast. Archiving is
  permanent. When the bridge refuses worktree cleanup (409, unsafe worktree)
  the only choices offered are Cancel or **Force**.

### Composer, agents and the sub-agents bar

- `PromptInput` is shared by phone and desktop. It has two modes (voice-first,
  text-first) and three layouts; desktop is forced to text-first with voice
  unsupported by `DesktopComposerPresentationScope`
  (`client/desktop/lib/core/widgets/`), the desktop widget that feeds the
  shared `ComposerPresentationScope`. The strip above the input
  (`_buildComposerTopSlot`) is the only region present in every mode and state:
  it holds the selectors, becomes the "Release to transcribe" hint while
  recording and the `/command` chip when one is staged.
- `AgentModelButtons` lays the selectors out as three `Expanded` dropdowns and
  shows the agent dropdown whenever the list is non-empty, so a single
  placeholder agent still gets a full-width dropdown.
- What the eleven harnesses put in that dropdown:

  | Harness | Entries today | Nature |
  |---|---|---|
  | Pi, DeepSeek, Hermes, Grok, Antigravity | one, named after the harness | placeholder |
  | Claude Code, Codex | Agent, Plan | harness mode mapped as an agent |
  | Cursor | Agent, Plan, Ask | harness modes mapped as agents |
  | OMP, Copilot | modes reported by the CLI at runtime | harness modes mapped as agents |
  | OpenCode | the user's real agents (build, plan, custom) | genuine agents |

  Bridge core passes `PluginAgent` through unfiltered; the client already hides
  `hidden` and `subagent` entries (`session_selection_calculator.dart`) and
  falls back to the first selectable agent when a stored name disappears. OMP
  and Copilot currently **throw** when asked for a mode they do not know.
- `BackgroundTasksBar` sits above the composer at full width. It lists child
  sessions (sub-agents) but speaks of "tasks", and its resting label "All tasks
  completed" claims a final state that is not final: a finished sub-agent can
  resume and new ones appear and finish during a turn. Inline sub-agent tiles
  already exist for the harnesses that expose them
  (`docs/HARNESS_CAPABILITIES.md`, Sub-agents).

## Design Decisions

All agreed with the user on 2026-09-19 unless marked otherwise.

- **D1 Activity means "in motion".** Activity = running sessions plus sessions
  with agent output the user has not looked at yet. A session the user marks
  unread on purpose stays quietly inside its project (bold, blue sparkle,
  counted on the project row) and does not return to Activity until the agent
  produces something new. No bridge or wire change: a desktop-local deferral
  marker.
- **D2 Sessions never relocate.** A session is always listed under its project;
  Activity is a shortcut list on top. The opened session stays in Activity,
  drawn as selected, until the user opens something else.
- **D3 Tree things happen in the tree.** "All sessions · N" becomes an
  in-place **Show more**. The project name is the one door to the project page.
- **D4 One primary action.** "New session ⌘N" is the sidebar's primary header
  button. "New project" becomes a small `+` on the Projects section header.
  `Cmd/Ctrl+N` works from anywhere: the current project, else the most recently
  active one; with no projects it opens the New project dialog.
- **D5 One noun.** "Session" everywhere; "task" is never used for a session.
  The strings are shared, so the phone inherits the wording.
- **D6 The sparkles stay.** `PregoAiLoader` is unchanged (hollow and turning
  while working, solid blue when finished and unread). It moves to one leading
  status column on every list; the time keeps its own trailing slot.
- **D7 Depth delimits.** The page content is the window's base surface; the
  sidebar (and the rail) is an inset, rounded, elevated panel on top of it.
- **D8 Unified macOS title bar.** The sidebar panel runs to the top edge and
  the traffic lights sit on it. `window_manager` hides the title bar but cannot
  move the lights, so the macOS runner gives the window an empty unified toolbar
  and AppKit itself sets them onto the panel (the user lifted the earlier "no
  custom Swift" limit for these few declarative lines on 2026-09-21). The
  collapse button lives in the panel's footer, so the top holds only the lights.
  Windows and Linux keep native chrome. The native
  brightness follows the in-app theme so chrome and content never disagree.
- **D9 Every rail button means one thing.** One Activity button with a count
  (the list pops out beside it), then one chip per project with a small sparkle
  when something in it is running or unread.
- **D10 Project page is one timeline.** No Running section: running sessions
  are simply the first rows of Today, with "Running" where the time would be.
  Filter chips All / Running / Unread; hover reveals Mark read/unread and
  Archive; about 44 pt rows in a width-capped column; "New session" lives in
  the page toolbar.
- **D11 Session page.** A solid toolbar with a hairline: title and context on
  the left; **Mark unread** (`Shift+Cmd/Ctrl+U`, returns to the project page,
  Gmail-style), **Changes**, and a `…` menu (Rename, Archive, Delete) on the
  right. Transcript and bottom controls share a centred column of about 760 pt.
- **D12 Right-click menus** are compact, open at the cursor, do not dim the
  window, and show shortcuts.
- **D13 Archive and delete on desktop.** Archive happens at once with an
  **Undo** toast (a client-side delayed commit; nothing is sent until the
  window closes). "Archive, keep worktree" is a separate menu item. Archive
  asks only when unusual: the session is still running, or the bridge refuses
  worktree cleanup — and then the default button is **Archive, keep worktree**,
  with "Delete it anyway" and Cancel beside it. Delete keeps a compact centred
  alert that names the session, offers the worktree checkbox ("the branch is
  kept"), cancels on Escape/Return, and needs a deliberate click on the red
  button. The phone keeps its sheets.
- **D14 New session page.** Centred "What should we work on?", a project
  selector, the same selector strip as the session page with the harness in
  front, the input, then "Dedicated workspace" and "Refresh options".
- **D15 Agents.** The agent entry appears only when more than one agent exists
  — one rule for every harness, OpenCode included. Harness modes are no longer
  presented as agents: Sesori stops offering Plan/Ask for Claude Code, Codex,
  Cursor, OMP and Copilot (user-confirmed consequence). A released mode value
  that still arrives is honoured, never silently downgraded. The phone follows,
  because the widget and the bridge are shared.
- **D16 Composer.** Selectors stay in the strip above the input in every mode
  and state. On desktop `+` and `/` are always visible and the box grows
  instead of opening the phone editor sheet. The **look** of the selectors is
  gated (D18).
- **D17 Sub-agents bar.** It speaks about sub-agents, never claims a final
  state, and becomes much narrower and less intrusive. Its design is gated
  (D18).
- **D18 Approval gate.** D16's selector look and D17 are built towards the end
  of the series, shown to the user as screenshots of the running app, and no
  PR is opened for them until the user explicitly approves.
- **D19 Out of scope.** The File changes screen and voice input on desktop.
- **D20 What suits the phone is built shared and the phone adopts it**
  (user direction, 2026-09-21; it replaces the earlier planning default that
  the phone stays unchanged). From step 13 on, an improvement that works with
  touch lives in `sesori_app_ui` or `sesori_dart_core` and both shells use it;
  a desktop-only opt-in switch is no longer the default shape. Work that
  merged before this date behind such switches (steps 9–12) moves to a shared
  implementation in steps 16–19, and step 20 deletes what that leaves unused.
  Pointer-only behaviour stays desktop-only: hover actions, right-click menus,
  the sidebar, rail and window chrome, pointer row density and keyboard
  shortcuts. The phone keeps what touch needs: swipe actions, the composer
  anchored above the keyboard, and its glass bars.

## Design

### Activity and the sidebar model (steps 3–5)

`DesktopSidebarSessionProjection.from` stays a pure function and gains two
inputs.

- **Deferral marker.** `DesktopSidebarLayout` (already persisted through
  `DesktopSidebarCubit`'s write queue) gains
  `deferredSessions: Map<String, int>` — session id → the session's
  `time.updated` when the user marked it unread on this desktop. A session is
  *deferred* while it is unseen and its `time.updated` still equals the
  recorded stamp. New agent output advances the stamp, so the session becomes
  news again without a subscription or timer. The rule becomes
  `isRunning || (isUnseen && !isDeferred)`. The marker is written through a
  new `onSessionMarkedUnread` hook on the desktop's
  `SessionListActionDispatcher` instance (next to the existing
  `onSessionDeleted`). The map is capped at 200 (oldest first) and never
  pruned otherwise: an entry is inert once the agent moves the session's stamp.
  Step 3 verified that `time.updated` advances with agent output for the
  registered plugins and that marking unread does not advance it
  (`steps/step-03.md`), so the running-session fallback was not needed.
- **Sticky selection.** The sidebar keeps one widget-local
  `String? stickyActivitySessionId`: set when the selection changes to a
  session that is in Activity at that moment, cleared when the selection
  changes again. The projection keeps that one session in Activity while it is
  selected, unless the user sets it aside.
- **No relocation.** `RecentSessionsResolvers.rows` loses
  `excludingSessionIds`; the projection stops tracking activity ids per
  project.
- **Show more.** `rows` takes a `limit`; `_SidebarProjectGroupState` owns the
  limit (3, +10 per click, reset when the group collapses). The "All sessions"
  button and string are deleted.
- **Sections and rows.** "Activity · N" and "Projects" become labelled,
  collapsible section headers (collapsed flags live in the same layout model);
  the Projects header carries the small `+`. Activity rows lead with the
  sparkle; project rows lead with the avatar; nested rows get the leading
  status column and a trailing compact time.
- **Rail.** One Activity button (sparkle + count) whose click opens the
  Activity list in an anchored popout, then one chip per project with a sparkle
  badge. The per-session chips disappear.

### Shell surfaces (steps 6–7)

- **Floating panel.** In `desktop_cockpit_shell.dart` the sidebar is wrapped in
  an 8 pt margin with a 14 pt radius, hairline border and soft shadow; the main
  pane paints the base surface. The visible divider goes away and the resize
  hit-area moves into the gap. Width bounds keep meaning the panel's width;
  the rail math includes the margin; the footer border is clipped by the
  panel; the connection pill is re-anchored. The pixel invariants in
  `desktop-cockpit-shell.md` are updated in the same PR.
- **Title bar.** macOS only. Every native-window operation stays behind the
  existing platform boundary: `WindowHost` (`client/module_desktop_core`) is
  the interface, and `FlutterWindowHost` remains the only file that imports
  `window_manager`. `FlutterWindowHost` builds
  `WindowOptions(titleBarStyle: TitleBarStyle.hidden, windowButtonVisibility: true)`
  on macOS, and `WindowHost` gains three platform-neutral operations: start
  dragging, toggle zoom, and set brightness (a closed light/dark value, because
  the core module is pure Dart).
  The expanded panel leaves room at its top for the traffic lights. A small
  shell drag-region widget covers that room (drag, and zoom on double-click)
  and, from the app root, the band a page toolbar fills (drag only, signed-out
  screens included) and calls the host; `window_manager`'s own `DragToMoveArea`
  is not used, because it would bypass the host. The traffic lights are wider
  than the rail, so the rail starts below them; they end before the page
  toolbar's leading control, so it needs no inset. In full screen the runner
  hides its empty toolbar, which AppKit would otherwise draw over the content.
  The native window brightness follows the app's **effective** brightness —
  the in-app mode resolved against the platform brightness — through one small
  shell widget under `MaterialApp` that observes `Theme.of(context).brightness`
  and calls the host's brightness operation (macOS and Windows).
  `window_manager` can only force light or dark (it has no "follow the system"
  value), so under System the widget re-applies the value on every OS
  light/dark switch.
  Full-screen, zoom and dragging are verified live before the PR opens; the
  step is independently revertible.

### Pages (steps 8–13)

**One pointer input (introduced by step 8).** `client/module_prego` gains a
closed `PregoInteractionMode { touch, pointer }` and a small
`PregoInteractionScope` inherited widget. `PregoInteractionScope.of(context)`
answers `touch` when no scope exists (the fallback posture of
`DefaultTextStyle`), so the phone and the existing widget tests change
nothing. The desktop app installs one scope in `app.dart`. Only shared widgets
with an agreed pointer presentation read it, in one place each:
`PregoAnchorMenu` (step 8) and `SessionTile` (steps 9–10). It is not a density
system: no spacing tokens and no theme fields, and a further reader needs a
plan amendment.

**Compact menus (step 8).** In pointer mode `PregoAnchorMenu` ignores
`spotlight` (no dimming, no lifted row), opens at the pointer for a secondary
click and at its anchor for a button, draws about 30 pt rows at `textSm`, and
renders a trailing shortcut label. Menu entries gain a required nullable
shortcut label, a string the desktop host formats the way the sidebar formats
its hints ("⌘N" or "Ctrl+N"), so shared code never formats key names or checks
the platform. (Flutter's shortcut labeller is private in the pinned toolchain,
so it cannot do the formatting.) Only real
bindings are shown (`Cmd/Ctrl+N`, and `Shift+Cmd/Ctrl+U` from step 11). Every
desktop call site inherits the look without a per-call-site flag.

**Project page (steps 9–10).** `DesktopSessionListScreen` stops hosting the
phone's `SessionListScaffold` and composes the page itself: a new
`DesktopPageToolbar` (`client/desktop/lib/core/widgets/`, reused by steps 11
and 13) over a scroll view holding the refresh progress bar, `CatalogScanRow`
and the shared `SessionListContent`, in a centred column capped at about
760 pt. The toolbar carries the project name and repository slug, an
**Archived** toggle (today's `toggleArchived`), **New session** as the page's
primary button, and an overflow menu that keeps today's two refresh actions
reachable (Refresh, Scan for sessions), because the pull gesture that owns
them has no mouse equivalent. The floating "New task" button is not part of
the desktop page.

- *One timeline.* `SessionListContent` takes a required closed
  `SessionListGrouping { runningSection, timeline }`. The phone passes
  `runningSection` and is unchanged. With `timeline`, a running session is
  bucketed under **Today** whatever its stored time, and its trailing slot
  reads "Running" (`sessionListRunning`). The service-owned ordering (running
  first) does not change.
- *Pointer rows.* In pointer mode `SessionTile` is about 44 pt tall with a
  13.5 pt title, a fixed leading status column holding the unchanged
  `PregoAiLoader` sparkle, the time always in the trailing slot, and a hover
  highlight.
- *Filter chips (step 10).* All · N, Running · N, Unread · N above the list.
  The session list is fully loaded client-side, so the counts are exact and
  the filter is a widget-local value applied to `SessionListLoaded.sessions`
  through the existing `isSessionRunning` / `isSessionUnseen` resolvers — no
  cubit state and no request. The chips hide while Archived is on. Unread is
  where "kept for later" sessions live.
- *Hover actions (step 10).* Hovering a row swaps the time for Mark
  read/unread and Archive buttons wired to the existing dispatcher handlers;
  keyboard focus reveals them too. An already archived row offers no Archive
  action, the same rule the menu follows.

**Session page (step 11).** `SessionDetailBody` keeps computing the title,
subtitle, busy state and diff availability, and gains one required nullable
input in the style of its existing `bottomControlsBuilder`: a small value
carrying a `headerBuilder` (which receives those computed values) and a
`maxContentWidth`, both non-null, so "a toolbar without a width cap" cannot be
expressed. The phone passes null and keeps its floating glass bar. The desktop
passes 760 and a builder returning a `DesktopPageToolbar` — title and context on the left; **Mark
unread**, **Changes** and a `…` menu (Rename, Archive, Archive keep worktree,
Delete) on the right — laid out above the transcript instead of over it. The
width is applied as symmetric padding computed from the available width inside
the transcript and the bottom controls, so the scrollbar and wheel area stay
full-width. The `…` menu reuses the sidebar's precedent: a throwaway
`SessionListCubit` in `SessionListMode.actions(sessions: [session])` driven by
the one desktop dispatcher. That needs a complete `Session`, which the desktop
screen does not have today (it receives ids and a title, and
`SessionDetailLoaded` exposes only derived fields). `SessionDetailLoaded`
therefore gains the hydrated `Session` the cubit already holds privately
(`_sessionMetadata`) as a required nullable field, the header builder receives
it, and the toolbar's session actions stay disabled until it is non-null. This
also covers child sessions and sessions opened directly, which the sidebar
inventory never holds.

Mark unread is an explicit operation, not the row's toggle: the dispatcher
gains `handleSessionMarkUnread`, which always sends `read: false` and fires
the `onSessionMarkedUnread` hook. The row toggle fires that hook only on its
mark-unread branch, so marking a session read never writes a deferral entry.
The toggle derives its direction from local state, which can still say "unseen" just after opening
(the bridge marks a session seen asynchronously when viewing starts) and
would then mark the session read. After marking unread the page navigates to
the project page. `Shift+Cmd/Ctrl+U` is registered beside the existing
bindings in `desktop_router.dart` and acts only while a session route is
open.

**Archive with Undo and compact alerts (step 12).**
`SessionListActionDispatcher` takes a required sealed `SessionCleanupFlow`.
`sheets` is the phone: today's confirmation sheets, unchanged. `immediate` is
the desktop: it carries an archive callback (session, deleteWorktree) and a
delete-confirmation callback, and makes the dispatcher offer **Archive** and
**Archive, keep worktree** as separate entries instead of opening a sheet.
After a confirmed delete the dispatcher's existing delete operation and
refusal handling run unchanged.

- `PendingSessionArchiveCubit` (`client/module_desktop_core`) depends on
  `SessionRepository` only — never on a `SessionListCubit`, which may be
  unmounted by the time the window closes. It is not DI-registered: the
  cockpit shell creates it with `BlocProvider(create:)` beside
  `DesktopSidebarCubit` (`desktop_cockpit_shell.dart`), so it outlives every
  page and the sidebar. Closing the cubit cancels the timer and sends nothing.
- Its state composes two independent parts. The **Undo window** is sealed:
  idle, or pending(session, deleteWorktree), with one `Timer` of about five
  seconds. The **archiving ids** are the sessions whose commit is in flight or
  has succeeded during this run. Commit outcomes — committed, refused(session,
  rejection), failed(session) — are one-shot events on a stream, the pattern
  `SessionDetailCubit.noticeStream` already uses. They are not state, so the
  late outcome of session A can never overwrite session B's Undo window.
- The desktop archive callback asks first only when the session is running,
  then opens the Undo window. The sidebar projection and `SessionListContent`
  take the hidden ids (the pending session plus the archiving ids) and hide
  those sessions while they still read as unarchived. An open page for that
  session returns to its project page. One listener in the cockpit shell shows
  the existing top-anchored `PregoPopupAlertPresenter` alert "Archived" with
  an **Undo** action, and later the refusal alert or the error toast. The
  alert's duration is the same constant as the timer, because the presenter's
  default is shorter.
- Undo returns the window to idle and the row comes back; nothing was sent.
  When the timer fires, the session moves to the archiving ids and the cubit
  calls `SessionRepository.archiveSession`. A second archive commits the first
  immediately: one Undo window at a time, no queue, and any number of commits
  in flight.
- The bridge publishes no session event on archive (its handler returns the
  session and emits only an unseen change), and plugins such as Claude Code
  and Pi emit none either, so the inventories are not assumed to converge on
  their own. A committed id therefore stays in the archiving ids for the rest
  of the run, which keeps a stale active-looking row hidden in the sidebar and
  the list. On `committed` the desktop project page also refreshes its list,
  so the Archived view shows the session at once.
- `SessionCleanupRejectedException` (the 409 worktree refusal) removes the id
  and emits `refused`: a compact alert with **Archive, keep worktree** as the
  default, "Delete it anyway" and Cancel beside it; either choice commits
  directly, without a second Undo window. Any other failure removes the id and
  emits `failed`: the row returns, an error toast shows, and the cubit logs
  the original error with the session id.
- Delete uses a compact centred alert (`showDialog`, about 420 pt) naming the
  session, with the worktree checkbox, Cancel on Escape/Return, and a red
  button that is never the default.

**New session page (step 13).** `NewSessionView` gains one required nullable
value carrying a top bar and a header, both non-null. When the host passes it,
the view draws that top bar instead of the glass bar and lays the header and
the composer block out as one centred, width-capped column instead of
anchoring the composer to the bottom. The desktop passes a
`DesktopPageToolbar` titled "New session" and the "What should we work on?"
heading plus a project selector; choosing another project replaces the route
with that project's new-session route. The router's replace reuses the page
identity (`GoRouter.replace`), and `DesktopNewSessionScreen` creates its
`NewSessionCubit` once in `BlocProvider(create:)`, so the route builder keys
the screen by project id — the precedent is `DesktopSessionListCubitProvider`'s
`ValueKey` on the sessions route — and a switch builds a fresh cubit for the
chosen project instead of creating the session in the previous one.
New-session drafts are already stored
per project (`ComposerDraftRepository.saveForNewSession`), so text typed
before switching stays with the project it was typed in rather than being
lost, and nothing carries it across. The harness chooser sits left-aligned
directly above the selector strip, with "Dedicated workspace" and "Refresh
options" below the input. Folding the harness into the strip itself belongs to
the gated step.

### Agents (step 14)

- Client: `AgentModelButtons` shows the agent entry only when more than one
  selectable agent exists.
- Plugins (Claude, Codex, Cursor, OMP, Copilot): stop **advertising** the
  non-default modes. Each lists only its default entry — "Agent" for Claude and
  Codex, and for Cursor, OMP and Copilot the default mode their CLI reports,
  which they already sort first. The inbound path does not change: a released
  mode value that still arrives is honoured, and an unknown value keeps each
  plugin's current behaviour.
- Why the value is honoured rather than ignored: "Plan" remains a real inbound
  value after the change. The bridge serves its cached session-options
  catalogs for up to 30 days (`session_options_service.dart`: stale after a
  day, retained for 30), clients send the agent by name, and an older app can
  have the selection in flight. Running such a turn in the default mode would
  let it edit files although the user chose a non-editing mode.
- Every client sends the single advertised agent by name and the plugins
  already resolve that name to the default mode, so a session left in plan
  mode returns to the default mode with its next prompt in all five harnesses.
- The retained inbound branches for non-default modes (and the agent reset
  Claude emits on plan exit, which an honoured "Plan" still needs) carry a dated
  `COMPATIBILITY` marker whose retiring condition is that no catalog captured
  before this change can still be served. Their deletion is a later phase, not
  part of this series.
- OpenCode is untouched; its chip follows the same "more than one" rule.
- `docs/HARNESS_CAPABILITIES.md` gains a short "Agent selection and harness
  modes" section; `session-creation-and-options.md` is updated.

### Approval Gate: composer selectors and sub-agents bar

Step 15 is different from every other step.

1. Build locally on top of step 14: a single closed desktop presentation value
   on the existing `ComposerPresentationScope` (not three booleans) that drives
   compact left-aligned selectors, always-visible `+` and `/`, and a growing
   text box without the editor sheet. The composer's state machine, the phone,
   and the recording/staged-command behaviour of the top slot do not change.
2. Build the sub-agents presentation: sub-agent vocabulary, no final-state
   claim (a count and a running signal, not "completed"), much narrower and
   visually quiet. Two real variants are prepared for comparison: a small pill
   sharing the selector strip's trailing edge, and a session-toolbar item with
   a count that opens the same list as a popover.
3. Send the user screenshots of the **running app** (light and dark, resting,
   typing, a running sub-agent, a finished sub-agent that resumes).
4. Iterate on feedback. **No PR is opened until the user explicitly approves
   the actual UI.** On approval the step may split into 15.a (composer) and
   15.b (sub-agents) if the diff warrants it.

## Failure Semantics

- **Deferral marker.** The projection stays pure. A failed layout write is
  already logged by the sidebar cubit's write queue; the only effect is that a
  deferred session shows in Activity again after a restart. A retained marker
  matters only while the stamp is unchanged: marking the session unread again
  before the agent moves it, here or on another device, keeps it set aside on
  this desktop, as D1 asks. Once the agent moves the stamp the marker is inert.
- **Pending archive.** Undo, or quitting inside the window, sends nothing and
  the session stays. Outcomes are events, not state, so overlapping archives
  cannot overwrite each other. A commit failure is never silent: a worktree refusal
  opens the refusal alert; anything else (a lost connection included) restores
  the row and shows an error toast, and the cubit logs the original error with
  the session id. Signing out inside the window closes the cubit and sends
  nothing.
- **Mode value that is no longer advertised.** A released non-default mode
  that still arrives (cached catalog, older app) runs in that mode, exactly as
  today. Unknown values keep each plugin's current behaviour, which step 14
  does not touch: Claude and Copilot reject the request, OMP fails the turn,
  Codex and Cursor fall back to the default mode.
- **Title bar.** macOS only. If live verification shows a regression in
  dragging, zoom or full screen, the step does not ship; nothing else depends
  on it except the panel's top inset, which is zero under native chrome.
- **Widget-local state** (sticky Activity id, Show more limit, filter chip,
  hover) has no failure mode beyond resetting when its widget goes away.

## Compatibility

- No wire shape, relay or database change.
- **Newer app, older bridge:** the bridge still lists Agent/Plan(/Ask); that is
  more than one agent, so the entry shows and the old bridge honours it.
- **Older app, newer bridge:** the five harnesses list one agent, as Pi does
  today, and the older app draws its one-entry dropdown. A "Plan" value that
  still arrives — from a catalog the bridge cached before the change, or an
  older app's in-flight selection — is honoured, never ignored or rejected.
- **Persisted selections** that name a mode no longer advertised (`lastAgent`,
  new-session defaults) get no migration: once the advertised list no longer
  contains the stored name, the client already falls back to the first
  selectable agent.
- **Layout file.** `DesktopSidebarLayout` is a desktop-local file, not a
  transport contract, and no public production desktop release exists at the
  plan date; the new fields default honestly (empty map, sections expanded)
  with no compatibility marker.
- **Strings.** Every string that calls a session a task changes in step 2
  (D5): `sessionListNewTask` is deleted and the phone's button reads "New
  session"; `sessionListEmptyTitle` ("Start your first task"),
  `archivedSessionsTitle` ("Archived tasks") and
  `projectsOnboardingWhyNotifiedSubtitle` ("Know when a task needs you.") say
  "session". The sub-agents bar's task strings are genuine sub-agent wording
  and stay with step 15.

## Non-Goals

- The File changes screen and voice input on desktop (D19).
- Phone adoption of pointer-only behaviour, the sidebar, the rail or window
  chrome (D20).
- A bridge-level "why is this unread" signal, or syncing deferral between
  devices.
- An unarchive endpoint: Undo is a delayed commit.
- A density or spacing token system, or a desktop theme fork.
- Custom title bars on Windows and Linux; C++ runner code, or Swift beyond the
  macOS runner's declarative toolbar lines that D8 allows.
- Stacked, queued or bottom-anchored toasts.
- A replacement control for Plan/Ask.
- New analytics events: the series restyles existing actions, and
  `new_session` / `session_created_with_message` keep firing from the same
  authoritative outcomes.

## Complexity Budget

New persistent state, all inside the existing desktop-local layout file (no
new file, table or wire field):

- `deferredSessions` (session id → stamp; capped at 200, oldest dropped);
- two section-collapsed flags.

New in-memory mutable state, each with exactly one owner:

| State | Owner | Lifetime |
|---|---|---|
| Sticky Activity session id | sidebar widget state | until the selection changes |
| Show more limit per project | `_SidebarProjectGroupState` | until the group collapses |
| Rail Activity popout open | the popout's anchor controller | until dismissed |
| Filter chip selection | desktop project page state | page lifetime |
| Row hover | row widget state | pointer presence |
| Undo window + one `Timer` | `PendingSessionArchiveCubit` | about five seconds |
| Archiving ids | `PendingSessionArchiveCubit` | the app run; one id per archive |

New types: `PregoInteractionMode` / `PregoInteractionScope`,
`SessionListGrouping`, `SessionCleanupFlow`, `DesktopPageToolbar`,
`PendingSessionArchiveCubit`, and the two small presentation values on
`SessionDetailBody` and `NewSessionView`. Existing types grow by three
`WindowHost` operations, one dispatcher handler (`handleSessionMarkUnread`)
and one `SessionDetailLoaded` field. No new DI registration (the cubit is
created by `BlocProvider` in the cockpit shell), route, repository, service,
stream or subscription.

Deliberately not added: everything under Non-Goals, a per-call-site "compact"
flag on menus, a desktop fork of any shared widget, and carrying typed text
between projects.

## Cleanup Assessment

Removed by the series:

- `excludingSessionIds` and the projection's per-project activity-id tracking
  (step 3);
- the "All sessions · N" button and its string (step 4);
- per-session rail chips (step 5);
- the `VerticalDivider` resize presentation (step 6);
- `sessionListNewTask`, and the desktop's use of the floating button and of
  `SessionListScaffold`, which stays as the phone's scaffold (steps 2, 9);
- the non-default mode entries in five plugins' advertised agent lists
  (step 14); their inbound mapping stays until its compatibility marker
  retires (Later Phases);
- the sub-agents bar's "tasks" strings (step 15).

Declined, because it would widen the series: splitting the 1,100-line
`desktop_sidebar.dart`. Steps 2–6 touch it one at a time; widgets that steps
4–5 introduce (section header, rail Activity popout) go in their own files
beside it, and the existing private widgets are not moved.

## Delivery Plan

Series slug `desktop-ui-polish`, 22 PRs, one at a time in order. Steps 1–12
were published with a total of 17, before the D20 amendment added steps 16–20.
Targets count additions plus deletions across every path. Exact titles and branches are in
[TRACKER](TRACKER.md#pr-titles). Each behaviour-changing step updates the
regression lines it invalidates in the same PR; step 21 reconciles the whole.

| Step | Delivery | Target | Scope |
|---|---|---|---|
| 1 | 1/17 | ≤ 1,100 | This plan, tracker and the roadmap cross-reference. |
| 2 | 2/17 | ≤ 350 | "New session" is the sidebar's primary button with "New project" as a small `+` beside it (step 4 moves it onto the Projects header); `Cmd/Ctrl+N` works anywhere (D4); every session-facing "task" string says "session" and `sessionListNewTask` is deleted (D5). |
| 3 | 3/17 | ≤ 600 | Activity in motion: `time.updated` verification, deferral marker, sticky selection, no relocation (D1, D2). |
| 4 | 4/17 | ≤ 700 | Labelled collapsible sections, leading status column, trailing time, Show more (D3, D6). |
| 5 | 5/17 | ≤ 400 | Rail: one Activity button with a popout, one chip per project (D9). |
| 6 | 6/17 | ≤ 450 | Floating sidebar panel and base-surface main pane (D7). |
| 7 | 7/17 | ≤ 350 | Unified macOS title bar; native brightness follows the in-app theme (D8). |
| 8 | 8/17 | ≤ 500 | `PregoInteractionScope` and compact pointer menus (D12). |
| 9 | 9/17 | ≤ 800 | Desktop project page: `DesktopPageToolbar`, one timeline, pointer rows (D10). |
| 10 | 10/17 | ≤ 500 | Filter chips and hover actions (D10). |
| 11 | 11/17 | ≤ 700 | Session toolbar, centred column, Mark unread and its shortcut (D11). |
| 12 | 12/17 | ≤ 900 | Archive with Undo, refusal alert, compact delete alert (D13). |
| 13 | 13/22 | ≤ 600 | New session page (D14). The heading and the project selector are shared and the phone shows them too; the desktop adds the toolbar and the centred column, the phone keeps its composer above the keyboard (D20). |
| 14 | 14/22 | ≤ 600 | Agent entry rule; five plugins advertise only their default agent and keep honouring released mode values; `HARNESS_CAPABILITIES.md` (D15). |
| 15 | 15/22 | set at approval | **Gated.** Composer selector look and the sub-agents bar, on both shells (D16–D18). No PR before explicit approval of real screenshots. |
| 16 | 16/22 | ≤ 500 | Phone session list becomes one timeline: Running merges into Today with the leading status, as on desktop (D10, D20). |
| 17 | 17/22 | ≤ 500 | The All / Running / Unread filter chips become one shared widget and the phone list shows them (D10, D20). |
| 18 | 18/22 | ≤ 900 | Archive with Undo on the phone: the pending-archive cubit moves to `sesori_dart_core`, the alerts move to `sesori_app_ui`, and the phone's swipe and menu archive use them (D13, D20). |
| 19 | 19/22 | ≤ 500 | Phone session page: Mark unread and the Rename / Archive / Delete menu come from the shared implementation (D11, D20). |
| 20 | 20/22 | ≤ 400 | Cleanup: delete the inputs, variants and widgets that both shells now set the same way or that nothing uses (D20). |
| 21 | 21/22 | ≤ 400 | Reconcile `docs/regression/`. |
| 22 | 22/22 | ≤ 300 | Execute the final matrix on the merged series, record it, retire to `.plan/completed/`. |

Steps 16–20 are rough on purpose. Each one is detailed when it starts, against
the code as it then stands, and is dropped with a recorded reason if the phone
already behaves that way or the move would not make the phone better. Step 20's
known candidates are `SessionListGrouping.runningSection`, the archive
confirmation sheet, the `hiddenSessionIds` opt-outs and the
`SessionCleanupFlow` variant the phone stops using.

Steps 16–20 do not wait for step 15's approval. Steps 21 and 22 wait for it, or
for the user's explicit decision to drop or defer it.

## Per-Step Verification

Every step analyzes its owning packages and runs the directly relevant tests;
CI runs the full matrix. Evidence goes in `steps/step-NN.md`, written by that
step's own PR.

- **2:** sidebar header widget test; shortcut test for the three cases
  (project in the route, none, no projects at all).
- **3:** projection unit tests — running; unseen; deferred stays out; deferred
  with a newer `time.updated` comes back; the sticky selected session stays;
  Activity sessions also appear under their project. Layout JSON round-trip
  with defaults. The `time.updated` finding is recorded before any code.
- **4:** resolver `limit` tests; Show more (+10, reset on collapse); section
  collapse persists.
- **5:** rail shows one Activity button with its count and one chip per
  project; the popout lists the Activity rows.
- **6:** layout test for the margin and the resize hit-area; live check of
  resize, collapse and persisted width.
- **7:** `FlutterWindowHost` is still the only `window_manager` import; the
  brightness widget and the drag region are tested against a fake
  `WindowHost`. Live on macOS — drag, double-click zoom, full screen in and out,
  traffic lights with the rail collapsed, light/dark/system switching the
  native brightness, and an OS appearance switch while System is selected
  (after a forced value was applied). Windows and Linux still build with
  native chrome.
- **8:** `module_prego` widget tests — pointer mode has no barrier or
  spotlight, opens at the pointer, shows the shortcut label; touch-mode tests
  pass untouched.
- **9:** `SessionListContent` under both groupings; `SessionTile` in pointer
  mode; the first desktop project page widget test (toolbar, Archived toggle,
  no floating button).
- **10:** counts and filtering; chips hidden under Archived; hover and focus
  reveal actions that call the dispatcher; an archived row has no Archive
  action.
- **11:** `SessionDetailBody` with and without `headerBuilder`; width maths;
  session actions disabled until the hydrated `Session` arrives, and working
  for a child session; Mark unread sends `read: false` even while local state
  still says unseen, fires the deferral hook, and lands on the project page;
  the shortcut is inert off a session route.
- **12:** cubit tests under fake time — Undo sends nothing; the timer commits
  through `SessionRepository` with no list cubit mounted; a second archive
  flushes the first, and the first one's late refusal or failure leaves the
  second Undo window intact; a committed id stays hidden without any session
  event; 409 → refused, other failure → failed and the row returns; close
  sends nothing. The alert duration equals the timer. The first dispatcher
  test covers both `SessionCleanupFlow` variants; phone sheets unchanged.
- **13:** header-slot layout; after a project switch the route, the mounted
  `NewSessionCubit`'s project and the created session's project are all the
  chosen one; a phone test shows the shared heading and project selector.
- **14:** per-plugin catalog tests (only the default entry is advertised); a
  prompt carrying a released non-default mode still runs in that mode; a prompt
  carrying the advertised entry returns a plan-mode session to the default
  mode; `AgentModelButtons` with zero, one and two agents; one live Claude Code
  turn in which a session left in plan mode runs its next prompt in the default
  mode.
- **15:** the approval gate first; then tests for the approved design.
- **16–19:** each adopting step adds phone widget coverage for what the phone
  gains and keeps the desktop tests passing; step 18 moves the cubit's tests
  with it.
- **20:** deletion only; both apps analyze and their suites pass.
- **21:** documentation validation only.
- **22:** executes the final matrix below on the merged series and records
  every cell in `steps/step-22.md`. A cell that was not executed is recorded
  as unexecuted, never as passed, and needs the user's explicit acceptance
  before the plan retires.

Steps 8–12 merged under the earlier default, where a phone test that needed
editing was a review signal. From step 13 on, phone tests change on purpose
and each adopting step adds phone coverage for what it adopts.

## Regression Documentation And Final Matrix

Affected feature documents:

- `desktop-cockpit-shell.md` — panel and rail invariants, the Activity rule,
  the three-row cap becoming Show more, the header's primary action, the
  shortcut list (`Cmd/Ctrl+N` anywhere, `Shift+Cmd/Ctrl+U`), and "All
  platforms retain native window chrome" becoming the macOS unified title bar.
- `projects-and-sessions.md` — the Running-first contract gains the desktop
  one-timeline presentation, filter chips and hover actions.
- `session-archiving-and-deletion.md` — the desktop Undo flow, the refusal
  alert's default, the compact delete alert; phone sheets unchanged.
- `session-creation-and-options.md` — the agent entry rule, modes no longer
  offered, the desktop new-session page, `Cmd/Ctrl+N` anywhere.
- `popup-alerts.md` — an alert carrying an Undo action.
- `native-activity-indicators.md` and `voice-input.md` — only if they state
  the sparkle's position or describe the composer presentation step 15
  changes.
- `docs/HARNESS_CAPABILITIES.md` — a new "Agent selection and harness modes"
  section; Sub-agents wording if step 15 changes what the bar claims.

Highest coverage level: **L3, client end to end** on macOS desktop against a
live bridge with a representative plugin. Step 14 adds the **Live plugin**
boundary: one real Claude Code turn from a stored "Plan" selection.

| Platform | Level | Boundary | Scope |
|---|---|---|---|
| macOS desktop | L3 | Client end to end, live bridge, representative plugin | Sidebar and Activity, rail, panel, title bar and theme, menus, project page, session page, archive/Undo/delete, new session page, agent entry |
| Bridge plugins (5 touched) | L2 + one live turn | Automated for all five; Live plugin for Claude Code | One advertised agent; released mode values still honoured |
| iOS, Android | L2 + one smoke | Automated + release-target device | Wording, agent entry rule; list, menus and sheets unchanged |
| Windows, Linux | smoke | Client end to end | Build, native chrome intact, floating panel, compact menus |

Proposed reductions, to be accepted with this plan: Windows and Linux run a
smoke pass (the reduction accepted for `desktop-ux`), and four of the five
touched plugins are proven by automated tests rather than a live turn each.

## Risks And Accepted Limits

- **Deferral is per desktop.** Marking unread on the phone shows as news on
  the desktop, unless this desktop still holds a marker at the same stamp.
  Fixing it needs a bridge-level reason (Later Phases).
- **`time.updated` also moves without agent output.** Renaming a session
  stamps it, and a cold Claude Code or Pi catalog import reads the transcript
  file's modification time. Either can return a deferred session to Activity
  once; the user defers it again. Accepted: rare, harmless, self-correcting.
- **Hidden title bar.** Dragging, zoom and full screen can regress; verified
  live, independently revertible.
- **Undo toast.** It is top-anchored and the presenter does not stack, so
  another toast can replace it inside the window; the archive then commits on
  time without a visible Undo. Accepted: archiving is what the user asked for.
  A pending archive is also dropped by quitting (the session simply stays).
- **Archive is not announced to other devices.** The bridge publishes no
  session event on archive, so the phone (or a second desktop) drops the row
  on its next refresh. Pre-existing, and not widened into here; this desktop
  stays correct through the archiving ids.
- **Plan/Ask fade out rather than vanish at once.** The bridge serves cached
  session-options catalogs for up to 30 days, so the entries disappear as each
  catalog refreshes. Accepted: a mode chosen from a cached list is still
  honoured, and nothing is invalidated to hurry it.
- **Plan/Ask are no longer offered from Sesori** (user-confirmed).
- **Shared-widget edits can regress the phone.** Through step 12 every one
  sits behind a closed input whose phone value is the earlier behaviour. From
  step 13 the phone changes on purpose (D20), so each adopting step runs the
  phone suite and analyzes `client/app`.
- **One large file.** Steps 2–6 all touch `desktop_sidebar.dart`; they are
  serialized and add new widgets in new files.
- **Step 15 can take several rounds.** It blocks only steps 21–22.

## Plan Review

`architecture-plan-review` ran once through a sub-agent on 2026-09-19 and
**rejected** the draft on one seam; the valid findings were applied directly
without a re-review, as the process requires.

- **Applied — cubit ownership.** The draft budgeted "one new DI registration"
  for `PendingSessionArchiveCubit`; cubits are never DI-registered. It is now
  created by `BlocProvider` in the cockpit shell beside `DesktopSidebarCubit`.
- **Applied — commit path.** The draft committed "through the existing
  `SessionListCubit` path", which may be unmounted inside the Undo window and
  would have been a cubit depending on a cubit. The cubit now depends on
  `SessionRepository` only and owns the refused/failed outcomes itself.
- **Checked and not applied.** The review reported that
  `DesktopComposerPresentationScope` does not exist. It does
  (`client/desktop/lib/core/widgets/desktop_composer_presentation_scope.dart`)
  and wraps the shared `ComposerPresentationScope`; the finding's path was
  added to the text for clarity.
- **Optional suggestions applied.** The confirmation strategy is named (the
  sealed `SessionCleanupFlow`); the new-session page's use of
  `DesktopPageToolbar` is stated; Claude's plan-exit reset was located and the
  deletion narrowed to the emitted agent reset. The paired nullable inputs on
  `SessionDetailBody` and `NewSessionView` were each folded into one value so
  half-configured states cannot be expressed.

**PR review corrections (Codex, 2026-09-19), applied:** commit outcomes
became one-shot events and the state became an Undo window plus archiving
ids, so overlapping archives cannot overwrite each other; the Undo alert's
duration is tied to the timer; a committed id stays hidden because the bridge
publishes no session event on archive (verified in
`update_session_archive_status_handler.dart`); the native brightness follows
the effective brightness, including OS switches under System
(`window_manager` can only force light or dark); archived rows offer no
Archive hover action; and the final step executes the final matrix instead of only
recording it. A second round (2026-09-20) routed the brightness and
drag-region operations through `WindowHost`, so `FlutterWindowHost` stays the
only `window_manager` import; made the session page's Mark unread an explicit
`read: false` operation instead of the state-dependent toggle; and gave the
toolbar's session actions a defined source by exposing the hydrated `Session`
on `SessionDetailLoaded`. A third round (2026-09-20) replaced step 14's
"emit a placeholder agent and ignore the value" with "advertise only the
default entry and keep honouring released mode values", after an audit of the
five plugins and of the bridge's 30-day session-options cache showed that
"Plan" can still arrive and must not silently run an edit-capable mode; keyed
the new-session screen by project so a project switch builds a fresh cubit;
and listed every session-facing "task" string for step 2. cubic's seven line-length findings were declined: the
repository has no Markdown line-length convention.

The architecture review found the rest compliant: plugin-boundary hygiene (the agent entry
is a pure count rule, never a backend check), the closed-input mechanism for
D20, the placeholder-agent pattern (since replaced by the third PR review
round above), naming, and no abstraction without a current consumer.

## Relation To Other Plans

- `desktop-ux` (completed) built the cockpit this plan restyles. This plan
  supersedes its sidebar rules (Activity = running ∪ unseen, the three-row cap
  with "All sessions") and the matching `desktop-cockpit-shell.md` invariants.
- `desktop-app` and `desktop-distribution` (active) are independent; nothing
  here completes or waives their gates. Packaged macOS QA that runs after
  step 7 sees the unified title bar.
- `instant-session-launch` (proposed) also edits `NewSessionView`; step 13
  changes only its layout and header slot, and whichever lands second rebases.
- `claude-inline-subtasks` (completed) supplies the inline sub-agent tiles the
  step 15 bar builds on.

## Later Phases (rough intent only; planned when they start)

- Voice input on desktop: the composer already has the modes; it needs a
  desktop capture implementation.
- The File changes screen.
- A bridge-level unread reason, so "kept for later" follows the user across
  devices.
- Custom title bars on Windows and Linux.
- A real per-harness mode control, if Plan/Ask are missed.
- Deleting the five plugins' inbound mapping for modes that are no longer
  advertised, with Claude's plan-exit agent reset, once no catalog captured
  before step 14 can still be served.

## Expected Result

The desktop app reads as one designed product. The sidebar is a floating panel
under a unified title bar, with one obvious "New session" button. Activity
lists only what is in motion, and no session ever jumps between lists. Pages
share one toolbar and pointer-sized rows; menus and confirmations behave the
way desktop users expect; the composer strip shows an agent entry only when
there is a real choice. The phone gains what suits touch from the same shared
code: the new session heading and project selector, one timeline with filter
chips, archive with Undo, and Mark unread. There is no wire, relay or database
impact.
