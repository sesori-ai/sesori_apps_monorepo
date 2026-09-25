# Desktop Cockpit Shell

## Capability

Desktop project navigation in a resizable sidebar that floats as a panel over
the page, with a compact initials rail and desktop-owned layout preferences. The sidebar and home pane share one
signed-in project inventory; one shared recent-session cache feeds the tree.
The main pane hosts one full-width routed page.

## Required Behavior

- The sidebar and its rail float as a panel over the base surface the pages
  paint: inset 8 pixels from the window's top, bottom and start edges, with
  14-pixel corners, a hairline border and a soft shadow, and no divider. The
  panel clips its footer. An 8-pixel gap separates it from the main pane, which
  therefore starts 16 pixels past the panel's width. While the sidebar is
  expanded that gap is the resize handle, with a resize cursor and no visible
  line; the fixed-width rail has none. Width bounds and the rail's 56 pixels
  measure the panel itself.
- macOS hides the native title bar and keeps its traffic lights; Windows and Linux keep their native chrome.
  The macOS runner gives the window an empty unified toolbar, so AppKit itself sets the lights lower and
  further in: the expanded panel keeps its 8 pixel inset and carries them above its first control, which
  starts 42 pixels from the window's top. The lights are wider than the rail, so the rail itself starts 42
  pixels from the top, below them. The room the panel leaves for the lights, and the strip above the rail,
  drag the window and zoom it on a double click. In full screen the runner hides that toolbar, which AppKit
  would otherwise draw as a bar over the content's top, and restores it on exit. The window's top 54 pixels,
  the band a page toolbar fills, drag it on every screen, the signed-out login included: a press becomes a
  drag only after it travels further than a click tolerates, so toolbar controls keep their clicks,
  undelayed, and a text selection or a scrollbar still wins its own press. Where the band and a zooming
  region overlap, one press still reaches the host once.
- Open, the sidebar's footer is one 44-point row: This computer, then Settings and collapse. Refresh sits
  on the Projects header beside New project. The rail stacks the footer: This computer, then refresh and
  Settings, then collapse, since it fits two controls a line. The session list clips its rows' highlights, so a
  highlighted row scrolled under the section above never shows through it.
- The native window chrome is forced to the app's effective brightness (the in-app mode, or the system's
  while the app follows it) and again on every change, because a host can only be forced light or dark.
  Chrome and content therefore never disagree, including after the system switches appearance while the
  app follows it.
- Expanded width defaults to 260 logical pixels and clamps to 200–420. Dragging
  uses the starting width plus global pointer displacement, preserving overshoot
  when reversing beyond either bound. Changes are immediate; an admitted drag
  saves once on completion/cancellation, and double-click reset saves once.
  Idle gesture cancellation does not write; explicit sidebar/project collapse toggles do.
- Expanded project controls have a 16-pixel directional scrollbar gutter.
  Trailing expand/collapse buttons remain clickable while the scrollbar is visible;
  thumb dragging still scrolls. The gutter shrinks with expansion to zero in the compact rail.
- Collapse uses a 56-pixel rail with deterministic two-grapheme project avatars
  and full-name tooltips. Expanding restores the user's width. Width and label
  transitions animate together; reduced motion disables the transition without
  delaying drag feedback.
- Windows narrower than 760 pixels temporarily collapse the sidebar without
  changing saved preferences. Widening restores the user's expanded/collapsed
  choice. The native minimum window remains 560 × 480.
- Project shortcuts open the existing sessions route. New session is a quiet row at the top of the sidebar,
  with its shortcut at the row's end; with no projects it reads Add project. The small New project button on the Projects section header uses the shared folder dialog and project-list
  cubit, and hides with the collapsed sidebar, where the home pane still offers it. The collapse control owns
  sidebar presentation. The compact Projects shortcut opens home, including empty/recovery states when the window is
  too narrow to expand. The separated footer groups This computer with the Settings and collapse controls.
  Icon/status hints and truncated-label hints remain useful, while fully visible labels need no duplicate tooltip.
