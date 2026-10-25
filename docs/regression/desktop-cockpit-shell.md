# Desktop Cockpit Shell

## Capability

Desktop navigation in a resizable sidebar that floats as a panel over the page and hides completely when
collapsed, with desktop-owned layout preferences. The sidebar shows the shared all-projects session list under
its project filter; the home pane reads the same signed-in project inventory and the list's default project.
The main pane hosts one full-width routed page.

## Required Behavior

- The sidebar floats as a panel over the base surface the pages
  paint: inset 8 pixels from the window's top, bottom and start edges, with
  14-pixel corners, a hairline border and a soft shadow, and no divider. The
  panel clips its footer. An 8-pixel gap separates it from the main pane, which
  therefore starts 16 pixels past the panel's width. That gap is the resize handle, with a resize cursor and no
  visible line. Width bounds measure the panel itself.
- macOS hides the native title bar and keeps its traffic lights; Windows and Linux keep their native chrome.
  The macOS runner gives the window an empty unified toolbar, so AppKit itself sets the lights lower and
  further in: the expanded panel keeps its 8 pixel inset and carries them above its first control, which
  starts 42 pixels from the window's top. The room the panel leaves for the lights drags the window and zooms
  it on a double click. With the sidebar hidden the lights sit over the page's toolbar band, and the restore
  button starts 80 pixels in, past them. In full screen the runner hides that toolbar, which AppKit
  would otherwise draw as a bar over the content's top, and restores it on exit. The window's top 54 pixels,
  the band a page toolbar fills, drag it on every screen, the signed-out login included: a press becomes a
  drag only after it travels further than a click tolerates, so toolbar controls keep their clicks,
  undelayed, and a text selection or a scrollbar still wins its own press. Where the band and a zooming
  region overlap, one press still reaches the host once.
- The sidebar's footer is one 44-point row: This computer, then Archived, Settings and collapse, with the
  bridge recovery card above it when one applies. Refresh sits beside the project filter at the head of the
  list. The session list clips its rows' highlights, so a highlighted row scrolled under the section above
  never shows through it.
- The native window chrome is forced to the app's effective brightness (the in-app mode, or the system's
  while the app follows it) and again on every change, because a host can only be forced light or dark.
  Chrome and content therefore never disagree, including after the system switches appearance while the
  app follows it.
- Expanded width defaults to 260 logical pixels and clamps to 200–420. Dragging
  uses the starting width plus global pointer displacement, preserving overshoot
  when reversing beyond either bound. Changes are immediate; an admitted drag
  saves once on completion/cancellation, and double-click reset saves once.
  Idle gesture cancellation does not write; explicit sidebar collapse toggles do.
- Collapse hides the sidebar completely: the panel and its resize gap slide out past the window's start edge
  in 220 ms while the page widens into their room, and the panel never squeezes its rows on the way. A restore
  button fades in at the page's top-left, centred in the 54-pixel toolbar band; page toolbars and the home's
  Viewing header move their content past it while it shows, and it slides just ahead of that content, never
  over it. The button and Cmd/Ctrl+B bring the sidebar back
  at the saved width. Hidden, the sidebar keeps its list and scroll offset but leaves the focus order and the
  screen reader. Reduced motion removes the slide without delaying drag feedback.
- Windows narrower than 760 pixels temporarily hide the sidebar without changing saved preferences; the
  restore button shows disabled and Cmd/Ctrl+B does nothing, so the palette reaches sessions there. Widening
  restores the user's choice. The native minimum window remains 560 × 480.
- New session is a quiet row at the top of the sidebar, with its shortcut at the row's end; with no projects it
  reads Add project and opens the shared folder dialog, and the project it adds opens in New session. Search under it opens the command palette. Below them
  the project filter, "All projects ▾" or the chosen project's name, heads the shared all-projects session list
  beside Refresh: it opens the shared project picker, and its pick is the shared filter that lasts for the app's
  run. The list is the phone's (see `projects-and-sessions.md`): its search field, All, Running and Unread
  chips, date headings with running sessions leading Today, launching rows, the catalog scan row and
  project-local retry. Each row names its project while the filter shows all of them, and opens its session in
  that project; the open session is highlighted. Adding a project otherwise lives on home and in Settings ›
  Projects. Icon/status hints and truncated-label hints remain useful, while fully visible labels need no
  duplicate tooltip.