- Explicit sidebar refresh runs through Layer-3 `DesktopSidebarRefreshService` over the same scoped project and recent
  inventory services. It awaits the project phase before refreshing admitted recent entries, joining initial reads
  already in flight. An ordinary project failure still allows retained recent entries to update; either phase failing
  produces failure feedback. Useful rows stay visible. Busy controls cannot dispatch duplicate intent, and busy/idle
  refresh plus Settings expose accessible names and keyboard actions.
  A superseded caller follows the current owning read after every completion, including an already-completed successor
  followed by a newer owner. Completed failures stay observable despite retained rows. During the recent-session phase,
  removal or disposal retires pending receipts without waiting for obsolete I/O; late successes/errors cannot restore
  entries, reseed unseen state or complete a receipt twice. A batch does not wait for future catalog activity or a
  globally quiet inventory.
- Running projects show the shared rotating outline sparkle; unread projects
  show its static filled state. On macOS, preserve Prego's native platform-view
  path so spinning does not schedule recurring Flutter frames. Verify its
  scrolling, clipping, and collapse/expand hierarchy natively. Compact avatars
  retain the indicator. The open sidebar also writes the count beside it ("Running", "2 running"). Only
  sessions an agent is working in count; a session only waiting for input does not. Tooltips
  and accessibility descriptions include running counts and unread status;
  live state updates also clear stale unread marks.
- Recent-session rows remain non-archived even when pinning the selected session.
  A live archive update removes that row without a refetch or navigation change;
  selected non-archived sessions outside the three recent rows remain pinned.
- A selected project follows route identity, not the displayed name. Each
  signed-in cockpit owns one project-list cubit, including the home pane;
  leaving the signed-in shell releases it.
- Activity appears before projects, under an “Activity · N” header that counts its sessions, and lists only what is
  in motion: non-archived sessions that are running, or that wait on the user or are live-unseen, unless set aside. It
  spans every current project, including collapsed/offscreen projects, preserves project/session source order and
  identifies each session's project. Sessions never leave their project: an Activity session also keeps its place in
  the project's ordinary rows.
- Marking a session unread on this desktop (sidebar or sessions-page menu) sets it aside: the desktop layout file
  records its `time.updated`, and it stays out of Activity, in primary text under its project, until the agent moves that
  stamp or it runs again. Marking read records nothing. The record is per desktop and holds the newest 200.
- The Activity session the user opens stays listed after opening marks it seen, until the selection
  changes or the user sets it aside by marking it unread. The keyed header remains structurally stable at zero
  height when Activity is empty, and keyed Prego reconciliation honors reduced motion as rows enter, leave or
  reorder.
- Expanded projects show the first three active visible sessions in the shared list's order, plus the open session
  when present outside that head. While the project has more, "Show N more" (12 pt tertiary) reveals up to ten more in place; folding the
  project starts over at three. The project name is the one door to the sessions page. Compact/project collapse
  hides ordinary rows without clearing cached data or hiding that project's Activity rows; per-project collapse
  preferences survive layout restore.
- “Activity · N” and “Projects” are labelled section headers. Clicking one folds its rows; both choices
  persist in the desktop layout file, and a file without them reads as unfolded. The collapsed rail has no
  headers, so folding never hides anything there.
- Every rail button means one thing. While anything is in motion the rail leads with one Activity button:
  the sparkle, turning while a session runs, with a count pill that grows with the system text size, and a
  tooltip naming the count and only what its rows' flags say (running, awaiting input, new activity); a
  seen, idle row kept only because it is selected adds nothing. It opens the same Activity rows in a
  popout beside the rail, never over the project chips. The popout follows live state while open, keeps
  the rows' menus, and closes when a row opens its session or when its last row leaves. Below it the rail
  shows one chip per project with its sparkle badge; no session stands in as its project's initials.
- Hierarchy: project names are 14 pt medium primary; session titles are 14 pt regular secondary, and an
  unread one is primary with the sparkle. A project's add and fold controls appear only on hover or keyboard
  focus. The open session is highlighted once, on its row under its project, never in Activity or on the
  project; the project row is highlighted only on its own page. The highlight fills the row's full width.
- A project whose folder is missing shows an amber folder icon in its sidebar status slot, ahead of running and
  unread. Its tooltip and screen-reader label say "Folder not found", and its menu offers Remove instead of Hide.
- Every session row leads with a fixed status column (awaiting-input and sparkle signals) aligned under the project
  avatar and ends with a compact last-activity time; its tooltip and screen-reader label say that time in full.
  Activity rows add the project name under the title. A running session shows no time, and a row drops the time
  before its title as it narrows or as the system text size grows. A session waiting on a scheduled
  auto-continuation shows its resume time in place of the last-activity time while it is neither running
  nor waiting for the user; running and waiting keep the last-activity time (see quota-auto-continuation.md).
- Cmd+N (Ctrl+N on Windows/Linux) and the sidebar's New session row open New Session for the open project, else the
  most recently active one; with no project yet they open the New project dialog. They do nothing until the project
  inventory has loaded, and never substitute another project for an open one that is missing from the inventory.
  Cmd/Ctrl+B toggles the saved sidebar choice except during automatic narrow-window collapse, where it does nothing
  like the disabled control. Cmd/Ctrl+, opens Settings. Held-key repeats do not repeat these commands; text-field
  focus remains usable and root popups own their focus. Hints use the platform modifier; the sidebar's New session row
  shows the shortcut. Windows and Linux retain native window chrome.
- Cmd/Ctrl+K and the sidebar's Search row (under New session, labelled with the shortcut) open the command
  palette: a search field over Commands (New session once projects load, reading Add project while there
  are none; Toggle sidebar while the window is wide enough to expand it; Settings; Go back; each with its
  shortcut), the recent Sessions newest first with their project and without archived ones, and Projects.
  Typing narrows all three by title words (an untitled session by "Untitled session"), bolding the matched
  letters; signing out closes the palette with the cockpit; nothing
  matching reads "No matches". Up/Down move the highlight past headings, Enter or a click closes the palette
  and runs the pick, and Esc closes it. The highlighted row is plainly visible in both themes: a clear
  grey in light, the sidebar's selected tint in dark. Hovering a row moves the same highlight. The palette
  shows the lists as they stood when it opened. One command list in the shell drives both the palette and
  the shortcuts; page-only commands such as Mark as unread stay on their page.
- Project hover/keyboard focus reveals New session. Right-click project and
  session menus reuse the shared rename/hide and session action flows.
  Session title tooltips, selection, running/awaiting/unread signals and
  screen-reader actions remain usable at minimum width; collapsing the rail clips
  them with the row instead of overflowing it.
- Every anchored menu in the desktop app is a pointer menu, because the app installs the design system's
  pointer scope at its root: a tight rounded panel of 30-pixel rows, no dimmed window and no lifted row. A
  right-click drops the panel's top-left corner on the pointer and flips it above only when it does not fit
  below; a button press or the keyboard hangs the menu off its trigger as before. A row shows a shortcut only
  where the desktop registers a real binding for the same action. The phone installs no scope and keeps its
  long-press presentation.
- Opening the sidebar or its session action menu never claims project viewing.
  The main list/detail routes retain viewing ownership. Session mutations use
  the existing action controller and a stable sidebar presentation context. Opening a session menu first retains its
  action owner even if reconciliation removes the row/group; dismissal releases it, while selection transfers to the
  confirmation or admitted operation lease. Mark-read, rename, archive and delete finish handling before disposal.
- `ProjectInventoryService` owns project loading, refresh, mutations, live projection and catalog/reconnect handling
  independently of its presentation Cubit. The cockpit owns one factory instance; consumer replacement replays current
  data without a second load. Optimistic changes and awaited results remain synchronously visible. Disposing the
  cockpit closes the owner and fences late project-state application/unseen seeding, not merely its adapter.
  Throttled activity refresh runs only while the projects page is current; returning from another page triggers
  one immediate read without recreating a Cubit. Both shells use the shared router's topmost-page observation.