- Explicit sidebar refresh runs through `SessionListRefreshCubit` and the shared `SessionListRefreshService` over the
  same scoped project and recent inventory services, and starts the all-harness import beside the reload. The cockpit
  shows no import progress row; a failed import raises the shared alert naming its harnesses. It awaits the project
  phase before refreshing admitted recent entries, joining initial reads
  already in flight. An ordinary project failure still allows retained recent entries to update; either phase failing
  produces failure feedback. Useful rows stay visible. Busy controls cannot dispatch duplicate intent, and busy/idle
  refresh plus Settings expose accessible names and keyboard actions.
  A superseded caller follows the current owning read after every completion, including an already-completed successor
  followed by a newer owner. Completed failures stay observable despite retained rows. During the recent-session phase,
  removal or disposal retires pending receipts without waiting for obsolete I/O; late successes/errors cannot restore
  entries, reseed unseen state or complete a receipt twice. A batch does not wait for future catalog activity or a
  globally quiet inventory.
- Each signed-in cockpit owns one project-list cubit, including the home pane;
  leaving the signed-in shell releases it.
- Cmd+N (Ctrl+N on Windows/Linux) and the sidebar's New session row open New Session for the open project, else the
  sidebar's filtered project, else the most recently active one; with no project yet they open the New project
  dialog. They do nothing until the project
  inventory has loaded, and never substitute another project for an open one that is missing from the inventory.
  Cmd/Ctrl+B toggles the saved sidebar choice except during automatic narrow-window collapse, where it does nothing
  like the disabled control. Cmd/Ctrl+, opens Settings. Held-key repeats do not repeat these commands; text-field
  focus remains usable and root popups own their focus. Hints use the platform modifier; the sidebar's New session row
  shows the shortcut. Windows and Linux retain native window chrome.
- Cmd/Ctrl+K and the sidebar's Search row (under New session, labelled with the shortcut) open the command palette: a
  search field over Commands (New session once projects load, reading Add project while there are none; Toggle sidebar
  while the window is wide enough to expand it; Settings; Go back; each with its shortcut), the Sessions the sidebar's
  list shows (under its filter, search and chip) newest first with their project, and every Project. Typing narrows all three by title words (an untitled
  session by "Untitled session"), bolding the matched letters; signing out closes the palette with the cockpit; nothing
  matching reads "No matches". Up/Down move the highlight past headings, Enter or a click closes the palette and runs
  the pick, and Esc closes it. A session pick opens it; a project pick filters the sidebar's list to that project and
  brings a collapsed sidebar back to show it. The highlighted row is plainly visible in both themes: a clear grey in
  light, the sidebar's selected tint in dark. Hovering a row moves the same highlight. The palette shows the lists as
  they stood when it opened. One command list in the shell drives both the palette and the shortcuts; page-only commands
  such as Mark as unread stay on their page.
- Right-click session menus on the sidebar's rows reuse the shared session action flows, and session title
  tooltips, selection, running/awaiting/unread signals and screen-reader actions remain usable at the
  sidebar's minimum width.
- Every anchored menu in the desktop app is a pointer menu, because the app installs the design system's
  pointer scope at its root: a tight rounded panel of 30-pixel rows, no dimmed window and no lifted row. A
  right-click drops the panel's top-left corner on the pointer and flips it above only when it does not fit
  below; a button press or the keyboard hangs the menu off its trigger as before. A row shows a shortcut only
  where the desktop registers a real binding for the same action. The phone installs no scope and keeps its
  long-press presentation.
- Filtered to one project, the sidebar's list claims that project's viewing once its sessions load, as the
  phone's list does; All projects claims nothing, since the bridge is told one project. The cockpit reports the
  open sidebar as the visible list pane, so the new session and Changes pages keep that claim only while the
  sidebar shows. A session action menu never claims
  project viewing. Session mutations use the existing action controller and a stable sidebar presentation
  context. Opening a session menu first retains its
  action owner even if reconciliation removes the row/group; dismissal releases it, while selection transfers to the
  confirmation or admitted operation lease. Mark-read, rename, archive and delete finish handling before disposal.
- `ProjectInventoryService` owns project loading, refresh, mutations, live projection and catalog/reconnect handling
  independently of its presentation Cubit. The cockpit owns one factory instance; consumer replacement replays current
  data without a second load. Optimistic changes and awaited results remain synchronously visible. Disposing the
  cockpit closes the owner and fences late project-state application/unseen seeding, not merely its adapter.
  Throttled activity refresh runs only while the home is current; returning from another page triggers
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
- The sidebar is the only navigation pane. The home, archived sessions, new session, detail, and diffs
  are sibling main-pane routes. The sidebar's shared list is the only full list owner; session action menus
  remain non-viewing action scopes.