- Each winning successful project snapshot admits every current project to the scoped pure-Dart recent inventory,
  independent of expansion or viewport position. `RecentSessionInventoryService` owns admission, reads and live state;
  its Cubit only mirrors immutable snapshots and delegates explicit retry. The signed-in cockpit resolves one factory
  instance before initial project publication and disposes it on exit. A replacement Cubit sees retained data, while a
  new signed-in scope gets an empty inventory. Flutter rebuilds and project expansion dispatch no reads.
  A superseded project response cannot admit stale IDs. A successful local project hide publishes the accepted
  post-hide inventory through that same seam and fences older list responses. If a connection/reload has replaced loaded
  state before hide acceptance, one forced successor fetch replaces the superseded load and publishes its winning
  inventory. Absent IDs and their read metadata are removed; reconnect/catalog invalidation refreshes retained entries,
  including failures. Initial loading/failure stays
  project-local. Live session/activity/unread events update loaded projections.
  Loaded rows remain visible during refresh and logged refresh failures; live
  activity/unread and root lifecycle patches continue against that useful data.
  Lifecycle changes overlapping a returned snapshot trigger a coalesced fresh read before seeding.
  A response or thrown failure retains that lifecycle generation; the next loaded-inventory check
  or root lifecycle event rearms the authoritative read. Initial failures still require explicit retry.
  Closed or superseded reads cannot seed shared unseen state, and an older
  completion cannot release a newer pending read.
- The sidebar is the only navigation pane, including at minimum window width.
  All sessions, new session, detail, and diffs are sibling main-pane routes.
  Only the all-sessions page creates a full list owner; recent-session menus
  remain non-viewing action scopes.
- The all-sessions page is a toolbar over one timeline. The toolbar names the project and its repository,
  starts a New session in that project (hidden while an empty project shows the composer, and folded to its
  icon on a narrow pane or under large text), toggles Archived, and keeps Refresh and Scan for sessions in its
  overflow menu; nothing floats over the list and there is no back arrow. The shared list sits in a centred
  column about 760 pt wide while the whole pane scrolls. It has no Running section: running sessions lead
  Today. Rows are about 46 pt, use the shared row anatomy in a denser size, and highlight under the pointer.
  The phone list is the same one timeline.
- Above the active list, chips read All, Running and Unread with exact counts from the loaded list and
  narrow it locally without a request; a filter that leaves nothing says so. The chips hide while Archived
  is on, which shows every archived session, and while the project has no sessions. Hovering a row, or
  moving keyboard focus into it, swaps its time for Mark read/unread and Archive without changing the row's
  height; an archived row offers no Archive. The phone list shows the same shared chips.
- Every enabled control that acts on a click shows the hand cursor on hover: buttons, menu items, list
  rows, tiles, switches, image previews and expand toggles. A disabled control keeps the arrow. Material
  defaults to the arrow on desktop, so the Prego theme and each custom tap target opt in.
- No page toolbar has a back arrow, so every toolbar starts its content at the same left edge.
  Cmd/Ctrl+[ returns a pushed page to its opener, including child-to-parent navigation, and does nothing
  on a page reached from the sidebar. The new session and session pages lead their title with the
  project as a breadcrumb that opens the project's all-sessions page; a subtask's breadcrumb is "Main
  session" instead. Archived rows open
  read-only. New-session creation replaces its page with detail. Deleting the open session returns to
  all sessions.
- The Changes page uses the same toolbar: the project breadcrumb, the File changes title, and the file
  count with total +/− under it; Cmd/Ctrl+[ goes back to the session. Below it the changed files are a
  list on the left and the selected file's full path and diff on the right; the first file opens
  selected, choosing another shows it from its top, and a refresh stays on the selected file while it
  is still changed.
- A project page with no active sessions shows the new-session composer for that project in place of the
  timeline, under the same toolbar; Archived still shows archived sessions. A session started there opens.
- A session being archived is hidden from the sidebar, the Activity popout, the project page and its chip
  counts for as long as its Undo window or its archive request is open, and returns if the archive is
  undone, refused or fails. Archiving the open session leaves its page. See
  `session-archiving-and-deletion.md`.
- The new session page uses the same toolbar, titled New session under the project breadcrumb, above one
  centred column no wider than the session page's: the shared heading and project selector (see
  session-creation-and-options.md), the harness chooser, the input, then Dedicated workspace and
  Refresh options. The column is centred in the pane, not anchored to the bottom, and scrolls as a whole when the pane is too short.
  Choosing another project builds a fresh cubit for it.
- The session page uses the same toolbar anatomy above the transcript, never over it: the breadcrumb
  and the title share one 16 pt line and baseline, the breadcrumb medium and secondary, a slash between
  them, the title bold. The amber awaiting glyph leads the title when a question or permission waits; a
  running session instead leads it with the turning sparkle, still under reduced motion. The title
  itself never shimmers. A root session's breadcrumb is its project; a
  subtask's is "Main session", which returns to the session that started it (back to the kept parent
  page when it was opened from there). No harness or model line sits under the title. The Changes button shows
  on a root unarchived session; and a menu with
  Mark as unread labelled with its shortcut, Rename, Archive, Archive keeping the worktree when the
  session has one, and Delete, the last four run by the same dispatcher as a row's menu. Session actions
  stay disabled until the page has the hydrated session, and work for child sessions and sessions opened
  directly. Mark unread always sends unread,
  whatever local state says, defers the session like a row's Mark unread, and returns to the project's
  all-sessions page; Shift+Cmd/Ctrl+U does the same while focus is in the session page and is inert
  elsewhere. The transcript and composer sit in a centred column about 760 pt wide while the wheel and
  scrollbar keep the whole pane. The phone keeps its floating glass bar and full-width transcript.
- With projects, home starts work: the new-session composer for a picked project (the first listed until the
  user picks another, each pick with its own draft), then Needs you, Running and Recent sections across projects.
  Recent holds the five newest sessions that are neither running nor waiting; empty sections are left out. A row
  opens its session, and a session started from home opens in the picked project. Empty inventory offers
  Add/Open Project. Loading is labelled, failures retry the shared inventory,
  and disconnected states offer supervised bridge recovery without CLI setup.
  Shared Prego text styles and Material themes resolve the bundled package font.
- Connection status floats over the main pane without changing its bounds.
  Reconnecting appears after the shared grace period; connection lost retains
  Reconnect. Local desired Off, including cold-start/default Off before a user
  starts the bridge, suppresses bridge-offline copy—not relay recovery for
  clients using another bridge. Recovery hides the pill with a
  short fade; reduced motion disables it. Departing content neither intercepts
  input nor remains in accessibility announcements.
- The This computer row always exposes its supervised status through a dot and an
  accessible description. Takeover, login, start failure and crash-give-up
  recovery lives in the sidebar footer. Long repair guidance scrolls within a
  bounded card whose icon sits centred on the message's first line, with its
  extra-small buttons below: Take over for takeover, Start bridge for login,
  Retry for a start failure, and for crash give-up only, Retry (primary alt)
  beside Open logs (tertiary). In dark mode none reads as disabled. Compact mode keeps the primary action and full tooltip. Open
  Logs is also available in the This computer popover. Command locks still disable
  recovery mutations, and start failures do not offer nonexistent child logs.
- The canonical `/projects` home receives startup via `/splash` redirect and
  anchors notification route stacks; returning home retains shared inventory
  refresh. No separate project grid competes with the sidebar.
- A root popup temporarily suspends the covered session's viewed/activity claim,
  even when its nested page and typed route remain current. Dismissal restores
  visibility without replacing the session controller, element or composer.
  Notification activation dismisses root popups before revealing its session:
  the same session retains its page and Back stack; another gets the typed stack.
- This computer opens a flat, screen-clamped popover in expanded and compact modes
  without replacing the main pane. A Local bridge heading and the sidebar's
  status dot with the process status precede the actions. Start, Retry and Take
  Over are one solid button; Stop is a quiet row beside logs and configuration. A crashed helper offers Retry despite retained On intent. A
  displaced running helper also offers Stop without requiring takeover. Explicit
  Stop cannot become Start if the helper exits before dispatch. Busy states
  disable mutations, not diagnostics; Settings dismisses before opening.
  Outside click and Escape dismiss without an action. App Quit and startup
  preferences belong to application controls, not local bridge controls.
- Settings is a root modal, preserving the current route, session element and
  live composer. Sidebar/⌘, (Ctrl+, elsewhere) open General; the This computer popover
  opens Bridge; session setup opens Harnesses. All tabs and Close remain usable
  at 560 × 480, with independently scrollable tabs/content through 250% text scale and no scale reduction.
  A title-only line's natural height fits the toolbar without vertical clipping.
  Longer tab labels wrap while the tab rail itself scrolls.
  Pages draw no title bar: the tab rail names the page, and one small X at the
  top-right closes the window. The selected tab uses the main sidebar's fill.
  Theme is a Light/Dark/System segmented control that drops below its label at
  large text sizes. Bridge's connected-bridge intro sits inside its section.
  Escape/outside dismiss;
  active text editing and owned dialogs retain their closer dismissal order.