- The footer's Archived opens the Archived sessions page over the current page: the shared archived list across
  projects, read through the sidebar's shared project filter, with each row naming its project. It never claims
  project viewing. A row opens its session read-only over Archived, so Cmd/Ctrl+[ returns to it; the page's close
  returns to the page it opened over, or home when there is none, and pressing Archived while it is the top page
  does nothing. While the computer is disconnected it lists nothing, and the connection pill and the footer's recovery
  card say why.
- Hovering a list row, or moving keyboard focus into it, swaps its time for Mark read/unread and Archive
  without changing the row's height; an archived row offers no Archive.
- Every enabled control that acts on a click shows the hand cursor on hover: buttons, menu items, list
  rows, tiles, switches, image previews and expand toggles. A disabled control keeps the arrow. Material
  defaults to the arrow on desktop, so the Prego theme and each custom tap target opt in.
- No page toolbar has a back arrow, so every toolbar starts its content at the same left edge.
  Cmd/Ctrl+[ returns a pushed page to its opener, including child-to-parent navigation, and does nothing
  on a page reached from the sidebar; New session reached directly goes back to the home. No page title
  carries a project crumb; a subtask's title leads with a "Main session" crumb instead. Archived rows open
  read-only. New-session creation replaces its page with detail. Deleting or archiving the open session
  returns to the home.
- The Changes page uses the same toolbar: the File changes title and the file
  count with total +/− under it; Cmd/Ctrl+[ goes back to the session. Below it the changed files are a
  list on the left and the selected file's full path and diff on the right; the first file opens
  selected, choosing another shows it from its top, and a refresh stays on the selected file while it
  is still changed.
- A session being archived is hidden from the sidebar and its chip
  counts for as long as its Undo window or its archive request is open, and returns if the archive is
  undone, refused or fails. Archiving the open session leaves its page. See
  `session-archiving-and-deletion.md`.
- The new session page uses the same toolbar, titled New session, above one
  centred column no wider than the session page's composer: the shared heading and project selector (see
  session-creation-and-options.md), the harness chooser, the input, then Dedicated workspace and
  Refresh options. The column is centred in the pane, not anchored to the bottom, and scrolls as a whole when the pane is too short.
  Choosing another project builds a fresh cubit for it.
- The session page uses the same toolbar anatomy above the transcript, never over it. A subtask's "Main
  session" crumb and the title share one 16 pt line and baseline, the crumb medium and secondary, a slash
  between them, the title bold; the crumb returns to the session that started it (back to the kept parent
  page when it was opened from there). A root session's title stands alone. The amber awaiting glyph leads
  the title when a question or permission waits; a running session instead leads it with the turning
  sparkle, still under reduced motion. The title itself never shimmers. No harness or model line sits under the title. The Changes button shows
  on a root unarchived session; and a menu with
  Mark as unread labelled with its shortcut, Rename, Archive, Archive keeping the worktree when the
  session has one, and Delete, the last four run by the same dispatcher as a row's menu. Session actions
  stay disabled until the page has the hydrated session, and work for child sessions and sessions opened
  directly. Mark unread always sends unread,
  whatever local state says, and returns to the home; Shift+Cmd/Ctrl+U does the same while focus is in the session page and is inert
  elsewhere. The transcript and the composer sit in two separately sized centred columns, the transcript
  about 960 pt wide and the composer, its pills and the needs-you cards about 760 pt, both centred in the
  same pane while the wheel and scrollbar keep the whole pane. A window too narrow for a column collapses
  that column's margin instead of clipping it. The transcript column stays narrow enough that a revealed
  timestamp gutter still fits inside the designed window; past that width the peek degrades to the phone's
  behaviour during the drag rather than breaking, and a settled label is never cut. The phone keeps its
  floating glass bar and one full-width transcript and composer.
- Home is the new-session composer alone, in the sidebar list's default project (its filter, else the newest
  session's project), as `session-creation-and-options.md` details: the project holds once it lands, another
  filter or a header pick moves it with its own draft, a still-loading list leaves the pane blank, and with no
  default the shared "Choose a project" prompt shows instead, offering only "Open another folder…" when there are
  no projects. A session started from home opens in its project. Loading projects is labelled and failures retry
  the shared inventory. A disconnected home branches on
  the computer being viewed: this computer's own bridge (or an unknown target) offers supervised recovery without
  CLI setup; another computer shows the phone's offline body instead: "<computer> is offline" (the generic
  "Bridge offline" until the list names it), its last-seen time when the list has one, a line to start the
  bridge on that computer, and the shared Other computers card, with no Start button.
- Home opens with a "Viewing: <computer> ▾" header ("Viewing: This computer" for the local one) whose anchored
  menu switches computers through the shared switch flow (source `menu`). It is hidden while the account's only
  computer is this one, grows into place when the list says otherwise, and stays put while the body below changes
  state. The desktop starts on the stored pick, else this computer when its bridge id is known; a fresh install
  connects to the relay's default computer until its helper registers. Each sign-in pins this computer again when
  nothing is stored. The desktop follows this computer's supervised bridge when its id appears or changes (a fresh
  install, a new login, a re-registration) unless the user picked another computer in this sign-in; picking this
  computer, or signing out, ends that. The local bridge keeps running while another computer is viewed. The
  capability as a whole is in [multi-computer](multi-computer.md).
  Shared Prego text styles and Material themes resolve the bundled package font.
- Connection status floats over the main pane without changing its bounds.
  Reconnecting appears after the shared grace period; connection lost retains
  Reconnect until a reconnect starts, which clears it. Local desired Off, including cold-start/default Off before a user
  starts the bridge, suppresses bridge-offline copy—not relay recovery for
  clients using another bridge. Recovery hides the pill with a
  short fade; reduced motion disables it. Departing content neither intercepts
  input nor remains in accessibility announcements.
- The This computer row always exposes its supervised status through a dot and an
  accessible description. Takeover (another copy of this computer's own bridge, here or on a cloned machine;
  another computer never causes it), login, start failure and crash-give-up
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
- This computer opens a flat, screen-clamped popover from the sidebar's footer
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
  Desktop's composer always leads with text (the mic is an extra click-to-talk control), so General does not
  advertise an ineffective Voice/Text preference.
  Bridge distinguishes connected-bridge configuration from local
  status/logs. Notifications exposes desktop attention, not mobile push options.
  Projects, after Harnesses, lists the cockpit's own project list with the shared Settings › Projects page
  (see `projects-and-sessions.md`); its folder browser opens over the settings window, which stays open. The
  Bridge tab has no Projects row, since the tab rail already names the page.
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
- The saved layout is the sidebar's width and its collapse choice; a stored key the build does not know is
  ignored. Missing layout uses defaults. Failed reads/writes are logged; unavailable
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
  text-field/popup precedence, layout persistence, narrow-window no-op, and New session following the open
  project, else the sidebar's filter, else the most recent one.
- Modal tab/entry selection, keyboard entry, route/element/draft preservation, nested Back/Close,
  text-edit/dialog Escape order, logout failure/late completion/auth rejection, every tab and Close at minimum size
  with 100%/200%/250% text. Use packaged fonts for geometry checks; preserve the requested text scaler.
- Home computer header shown, hidden for a lone local computer, and switching from its menu; disconnected home
  for a remote target (offline body, other computers, no Start) versus this computer (supervised Start); the
  desktop target following a new or changed supervised bridge id unless another computer was picked in this
  sign-in; header and body agreeing on "this computer" before the supervised id is known.
- Root-popup activity visibility across nested navigators; notification popup dismissal,
  same-page/Back preservation, different-session replacement, readiness and logged-failure ordering.
- Popover scope/contextual actions, locks/live updates, explicit Stop intent, footer anchoring,
  outside/Escape dismissal, preserved main pane.
- Floating panel geometry open and hidden: window inset, main-pane offset, the resize gap and its absence while
  hidden, no divider; the restore button's place in the toolbar band and the room a page toolbar leaves it.
- Unified macOS title bar: the title bar style per platform, the panel's top edge and its first control
  on macOS, drag and double-click zoom on the room above that control, the restore button past the
  lights while the sidebar is hidden, the top band's drag that leaves a jiggling click alone and fires once under a
  zooming region, the signed-out window moved from the app's root, logged host failures, the list's clipped
  highlights, and the native brightness pushed once per effective change, including a system switch.
- Pointer menus: no spotlight, the panel's corner on the pointer and its flip above it, 30-pixel rows with the
  shortcut label, a button-opened menu still hung off its trigger, the touch presentation where no scope
  exists, and the desktop app installing the pointer scope.