- General contains appearance, launch-at-login, desktop app-update guidance and support/legal information.
  Desktop's composer is text-only, so General does not advertise an ineffective Voice/Text preference.
  Bridge distinguishes connected-bridge configuration from local
  status/logs. Notifications exposes desktop attention, not mobile push options.
  Account owns supervised logout; failed logout stays open, and delayed success
  cannot pop the opener. External auth rejection also dismisses the root modal.
- One harness controller spans its modal overview/detail navigator. Back stays
  inside that flow; Close removes its dialogs without cancelling upstream auth.
  Only harness detail has Back; Account's title and Close do not duplicate it.
  Modal blur/dim respects Prego accessibility/quality policy; macOS uses dim
  rather than sampling native indicators. Reduced motion removes the fade.
- On macOS, home shows optional local-agent file-access guidance while the
  protected-file check is denied. Open System Settings is primary; Not now
  dismisses for this run without blocking project navigation. Bridge Settings
  retains an independently reachable This computer permission row. Focus updates
  its status; unsupported systems hide these controls and unknown is not denial.
- Missing layout uses defaults. Failed reads/writes are logged; unavailable
  storage does not prevent navigation or in-memory layout changes.

## Coverage

These levels define required checks, not claims of completed verification.
Executed checks and outstanding native/live gaps are recorded in the step evidence.

| Level | Boundary / scope | Added checks |
|---|---|---|
| L1 | Client E2E; desktop; representative bridge | Sidebar, project opening, Bridge/Settings access. |
| L2 | Automated; no plugin | See [automated checks](#automated-checks-l2). |
| L3 | Client E2E; macOS; representative live bridge | See [live macOS checks](#live-macos-checks-l3). |
| L4 | Client E2E; Windows/Linux | Resize/collapse, native-window size changes, saved-layout restore. |
| L5 | No additional coverage | Lower levels still apply. |

### Automated checks (L2)

- Optional file-access card/dismissal, narrow layout, local Settings statuses and unsupported omission.
- Project/no-project keyboard entry, nullable route-name propagation, platform modifiers, held-key repeat suppression,
  text-field/popup precedence, layout persistence, narrow-window no-op and truthful per-project hints.
- Modal tab/entry selection, keyboard entry, route/element/draft preservation, nested Back/Close,
  text-edit/dialog Escape order, logout failure/late completion/auth rejection, every tab and Close at minimum size
  with 100%/200%/250% text. Use packaged fonts for geometry checks; preserve the requested text scaler.
- Root-popup activity visibility across nested navigators; notification popup dismissal,
  same-page/Back preservation, different-session replacement, readiness and logged-failure ordering.
- Popover scope/contextual actions, locks/live updates, explicit Stop intent, expanded/compact anchoring,
  outside/Escape dismissal, preserved main pane.
- Floating panel geometry expanded and collapsed: window inset, main-pane offset, the resize gap and its absence
  beside the rail, no divider.
- Unified macOS title bar: the title bar style per platform, the panel's top edge and its first control
  expanded and as a rail on macOS, drag and double-click zoom on the room above that control and on the
  strip above the rail, the top band's drag that leaves a jiggling click alone and fires once under a
  zooming region, the signed-out window moved from the app's root, logged host failures, the list's clipped
  highlights, and the native brightness pushed once per effective change, including a system switch.
- Pointer menus: no spotlight, the panel's corner on the pointer and its flip above it, 30-pixel rows with the
  shortcut label, a button-opened menu still hung off its trigger, the touch presentation where no scope
  exists, and the desktop app installing the pointer scope.
- Rail Activity button count and tooltip (including a sticky-only count that claims nothing new, and its
  pill under larger text), one chip per project, popout placement beside the rail, rows that stay live
  with the cockpit's cubits mounted below the root navigator, and dismissal when a row opens its session
  or the last row leaves.
- Connection grace, pill visibility, fixed content geometry, reduced motion, departing hit testing/semantics,
  sidebar recovery/actions/locks.
- The session page toolbar above a centred transcript column: the breadcrumb, status slot and title styles
  and order, the breadcrumb opening the project or, for a subtask, "Main session" returning to its parent
  (popping to the kept parent when opened from it, opening the parent otherwise), the sparkle leading
  the title only while the session runs, session actions disabled until the session is hydrated,
  Mark unread sending unread and leaving the page from the menu (which shows its shortcut) and from
  Shift+Cmd/Ctrl+U, and a menu without Mark as read.
- The command palette opened by Cmd/Ctrl+K and the Search row: recency order with project names, filtering
  with No matches, Enter opening a session or project, Down skipping a heading, Esc, and a command run from
  the palette and by its shortcut (`desktop_cockpit_shell_test`).
- Cmd/Ctrl+[ popping a pushed page and doing nothing on a direct one; the new session and session
  breadcrumbs opening the project's sessions.
- Filter chip counts, local narrowing, the filtered-empty message and chips hidden under Archived; hover and
  focus revealing row actions that call the row's handlers at a stable height, with no Archive on an
  archived row.
- The new session page: toolbar above a centred, width-capped column with room left below it, and the
  project selector reporting the chosen project (`desktop_new_session_screen_test`).
- The all-sessions page: toolbar title and New session button (hidden beside the empty-project composer,
  icon-only on a narrow pane under large text, without overflow), Archived toggle state, no floating button, the
  timeline grouping with running sessions first under Today, and pointer-mode row height. With no active sessions
  it shows the composer and the catalog scan row instead, keeps the composer until a started session opens even
  when the list shows it first, and shows no composer under Archived (`desktop_session_list_screen_test`).
- Flat typed route registration, no-back all-sessions presentation, archived read-only navigation,
  new-session replacement, Changes breadcrumb and file selection, home states, package-font resolution.
- Recent ordering/pinning, live inventory mutations, action-scope viewing isolation, invalidation/disposal,
  project-collapse and section-fold persistence, Show more paging and its reset, a row's compact time with its
  spoken form and its drop under larger text, shared menu/route callbacks. All-project admission happens once per
  entering ID, including collapsed/offscreen projects; Activity keeps project context, selection/navigation/actions,
  leaves project rows in place, honors set-aside and just-opened sessions, and reconciles keyed entry/exit under
  reduced motion. Empty/loading/failed entries preserve the stable header and project-local retry. Keep loaded rows
  through catalog/reconnect refreshes and failures, including live unread false, lifecycle patches, failed-reread
  rearming and superseded-read completion. Execute those inventory cases without a mounted Cubit. Verify adapter
  replay/retry, independent consumer close, one eager factory instance per signed-in scope, and disposal before a
  fresh scope admits data.
- Headless explicit refresh ordering, shared-instance factory parameters, admission joining, completed failed winners,
  later owning reads, partial failure, removal/disposal and useful diagnostic causes. Presentation covers keyboard
  activation, accessible busy/idle names, disabled states, useful-row retention and success/failure notices.
- Width clamp, anchored overshoot/reversal at both bounds, admitted drag-end/cancel and reset-only persistence,
  visible-scrollbar edge hit tests and thumb dragging, intermediate collapse/expand frames with cramped
  session-row signals, both reduced-motion signals, temporary narrow-window mode, running/unread updates
  in both widths, Unicode initials, JSON round-trip, storage failure fallback.

### Live macOS checks (L3)

- Right-click menus on sidebar projects and sessions and on list rows: they open at the pointer without
  dimming the window, flip near the window's bottom edge, highlight the hovered row, and close on an outside
  click or Escape.
- Fresh-account autostart, login-item registration, optional Full Disk Access grant/deny/focus-return
  and helper inheritance.
- Settings entries/tabs, native startup preference, dialog keyboard/backdrop/accessibility and retained composer.
- Popover Start/Stop/Retry, Take Over versus Stop, logs and Settings.
- Relay drop/reconnect and intentional-Off presentation, sidebar recovery, resize feel, hover and selected rows.
- The floating panel in light and dark: rounded corners, border and shadow with no hard edge against the page.
- The unified macOS title bar: the traffic lights on the expanded panel above New session and above the
  rail, dragging by the room beside the lights, by a page toolbar and by the top of the login screen,
  double-click zoom, full screen in and out with no bar over the content, a highlighted row scrolled under
  the panel's top, and the chrome's brightness under light, dark and System, including a system appearance
  switch after a forced value. Windows and Linux keep native chrome.
- Keyboard focus, compact tooltips, relaunch persistence, light/dark appearance,
  recent-session navigation/actions on a live bridge, and native indicator scrolling/clipping
  through the tree and menus.

## Failure Signals And Exploration

Audit rendered content as well as action availability: purpose, concise labels, grouping, scope and state-correct
primary actions. Inspect light/dark, compact/expanded and minimum-window output with the actual packaged fonts.
Keep app preferences and updates in General, local supervision in This computer, and remote configuration distinct.
Synthetic rendering does not qualify native accessibility, compositing, keyboard handling or live bridge operations.

Look for overflow at minimum width, drag updates that stall or write per frame,
width jumping on reversal beyond a bound, scrollbars intercepting project toggles,
automatic collapse overwriting user preferences, missing/stale activity marks,
duplicate project inventories, a session leaving its project's rows for Activity, a deliberately unread session
returning to Activity without new agent output, an opened Activity session vanishing under the pointer, repeated
admission on rebuild/expansion, a folded section hiding its rows in the collapsed rail, session chips posing as
projects in the rail, a rail Activity popout that is empty, stale, over the rail or throws for a missing provider, a
divider or square corners on the sidebar panel, a resize handle beside the fixed rail, lost project
context, a shifting empty Activity header, a second session-list pane, sidebar browsing clearing unread state,
stale/missing recent rows, a refresh reporting success from old retained data, an indicator settling before its
owning reads, duplicate refresh dispatch, unnamed icon controls, covered transcripts marked viewed,
notification opens stranded behind a popup,
wrong session-action targets, or lost navigation after switching projects. Vary project-name lengths and
Unicode, window sizes, theme, and sidebar width; preserve any already-running
bridge during UI-only checks.

On home, watch for a session starting in a project other than the one picked, a draft following a project
reorder or surviving a new pick, a running or waiting session under Recent, and an empty section heading.

## Maintenance Sources

- `client/desktop/lib/core/widgets/desktop_cockpit_shell.dart`
- `client/desktop/lib/core/widgets/desktop_sidebar.dart`
- `client/desktop/lib/core/widgets/desktop_window_drag_area.dart`
- `client/desktop/lib/core/widgets/desktop_window_brightness.dart`
- `client/desktop/lib/core/platform/flutter_window_host.dart`
- `client/desktop/macos/Runner/MainFlutterWindow.swift`
- `client/module_desktop_core/lib/src/foundation/platform/window_host.dart`
- `client/module_desktop_core/lib/src/services/desktop_sidebar_refresh_service.dart`
- `client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_refresh_cubit.dart`
- `client/desktop/lib/core/widgets/desktop_connection_pill.dart`
- `client/desktop/lib/core/widgets/desktop_bridge_recovery_card.dart`
- `client/desktop/lib/core/widgets/desktop_bridge_popover.dart`
- `client/desktop/lib/core/routing/desktop_router.dart`
- `client/desktop/lib/core/platform/desktop_route_dispatcher.dart`
- `client/module_app_ui/lib/src/features/session_detail/session_detail_activity_owner.dart`
- `client/desktop/lib/features/home/desktop_home_pane.dart`
- `client/desktop/lib/features/settings/desktop_settings_modal.dart`
- `client/desktop/test/features/settings/desktop_settings_screens_test.dart`
- `client/module_prego/lib/interactions/prego_interaction_scope.dart`
- `client/module_prego/lib/components/menus/prego_anchor_menu.dart`
- `client/module_prego/lib/components/menus/anchored_flat_panel.dart`
- `client/module_prego/test/components/prego_anchor_menu_test.dart`
- `client/module_prego/lib/components/navigation/prego_nav_title.dart`
- `client/module_prego/test/components/prego_nav_title_test.dart`
- `client/desktop/lib/features/sessions/desktop_session_list_screen.dart`
- `client/desktop/test/features/sessions/desktop_session_list_screen_test.dart`
- `client/module_core/lib/src/cubits/recent_sessions/`
- `client/module_core/lib/src/cubits/session_list/session_list_mode.dart`
- `client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_cubit.dart`
- `client/module_desktop_core/test/cubits/desktop_sidebar_cubit_test.dart`
- `client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart`
- `.plan/completed/desktop-ux/PLAN.md`