- The sidebar's shared list across projects, a row opening its session in its own project, the filter
  narrowing the list and returning to All projects, project-local retry, the list hearing whether the sidebar
  shows it through collapse, restore and narrow windows, and a filtered sidebar declaring its project again
  once a project page's list claim is released (`desktop_cockpit_shell_test`).
- Connection grace, pill visibility, fixed content geometry, reduced motion, departing hit testing/semantics,
  sidebar recovery/actions/locks.
- The session page toolbar above a centred transcript column wider than the centred composer's: a subtask's crumb,
  status slot and title styles and order, its "Main session" crumb returning to its parent
  (popping to the kept parent when opened from it, opening the parent otherwise), the sparkle leading
  the title only while the session runs, session actions disabled until the session is hydrated,
  Mark unread sending unread and leaving the page from the menu (which shows its shortcut) and from
  Shift+Cmd/Ctrl+U, and a menu without Mark as read.
- The command palette opened by Cmd/Ctrl+K and the Search row: recency order with project names, filtering
  with No matches, Enter opening a session or filtering the sidebar to a project and bringing it back,
  Down skipping a heading, Esc, and a command run from
  the palette and by its shortcut (`desktop_cockpit_shell_test`).
- Cmd/Ctrl+[ popping a pushed page and doing nothing on a direct one; New session reached directly, Mark unread,
  and deleting or archiving the open session all returning to the home (`desktop_router_test`).
- The new session page: toolbar above a centred, width-capped column with room left below it, no project crumb,
  and the project selector reporting the chosen project (`desktop_new_session_screen_test`).
- Flat typed route registration, archived read-only navigation,
  new-session replacement, Changes file selection, home states, package-font resolution.
- Add project from the sidebar's empty New session row opening New session in the added project
  (`desktop_cockpit_shell_test`).
- The footer's Archived control (`desktop_cockpit_shell_test`); the Archived page pushed once over its opener, its
  rows opening read-only over it, and its close returning to the opener or, reached directly, home
  (`desktop_router_test`).
- Live inventory mutations, action-scope viewing isolation, invalidation/disposal. All-project admission happens
  once per entering ID, including offscreen projects. Empty/loading/failed entries keep project-local retry. Keep
  loaded rows
  through catalog/reconnect refreshes and failures, including live unread false, lifecycle patches, failed-reread
  rearming and superseded-read completion. Execute those inventory cases without a mounted Cubit. Verify adapter
  replay/retry, independent consumer close, one eager factory instance per signed-in scope, and disposal before a
  fresh scope admits data.
- Headless explicit refresh ordering, shared-instance factory parameters, admission joining, completed failed winners,
  later owning reads, partial failure, removal/disposal and useful diagnostic causes. Presentation covers keyboard
  activation, accessible busy/idle names, disabled states, useful-row retention and success/failure notices.
- Width clamp, anchored overshoot/reversal at both bounds, admitted drag-end/cancel and reset-only persistence,
  intermediate collapse/restore frames with the panel sliding whole, both reduced-motion signals, temporary
  narrow-window mode, JSON round-trip with an unknown key ignored, storage failure fallback.

### Live macOS checks (L3)

- Right-click menus on sidebar sessions and on list rows: they open at the pointer without
  dimming the window, flip near the window's bottom edge, highlight the hovered row, and close on an outside
  click or Escape.
- Fresh-account autostart, login-item registration, optional Full Disk Access grant/deny/focus-return
  and helper inheritance.
- Settings entries/tabs, native startup preference, dialog keyboard/backdrop/accessibility and retained composer.
- Popover Start/Stop/Retry, Take Over versus Stop, logs and Settings.
- Viewing a remote computer from the home header while the local bridge keeps serving a phone, and the remote
  offline body when that computer's bridge stops.
- Relay drop/reconnect and intentional-Off presentation, sidebar recovery, resize feel, hover and selected rows.
- Archived from the footer: the page fades in over the open page, a row opens read-only, Cmd/Ctrl+[ comes back,
  and the close returns to the opener.
- The floating panel in light and dark: rounded corners, border and shadow with no hard edge against the page.
- Collapse and restore by the footer button, the restore button and Cmd/Ctrl+B: the panel slides whole while
  the page widens or narrows with no jump in what it shows, and the restore button fades in past the traffic
  lights. The filter popover narrowing the list and back, and a project picked in the palette.
- The unified macOS title bar: the traffic lights on the open panel above New session and beside the restore button
  while it is hidden, dragging by the room beside the lights, by a page toolbar and by the top of the login screen,
  double-click zoom, full screen in and out with no bar over the content, a highlighted row scrolled under the panel's
  top, and the chrome's brightness under light, dark and System, including a system appearance switch after a forced
  value. Windows and Linux keep native chrome.
- Keyboard focus, compact tooltips, relaunch persistence, light/dark appearance,
  recent-session navigation/actions on a live bridge, and native indicator scrolling/clipping
  through the list and menus.

## Failure Signals And Exploration

Audit rendered content as well as action availability: purpose, concise labels, grouping, scope and state-correct
primary actions. Inspect light/dark, open/hidden sidebar and minimum-window output with the actual packaged fonts.
Keep app preferences and updates in General, local supervision in This computer, and remote configuration distinct.
Synthetic rendering does not qualify native accessibility, compositing, keyboard handling or live bridge operations.

Look for overflow at minimum width, drag updates that stall or write per frame,
width jumping on reversal beyond a bound, automatic collapse overwriting user preferences, missing/stale
activity marks, duplicate project inventories, repeated admission on rebuild, a page that jumps while the
sidebar slides, a panel that squeezes its rows, a restore button under the traffic lights or over a toolbar's
content, a divider or square corners on the sidebar panel, lost project context, a second session-list pane,
sidebar browsing clearing unread
state,
stale/missing recent rows, a refresh reporting success from old retained data, an indicator settling before its
owning reads, duplicate refresh dispatch, unnamed icon controls, covered transcripts marked viewed,
notification opens stranded behind a popup,
wrong session-action targets, or lost navigation after switching projects. Vary project-name lengths and
Unicode, window sizes, theme, and sidebar width; preserve any already-running
bridge during UI-only checks.

On home, watch for a session starting in a project other than the one picked, a draft following a project
reorder or surviving a new pick, the composer moving when a session elsewhere turns newest, a jump or flash of
the prompt while the list loads on launch, a Start button
offered for another computer, a header that pops in on each load, or the desktop jumping back to this computer
after the user picked another one.

## Maintenance Sources

- `client/desktop/lib/core/widgets/desktop_cockpit_shell.dart`
- `client/desktop/lib/core/widgets/desktop_sidebar.dart`
- `client/desktop/lib/core/widgets/desktop_sidebar_expansion.dart`
- `client/desktop/lib/core/widgets/desktop_page_toolbar.dart`
- `client/desktop/lib/core/widgets/desktop_command_palette.dart`
- `client/module_app_ui/lib/src/features/session_list/all_sessions_list.dart`
- `client/module_app_ui/lib/src/features/project_picker/project_picker.dart`
- `client/module_core/lib/src/cubits/all_sessions/all_sessions_cubit.dart`
- `client/module_core/lib/src/services/project_viewing_service.dart`
- `client/desktop/lib/core/widgets/desktop_window_drag_area.dart`
- `client/desktop/lib/core/widgets/desktop_window_brightness.dart`
- `client/desktop/lib/core/platform/flutter_window_host.dart`
- `client/desktop/macos/Runner/MainFlutterWindow.swift`
- `client/module_desktop_core/lib/src/foundation/platform/window_host.dart`
- `client/module_core/lib/src/services/session_list_refresh_service.dart`
- `client/module_core/lib/src/cubits/session_list/session_list_refresh_cubit.dart`
- `client/module_app_ui/lib/src/widgets/session_scope.dart`
- `client/desktop/lib/core/widgets/desktop_connection_pill.dart`
- `client/desktop/lib/core/widgets/desktop_bridge_recovery_card.dart`
- `client/desktop/lib/core/widgets/desktop_bridge_popover.dart`
- `client/desktop/lib/core/routing/desktop_router.dart`
- `client/desktop/test/core/routing/desktop_router_test.dart`
- `client/module_app_ui/lib/src/features/session_list/archived_sessions_view.dart`
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
- `client/module_core/lib/src/cubits/recent_sessions/`
- `client/module_desktop_core/lib/src/cubits/desktop_sidebar/desktop_sidebar_cubit.dart`
- `client/module_desktop_core/test/cubits/desktop_sidebar_cubit_test.dart`
- `client/desktop/test/core/widgets/desktop_cockpit_shell_test.dart`
- `.plan/completed/desktop-ux/PLAN.md`
