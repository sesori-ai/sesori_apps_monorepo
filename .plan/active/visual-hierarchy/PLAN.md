# Visual Hierarchy — one calm, legible product on both apps

## Status

- **Plan slug:** `visual-hierarchy`
- **Status:** Active. Step 1 raises this plan.
- **Plan date:** 2026-09-23
- **Repository:** `sesori-ai/sesori_apps_monorepo`, implementation base `main`
  at `a845f1434c`.
- **Delivery:** 38-step PR series titled
  `<emoji> [visual-hierarchy] <description> [step <x>/38]`. Exact titles and
  branches are in [TRACKER](TRACKER.md#pr-titles).
- **Order:** steps 2–34 need no further input from the user and run first.
  Step 35 waits for the user to scope the sign-in rebuild, and step 36 for
  their approval of screenshots (D16). Steps 37–38 close the series.
- **Sources:** the user's verdicts on the round 1 UI review and on the motion
  review, their answers to the follow-up questions, and their round 2 answers
  of 2026-09-23 (D19–D23; [TRACKER](TRACKER.md#round-2-answers)). The review
  pages and every screenshot are private and stay local under
  `/tmp/sesori-ux/`; nothing from them is committed.

## Goal

Both apps read as one designed product with a clear hierarchy: one title
ladder, greys you can read, one meaning per colour, rows that lead with status,
and chrome that steps back so content leads. The transcript shows real,
continuous progress instead of a wall of tool cards. The missing everyday tools
arrive: search on the phone, a command palette on the desktop, an Activity
group on the phone, a file list in Changes, and a visible failure when a send
fails.

## Scope

In scope: the 63 items the user marked "Worth doing", the three motion-review
changes (desktop page fade, one modal entry point, anchored pickers), and three
follow-ups the user raised or approved (tool detail expansion animates, the
first frame after a filter change stops spiking, a failed archive no longer
hides a pending Undo).

The table lists round 1 review items and round 2 answers (R1.1–R6). Review
item IDs overlap this plan's design decisions, so outside the table a desktop
review item is written "review D<n>"; a bare D<n> is a design decision below.

| Step | Review items and answers |
|---|---|
| 2 | H5 note (tool details expand without animation), motion PR1 |
| 3 | motion PR2 |
| 4 | motion PR3 |
| 5 | H2, H4 |
| 6 | H1 on the phone |
| 7 | D3, D5 (menu and status slot) |
| 8 | H3, LG2 |
| 9 | CD1, CD4, CD6 |
| 10 | CD5, FC1 (R6), FC2, FC3 |
| 11 | CD2, CD3, CD8, ST7 |
| 12 | D1, D2, D10, MS10 on the desktop |
| 13 | D4, SL2, SL4, SL5 |
| 14 | D6 |
| 15 | D13 |
| 16 | D7, MS8 |
| 17 | MS11 |
| 18 | D8, D11 |
| 19 | MS1 |
| 20 | MS6 |
| 21 | PL1, PL2, PL3, PL4, MS10 on the phone |
| 22 | SD1, SD5, SD7 |
| 23 | NS1, NS2, NS3, NS4 |
| 24 | AP1, AP2, AP3, AP5 |
| 25 | AP2 note (Windows drives) |
| 26 | ST1, ST2, ST3, ST5, H5 (settings parts), LG1 |
| 27 | MS9 |
| 28 | filter-insert first frame |
| 29 | failed archive versus Undo |
| 30 | SD8 |
| 31 | SD2, SD3, SD4, SD6, H5 (transcript parts), R1.2–R1.4 |
| 32 | MS4 folded into the summary words, R1.1, R5 |
| 33 | ST4, R2 |
| 34 | D5 counts, R3 |
| 35 | D12, as its own plan |
| 36 | H6; approval gate, last |

Out of scope, by the user's verdict:

- **Not worth it:** SL1 (sessions are named by the bridge), SL3 (logos tell
  harnesses apart at a glance), SD10, AP4, ST6 (the harness list stays as it
  is, so H5's harness-row line is dropped too), LG3, MS5.
- **Later:** H7 (review after step 6), review D9, SD9 (swipe shows the
  timestamp), MS3, MS7, CD7.
- **Declined follow-ups:** a confirmation sheet for phone archive (Undo is the
  safety net), keeping hidden sidebar rows mounted (D14), and popovers on
  sign-out (D15).
- **MS2** gets its own plan after this series (D23, Later Phases).

## Current Behavior And Findings

Design system (`client/module_prego`):

- `prego_colors.g.dart` is generated from `scripts/figma_tokens/figma_tokens.json`
  by `dart run scripts/figma_tokens/sync_figma_tokens.dart generate`.
  `textTertiary` is `gray450` `#5C5C5C` in both themes, about 2.6:1 on the dark
  background. `textQuaternary` has no users. `textTertiary` has 51 users and
  `textSecondary` 164.
- The type scale already has every size the ladder needs (textXs 12, textSm 14,
  textMd 16, textLg 18, textXl 20). `PregoNavTitle` hardcodes textLg medium and
  `PregoNavSubtitle` textXs medium in `textSecondary`, as loud as content.
- `PregoButtonsSolidHierarchy.primary` is the blue fill; `.primaryAlt` is the
  inverse pill the phone already uses. The desktop picks `.primary` in
  `desktop_bridge_popover.dart` and `desktop_session_list_screen.dart`.
- `PregoRadius` and `PregoSpacing` tokens exist, but 94 `BorderRadius.circular`
  literals bypass them. No icon size token exists; 57 icon sizes are literals.
  About 30 sites set a monospace style, at 11 to 13 points.
- Status colour families exist. Diff colours are hardcoded per brightness in
  `session_diffs/utils/diff_theme.dart`; 62 `Color(0x` literals remain in
  feature code. 90 `Icons.` uses remain beside the Tabler font, including three
  Material chevrons.
- Lint rules live in `shared/no_slop_linter` and register in
  `_NoSlopLinterPlugin.register()`.
- `PregoInteractionScope` already tells a shell apart as touch or pointer.
  `PregoAnchorMenu` is the anchored pointer menu.

Shared screens (`client/module_app_ui`, used by both shells unless noted):

- Session rows are one `SessionTile`; the unread and running sparkle is
  `PregoAiLoader`; the time sits far right in tertiary; the sparkle hides the
  time. Date group headers are inline `Text` in `session_list_content.dart`.
- The question and permission banner is one glass `SessionDetailPendingBanner`,
  brand-blue for questions and green for permissions, floating over the
  transcript and wider than the column.
- Tool rows after #1530 are a status icon, a title in `textSm` secondary and a
  trailing "Done". `ToolState.shellCommand` gives an expandable shell panel,
  inserted with no animation (`tool_part_widget.dart`, `_ShellToolPreview`).
  `_ToolOutputBlock` is an 11-point mono slab with a blue "Show more". A tool
  part carries only the harness's raw tool name, and the regression rule in
  `tools-and-file-changes.md` forbids deciding anything from that string.
- `PendingArchiveAlerts` shows the Undo toast and, on
  `PendingSessionArchiveFailed`, an error through the same single-slot
  presenter, which replaces a still-showing Undo.
- `PregoAnimatedSliverList` animates every inserted row at once, which spikes
  the first frame after a filter change.
- Project rows on both apps render `activityById`, which counts active
  sessions, including those only waiting for input. `ProjectListService`
  already computes running sessions per project, for ordering.
- Neither the wire nor client state records when a session began waiting;
  `ActiveSession` has only `awaitingInput`.
- The desktop shortcuts are inline closures in `desktop_router.dart`,
  `desktop_cockpit_shell.dart` and `desktop_session_detail_screen.dart`, and
  there is no back shortcut.

Data paths:

- **Send failures are silent in the client.** The bridge's router turns an
  uncaught send exception into HTTP 500. `SessionDetailCubit`'s send path
  catches it, calls `PromptSendQueue.failSend()`, which puts the message back
  at the head of the queue as if unsent, and only logs a warning. Three paths
  call `failSend`: a stale-options error, which then recovers the options; a
  dropped connection, re-sent after reconnect; and any other failure. The
  bridge deduplicates by `promptId` and records acceptance only after the
  plugin send succeeds.
- **Missing folders are barely reported.** `Project.directoryMissing` is set
  only when a project is added (`/project/open`) or renamed;
  `/project/current` always sends `false`, and `GET /projects` returns
  `ProjectSummary` without it. No client code reads it.
- **No drive enumeration exists.** The folder browser starts at the bridge's
  `FilesystemRepository.defaultBrowsePath`, which reads `HOME` directly before
  `USERPROFILE` instead of using `resolveUserHomeDirectory`. The client
  computes Root by walking parents.
- **Cross-project sessions exist only on the desktop.**
  `RecentSessionInventoryService` loads every project's session list when
  projects are admitted and reloads them all on every reconnect and catalog
  change. Only the desktop cockpit creates it; the phone's Projects screen
  provides only `ProjectInventoryService` and `ProjectListCubit`.
- **Worktrees.** Sesori's own worktrees live under `<project>/.worktrees/` and
  their sessions keep the project's id. A harness run directly inside a
  worktree folder is imported as an unrelated project; the bridge never reads a
  worktree's common git directory.
- **Diff counts.** Only the Changes screen fetches `/session/diffs`, which
  returns full before and after text for every file and costs five git
  processes, two more per changed file, and a read of every file, uncached.
  The `git diff --numstat` stage alone yields the totals; on this repository
  with 267 changed files the five fixed git steps took 0.19 s. Every plugin
  already emits a `session.diff` invalidation after file edits.
- **Per-turn edit data.** OpenCode reports per-file line counts (dropped by the
  bridge), Codex embeds diff text in tool output, the ACP family only flags that
  a call carries a diff, and Claude Code and Pi only know a tool edits files.
  None of it reaches the client.

## Design Decisions

- **D1 Scope.** As in Scope. Nothing marked Not worth it or Later is built.
- **D2 Order.** Steps that need no input first (2–34), then the sign-in plan
  (35), then H6 (36), which the user asked to be last. Foundations come before
  the screens that use them, and the transcript (31–32) builds on the restyled
  tokens, rows and session page.
- **D3 The sparkle stays.** It is the running and unread signal everywhere and
  replaces the blue dot. It moves into the row's leading status slot, sized and
  placed so the name leads, and the time always shows (PL2, SL2, review D1).
- **D4 Grey ramp.** Primary for titles; secondary for what you read next,
  including the time, which outranks the branch; tertiary for meta (harness,
  branch, counts, section headers); quaternary only for disabled content. Dark
  tertiary reaches about 4.8:1 and light tertiary drops from 6.5:1 to about
  5.0:1, so the steps stay distinct in both themes.
- **D5 Blue.** Blue means selected, on, or actionable: toggles, picker checks,
  the selected sidebar row, links and focus rings. Primary buttons are the
  inverse pill on both apps. "Show more" and "Jump to latest" become neutral.
  Required-field asterisks go.
- **D6 Amber means needs you.** Questions, permissions, waiting rows and the
  docked card are amber; so is a missing folder, which also needs you. Nothing
  decorative is amber.
- **D7 Title ladder.** Phone: a large 36 bold title only on Projects and
  Settings; bar title 18 bold with a 12 tertiary subtitle elsewhere; section
  header 14 medium tertiary; row title 16 medium with 12 tertiary meta. Desktop
  is one step smaller: no large titles, a 14 tertiary breadcrumb and a 16 bold
  title, 14 medium rows.
- **D8 Motion and modality.** Desktop pages fade in 150 ms. One
  `showPregoModal` entry point picks a sheet frame for touch shells and a
  dialog frame for pointer shells from the existing `PregoInteractionScope`, so
  no new scope is added. Nested dialogs stack and Esc closes only the top one.
  The model and slash-command pickers become anchored popovers on both apps,
  with keyboard navigation on the desktop. With reduced motion, everything
  switches instantly.
- **D9 Git worktree wording.** The option reads "New git worktree" with the
  hint "Runs on a new branch in its own folder" (NS2, the user's note).
- **D10 Tool kinds come only from plugins.** The client never classifies a raw
  tool name. Until step 32 lands, the transcript summary counts steps.
- **D11 Search covers titles the app already has.** No bridge search, no
  transcript search.
- **D12 One activity projection.** The desktop sidebar projection moves from
  `module_desktop_core` into `module_core` under surface-neutral names and
  feeds the desktop sidebar, the desktop home and the phone Activity group. It
  outputs the phone's waiting-first order and the home's needs-you, running
  and recent sections, so no widget derives them. The phone's Projects screen
  owns its own `RecentSessionInventoryService` and `RecentSessionsCubit`, as
  the desktop cockpit does.
- **D13 Archive.** The phone keeps Undo only, with no confirmation sheet. A
  failure alert never replaces a showing Undo; it waits until the Undo closes.
- **D14 Hidden sidebar rows are not kept mounted.** One slow first frame on
  expand costs less than keeping every hidden row alive.
- **D15 No change to popovers on sign-out.**
- **D16 Gates.** The round 2 answers removed the gates on steps 31–34 and
  FC1. Step 35 waits for the user to scope the sign-in rebuild with them.
  Step 36 is built locally and shown as before and after screenshots of the
  running app on a local page; no PR opens before the user approves it.
- **D17 Sends name the harness, not a start.** The SD8 mockup said "Starting
  OpenCode…", but the client cannot tell a harness start from a slow send, so
  it says "Sending to OpenCode…". The name comes from the one display name
  step 22 puts on `SessionDetailLoaded`.
- **D18 No new analytics.** Search and the palette are the only candidates;
  add them later if a product decision needs the numbers.
- **D19 Transcript groups (R1.2–R1.4).** A group of steps ends at every piece
  of text, so steps, a sentence and more steps keep their order. When the live
  row is off screen, the jump button shows it and a turning sparkle leads the
  session title. Running sub-agents are live rows too and fold into their
  group as "2 sub-agents"; the sub-agent pill by the composer stays.
- **D20 Summary words (R1.1, R5, R6).** The summary counts by kind in order of
  first appearance, plus failures: "Thought · read 2 files · ran 1 command".
  Edits fold in as "edited 2 files" with no line counts; the session's line
  total lives on Changes (D22). Reasoning parts carry no timing on the wire,
  so thinking shows without a duration. Zero counts are hidden everywhere, and
  every count uses the one "−" sign.
- **D21 YOLO (R2).** A neutral "⚡ YOLO" chip sits in the model row of every
  session while YOLO is on; tapping it explains YOLO and links to Settings.
  Settings says what happens in a plain sentence with no warning tone. No
  amber (D6).
- **D22 Changes numbers (R3).** "Changes +12 −2" on both apps, from a cheap
  numstat-only request. An older bridge keeps plain "Changes".
- **D23 Outside worktrees (R4).** Worktrees made outside Sesori fold into
  their repository like Sesori's own: their sessions move under the repository
  and show their branch, with no new list shape. Its own plan (Later Phases).
- **D24 No waiting durations.** Nothing records when a session began waiting,
  so rows drop the mockups' "waiting 9m". A waiting row says "Waiting" in
  amber, and the row's time, which is when the session last changed, stays at
  the right and carries the same information.
- **D25 One subtitle rule for every harness.** No harness declares a default
  agent, so SD1's "OpenCode adds its agent only when it is not the default"
  would need a harness check in shared code. The subtitle is the harness
  display name and the model for every harness; the agent stays in the
  composer's agent chip, where it already shows.
- **D26 Missing folders show on the row.** The project page has no project
  fetch of its own, and adding one costs a request per page open for a rare
  state the row already shows. So MS9's line above the session list is
  dropped; the row says "Folder not found" on both apps.

## Design By Step

Every behaviour-changing step updates the regression lines it invalidates in
the same PR, analyzes each owning package with `--fatal-infos`, runs the
directly relevant tests, and, when it changes a shared widget, runs the phone
and desktop suites that render it. Visual steps render before and after images
locally for both themes and both apps; they stay private.

### Motion and modality (steps 2–4)

**Step 2 — tool details and desktop page fades.** The shell panel in
`_ShellToolPreview` and the `_ToolOutputBlock` expansion animate their height
(about 200 ms, ease-out, top-aligned). `desktop_router.dart` gives its routes
one fade page builder (150 ms). Both honour
`MediaQuery.disableAnimationsOf`. Checks: a widget test that pumps half the
duration and sees an intermediate height; reduced motion switches in one
frame; a router test for the fade duration.

**Step 3 — one modal entry point.** `showPregoModal` in `module_prego` renders
the existing bottom sheet under a touch scope and a centred dialog under a
pointer scope. Every sheet call site in `module_app_ui` and `app` moves to it,
except the two pickers that step 4 replaces. The desktop has no direct sheet
calls; what it reaches are the shared `showPregoBottomSheet` sheets and four
raw `showModalBottomSheet` calls in `add_project_dialog.dart`,
`question_modal.dart`, `permission_modal.dart` and `reasoning_modal.dart`
(step 14's card opens the question and permission ones). The `showDialog`
alerts stay as they are. Phone behaviour is unchanged. Checks: `module_prego`
tests for both frames, a dialog opened from a dialog, and Esc closing only the
top one; the phone sheet tests pass untouched. Architecture implementation
review: new shared API.

**Step 4 — anchored pickers.** `model_picker_sheet.dart` and
`command_picker_sheet.dart` content opens in a popover anchored to its chip or
button on both apps. The desktop adds Up, Down, Enter and Esc, and the command
list filters as you type after "/". Checks: keyboard and selection tests;
popover placement near a window edge.

### Foundations (steps 5–11)

**Step 5 — grey ramp and section headers.** Edit the tertiary and quaternary
mappings in `figma_tokens.json` (adding a grey primitive if none fits D4) and
regenerate; never edit the generated file. Section headers take the D7 style:
session list date groups, `SettingsSection` and
`DesktopSidebarSectionHeader`. The PR asks the user to mirror the token change
in Figma, or the next export reverts it. Checks: a contrast test on the
generated values; existing golden-free widget tests.

**Step 6 — title ladder on the phone.** Restyle `PregoNavTitle`,
`PregoNavSubtitle` and `PregoNavLeadingTitle` to D7, and keep the large title
only on Projects and Settings. Row styles land with their rows (steps 13, 21).
Checks: nav widget tests for the three styles; a large-title test per screen.

**Step 7 — desktop page header.** `DesktopPageToolbar` shows the project as a
14 tertiary breadcrumb that opens its list, then the session name in 16 bold,
with no back arrow. No back shortcut exists, so the step adds Cmd/Ctrl+[ to go
back from a pushed page. Toolbar content starts at one
left edge on every page. On the session page, Mark as unread moves into the
more menu, and the busy or waiting indicator leads the title in the same
status slot as the sidebar. Checks: toolbar layout tests; breadcrumb
navigation; Cmd/Ctrl+[ goes back; Mark as unread from the menu keeps its
shortcut.

**Step 8 — blue and the email form.** Apply D5: the two desktop `.primary`
buttons become `.primaryAlt`; "Show more" and "Jump to latest" become neutral;
`PregoInputField` stops drawing asterisks and its placeholders use tertiary.
The question banner turns amber in step 14. Checks: button hierarchy tests;
input field test without asterisks.

**Step 9 — icon size, radius and code text tokens.** Add a hand-written
`PregoIconSize` (14, 18, 22) beside the radius tokens; map radius literals to
`PregoRadius` (small, medium, card, pill); add one 12-point mono style and use
it for every code and output surface. Literal sizes that are deliberate, such
as brand art, stay and say why. Split into 9.a (icons and mono) and 9.b
(radii) if the diff passes the soft cap. Checks: analyze; the design catalog
shows the new tokens.

**Step 10 — status and diff colours.** `DiffTheme` derives its colours from
the status tokens: a 10% tint, a 2-point left bar and a full-height gutter.
File badges become a plain coloured letter. Remaining raw colours move to
tokens where one exists with the same meaning. FC1 (D20): a zero count is
left out, and the header uses the same "−" sign as the rows. Checks: diff
widget tests for added, removed and changed lines in both themes.

**Step 11 — one icon set and sentence case.** Replace every `Icons.` use with
its Tabler equivalent, one chevron everywhere, and add an `avoid_material_icons`
warning rule to `no_slop_linter`. The X brand uses Tabler's `brand_x` glyph if
the bundled font has it, else an SVG asset. Title Case strings in
`app_en.arb` become sentence case. Checks: lint rule tests; analyze every
client package clean.

### Desktop cockpit (steps 12–16)

**Step 12 — sidebar.** Review D1: projects 14 medium primary, sessions 14
regular secondary, unread sessions primary with the sparkle. Review D2: the
full-width New
session button and the list toolbar copy go; a quiet "+ New session ⌘N" row
replaces them, reading "Add a project" when there are none. Review D10: the
chevron
shows on hover only, the selected row fills the width, the open session is
highlighted once, "Show 4 more" is 12 tertiary, and the footer is one 44-point
row. MS10: a project row shows "2 running" when it has running sessions.
`ProjectListLoaded` gains that per-project count, computed in `module_core`
with `SessionActivityCalculator.isRunning` in the pass `orderProjects` already
makes, so sessions only waiting for input never count as running. Checks:
sidebar widget tests for each rule; a service test for the count; the shortcut
still works.

**Step 13 — session rows.** `SessionTile` gets a 16-point leading status slot
(sparkle, amber waiting dot, or nothing), the title, and one tertiary meta line
of harness, branch and PR; the time sits at the right in secondary and always
shows. Waiting rows say "Waiting" in amber (D24). Branches shorten in the
middle.
The repository subtitle loses its chevron popover, shortens in the middle and
shows the full text on long press. Checks: tile tests for idle, running,
unread, waiting and a long branch, on both apps.

**Step 14 — needs-you card.** `SessionDetailPendingBanner` becomes a solid
amber card docked above the composer, as wide as the column, with the request's
first line and an Answer or Review button that opens the existing modal.
Checks: card placement and width; one card per pending request type; the
modals still open.

**Step 15 — desktop settings window.** No page title; a small plain X; Esc
closes; Appearance is a Light, Dark, System segmented control; intro text in 12
tertiary; chevrons on values that open menus; the bridge popover leads with a
status dot and "Running" and uses quiet rows. The settings sidebar takes the
main sidebar's row style. The user gets before and after screenshots on a
local page. Checks: settings modal tests; Esc; appearance switching.

**Step 16 — file list in Changes.** The desktop Changes page uses the shared
toolbar, a file list on the left and the selected file's diff on the right.
The phone shows the file list with counts at the top, and a tap jumps to that
diff. Checks: selection and jump tests on both apps.

### Activity, home, search and palette (steps 17–20)

**Step 17 — shared activity (D12).** Move
`desktop_sidebar_session_projection.dart` and its tests from
`module_desktop_core` to `module_core`, beside `recent_sessions_resolvers.dart`,
under surface-neutral names. The desktop keeps passing its deferred sessions
and sticky id; the phone passes `deferredSessions: const {}` and
`stickySessionId: null`. The projection gains the waiting-first order the
phone shows and the needs-you, running and recent sections step 18's home
shows. The phone's `project_list_screen.dart` provides
`RecentSessionInventoryService` and `RecentSessionsCubit` as
`DesktopCockpitCubitProvider` does, and an Activity group tops Projects:
waiting sessions first with an amber dot, then running ones, each opening its
session (D24). Checks: projection tests move with it and cover the new
outputs; phone widget tests for empty, waiting and running. Architecture
implementation review: moved class, new phone owner and shared boundary.

**Step 18 — desktop home and empty project.** The home pane shows a composer
that starts a session in any project, then the projection's needs-you, running
and recent sections. It reuses the new session composer rather than building
another: the home pane keeps the picked project in widget state and provides a
`NewSessionCubit` keyed by that project's id, re-created when the pick
changes. `NewSessionCubit` is unchanged, and drafts stay per project as they
are today. A project with no sessions shows the composer in place with the
project picked. Checks: home pane tests; changing the pick re-creates the
cubit; a session started from home lands in the chosen project. Architecture
implementation review: new composition.

**Step 19 — search on the phone.** A search field tops Projects and each
session list. It filters titles the list has loaded and shows "No matches"
when empty. One pure title matcher in `module_core` returns the matches and
their match ranges; the phone lists and step 20's palette call it with a
query held in widget state. Checks: matcher unit tests; filter, clear and
no-match widget tests. Architecture implementation review: new shared
matcher.

**Step 20 — command palette.** Cmd/Ctrl+K opens a palette over sessions,
projects and commands, with each command's shortcut and matches highlighted
through step 19's matcher; the sidebar gains a "Search ⌘K" row. The desktop
shell gains one command list (label, shortcut, action) that both its
`CallbackShortcuts` bindings and the palette read, replacing the inline
closures. Page-only commands such as Mark as unread stay on their page and
are not in the palette. Sessions and projects come from the cockpit's
`RecentSessionsCubit` and `ProjectListCubit`. Checks: open, filter, keyboard
selection and Esc; each command runs its action and its shortcut still works.
Architecture implementation review: new feature and shortcut ownership.

### Phone pages and settings (steps 21–27)

**Step 21 — project rows.** A project's path grows one folder at a time until
it differs from same-named projects, and absolute paths keep their leading
slash; a pure `module_core` function computes it, not the row. The sparkle
replaces "New activity" text. Dates read "15 Aug". Adding a project opens it.
Rows show "2 running" from step 12's count. Checks: a unit test for the path
function; row tests.

**Step 22 — session page.** The subtitle reads harness display name and model
in 12 tertiary ("Claude Code · Haiku") for every harness (D25).
`SessionDetailLoaded` carries the display name `SessionInteractionCalculator`
already reads from `setup.displayName`, so the subtitle and step 30 share one
source. Code blocks use the tool output inset with the language and a Tabler
copy button in their header. The composer's + and / fold away once typing
starts. Checks: subtitle tests with and without a model; composer fold
test.

**Step 23 — new session page.** One grouped card under a bar title; the
question becomes the composer placeholder; D9 wording; the cache message goes
and Refresh moves into the harness picker; the OpenCode logo gets square
bounds; with the keyboard up, one summary line shows project, harness and
worktree. Checks: new session view tests on both apps.

**Step 24 — folder browser.** "Add project" in 18 bold beside the close
button; a tappable path breadcrumb with the current segment bold and Home as
the first segment inside it; "No folders here" with a line saying the folder
holds only files; the button reads "Add <folder>". Checks: dialog tests.

**Step 25 — Windows drives.** `FilesystemApi` gains an asynchronous drive-root
probe, so a disconnected drive never blocks the bridge isolate, and
`FilesystemRepository` makes the Windows-only decision. The handler returns
the roots on `FilesystemSuggestions`, only for a request without a prefix, as
`@Default([])` marked `// COMPATIBILITY 2026-MM-DD (v1.9.0): ...` with its
retiring condition. The browser lists them beside Home. `defaultBrowsePath`
switches to `resolveUserHomeDirectory`, which also fixes its
`HOME`-before-`USERPROFILE` order on Windows. Checks: bridge tests with a fake
filesystem; client test with and without drives. Architecture implementation
review: wire field.

**Step 26 — settings and bridge offline.** Close X on the title row; the
account page is named Account and says "Signed in with Email" once; offline
bridge settings show one line above the group with the rows dimmed; Log out
asks first. The bridge offline screen keeps its illustration, names the
computer once in the bridge line, reads "Bridge offline", and quiets its links;
the user gets before and after screenshots on a local page. Checks: settings
and offline view tests.

**Step 27 — missing folders (D26).** `GET /projects` returns
`directoryMissing` on `ProjectSummary`, computed in the bridge's project
repository with the existing directory check and defaulting to false for older
bridges (compatibility marker as in step 25). The project row on both apps
says "Folder not found" in amber with Remove. Checks: repository and handler
tests; row tests. Architecture implementation review: wire field.

### Fixes (steps 28–30)

**Step 28 — filtered rows.** After a filter change, `PregoAnimatedSliverList`
animates only the rows that land on screen and builds the rest lazily. Checks:
list tests; a before and after frame timing from a local benchmark, recorded
in the step evidence.

**Step 29 — failed archive and Undo.** `PendingArchiveAlerts` holds a failure
alert while an Undo toast is showing and shows it when the toast closes. Both
apps. Checks: alert tests for failure during and after the Undo window.

**Step 30 — failed sends.** `QueuedSessionSubmission` stays as it is;
`PromptSendQueue` holds a failed head in its own slot instead of silently
re-queueing it. Only a non-stale error response, or a thrown failure within
the same connection generation, marks it failed; the stale-options recovery
and the re-send after reconnect stay automatic. The message shows "Couldn't
send" under it with Retry, and later messages wait behind it. Retry resends
the same `promptId`, so the bridge's dedup can never run a prompt twice. While
a send is in flight past a short delay, the message shows "Sending to
<harness>…" (D17); the message bubble owns that delay timer. The warning log
stays. Checks: queue unit tests for fail, retry with the same id, and success
after retry; the stale-options and reconnect paths stay automatic; widget
tests for both states.

### Transcript, YOLO and Changes (31–34)

**Step 31 — live transcript (D19).** Client only. Consecutive tool, thinking,
step and sub-agent parts collapse into one summary row that expands with
animation; a group ends at every piece of text. The running part shows as a
live row with a shimmering label, then folds into its group when it finishes.
Thinking shows a short tail of its latest words while it streams. Finished
rows say nothing; failures keep one signal. Until step 32 the summary names
only what the part types already tell: thinking, sub-agents, a step count for
tools, and failures. When the live row is off screen, the jump button shows it
and a turning sparkle leads the session title. This replaces the tool "Done",
the thought card box and the blue output "Show more". Grouping and counting
are a pure `module_core` builder over the loaded messages, beside
`session_detail_state.dart`; widgets only render its groups. Whether the live
row is on screen is widget state in the message list, exposed through a
`module_app_ui` scope that the desktop session screen and the phone title
read; scroll state never enters the cubit. Split 31.a (grouping) and 31.b
(live row and streaming tail) if needed. Architecture implementation review:
new transcript builder and scope.

**Step 32 — tool kinds (D20).** The plugin interface gains `PluginToolKind` on
its tool part, and each plugin maps its own tool names to it. `sesori_shared`
gains its own `ToolKind` on `MessagePartTool`, declared
`@JsonKey(unknownEnumValue: ToolKind.unknown) @Default(ToolKind.unknown)` with
a compatibility marker, so an older bridge's missing field and a newer
bridge's new value both read as unknown. The bridge maps one to the other in
`plugin_to_shared_mapping.dart`, and the plugin interface stays independent of
`sesori_shared`. An unknown kind still counts as a step. The summary switches
to words, including "edited 2 files" with no line counts. Counts are tool
calls per kind, so reading one file twice reads "read 2 files"; the client
never parses tool input. `docs/HARNESS_CAPABILITIES.md` records any harness
that cannot classify. Architecture implementation review: contract change.

**Step 33 — YOLO (D21).** The settings hint becomes "Sesori approves every
permission request for you, so the agent never stops to ask." The chip joins
the model row of every session while YOLO is on. Today only the Settings
screens load the flag (`BridgeSettingsCubit` over the stateless
`BridgeSettingsRepository`), so a small `module_core` service owns the
last-known flag for the connected bridge and loads it on connect.
`BridgeSettingsCubit` reads and saves through it, and `SessionDetailCubit`
subscribes to its stream and carries the flag in `SessionDetailLoaded`, which
the chip reads. A change made on another
surface shows after the next reconnect or Settings visit; accepted as a
self-correcting stale value. Architecture implementation review: new shared
state.

**Step 34 — Changes count (D22).** Bridge: a new handler calls a summary
method on `SessionDiffService`, which reuses `SessionDiffRepository`'s numstat
step, and reports a missing session as a structured error rather than a bare
404. Client: a new `module_core` cubit beside `DiffCubit` asks
`SessionRepository`, then `SessionApi`, for the summary, refreshed on
`session.diff` at most every two seconds; both shells' session pages provide
it. The repository maps a bare 404, which is how an older bridge answers an
unknown route, to a sealed unsupported result, and the cubit then stops asking
for that page, which keeps plain "Changes". Zero sides hide (D20).
Architecture implementation review: wire change.

### Steps that wait for the user (35–36)

**Step 35 — desktop sign-in plan (review D12).** Scope the sign-in rebuild
with the user, including Apple sign-in, and raise it as its own plan. This step
is that plan's PR; its implementation runs under it.

**Step 36 — header backdrop (H6).** Built last, locally. The user approves
before and after screenshots of the running app first, because an over-strong
fade looks worse than none. No PR before approval.

## Compatibility

- Only steps 25, 27, 32 and 34 touch the client-bridge contract. Each adds an
  optional field or a new request with an honest default, so an older bridge
  degrades to today's behaviour and an older app ignores the field. Step 32's
  kind also reads a newer bridge's unknown values as unknown. Markers use the
  product version from `bridge/app/pubspec.yaml` at the time.
- No database, migration or persisted-format change. The desktop layout file
  is unchanged.
- Plugin and module APIs change in lockstep inside the repository.

## Complexity Budget

New persistent state: none.

New in-memory state, each with one owner:

| State | Owner | Lifetime |
|---|---|---|
| Expansion animation | the row's widget state | while mounted |
| Popover open and highlighted index | the picker and palette widgets | while open |
| Search and palette query | the list screen's or palette's widget state | while shown |
| Picked project | the desktop home pane's widget state (step 18) | while mounted |
| Recent session inventory on the phone | `RecentSessionInventoryService` and `RecentSessionsCubit` from the phone's Projects screen (step 17) | Projects screen lifetime |
| Held failure alert | `PendingArchiveAlerts` | until the Undo toast closes |
| Failed head submission | `PromptSendQueue` | until Retry or removal |
| "Sending to" delay timer | the message bubble (step 30) | while the send is in flight |
| Group expanded flags | the transcript group widget | while mounted |
| Live row off screen | the message list's widget state, exposed through a `module_app_ui` scope (step 31) | while mounted |
| Change summary, one debounce timer and the unsupported result | a new `module_core` cubit beside `DiffCubit` (step 34) | page lifetime |
| Last-known YOLO flag | a `module_core` service (step 33) | connection lifetime |

New types: `showPregoModal` and its two frames, `PregoIconSize`, the mono
style, the projection's phone and home sections, the title matcher, the
desktop command list, the palette, the Activity group, the transcript builder
and its groups, the live-row scope, the YOLO flag service, `PluginToolKind`
and `ToolKind`, the change-summary cubit with its sealed result, and the
summary request. The YOLO flag service is the only new DI registration and
stream, and step 34 adds the only new route. No new repository.

Deliberately not added: a new interaction scope for modal frames, a desktop
fork of any shared widget, transcript or server-side search, client-side tool
classification, per-turn line counts, a density or spacing system, analytics
events, a "waiting since" time (D24), a default-agent contract field (D25), a
project fetch on the project page (D26), and a failed variant of
`QueuedSessionSubmission`.

## Cleanup Assessment

Removed by the series, each in the step that makes it obsolete:

- the direct sheet calls that step 3 routes through `showPregoModal`;
- the asterisk rendering in `PregoInputField` if nothing else uses it (8);
- the literal sizes, radii and colours that tokens replace (9–11);
- the full-width New session button and the list toolbar copy (12);
- the repository subtitle popover (13);
- the glass pending banners (14);
- the settings page titles and preview-card appearance picker on the
  desktop (15);
- the "New activity" label (21), the raw id subtitle (22), the cache message
  and the standalone refresh control (23), the Home and Root chips (24);
- the repeated offline strings and the duplicated machine name row (26);
- the desktop-only projection names (17) and the inline shortcut closures the
  command list replaces (20);
- the silent re-queue after a real send failure in `failSend` (30);
- the tool "Done", the bordered thought card, sub-agent "Done ›" cards and the
  blue output "Show more" (31);
- plugin-private tool classifiers that the normalized kind covers (32).

Declined: splitting `desktop_sidebar.dart`; steps 12 and 20 touch it one at a
time.

## Delivery Plan

38 PRs, one at a time in order; exact titles and branches are in
[TRACKER](TRACKER.md#pr-titles). Targets count additions plus deletions
across every path.

| Step | Target | Emoji | Architecture review |
|---|---|---|---|
| 1 | ≤ 1,000 | 🌱 | plan review |
| 2 | ≤ 250 | 🌿 | — |
| 3 | ≤ 600 | ⚙️ | yes |
| 4 | ≤ 600 | ⚙️ | — |
| 5 | ≤ 500 | ⚙️ | — |
| 6 | ≤ 600 | ⚙️ | — |
| 7 | ≤ 500 | ⚙️ | — |
| 8 | ≤ 400 | 🌿 | — |
| 9 | ≤ 900 | ⚙️ | — |
| 10 | ≤ 600 | ⚙️ | — |
| 11 | ≤ 900 | ⚙️ | — |
| 12 | ≤ 700 | ⚙️ | — |
| 13 | ≤ 700 | ⚙️ | — |
| 14 | ≤ 600 | ⚙️ | — |
| 15 | ≤ 600 | ⚙️ | — |
| 16 | ≤ 800 | ⚙️ | — |
| 17 | ≤ 900 | 🚧 | yes |
| 18 | ≤ 800 | ⚙️ | yes |
| 19 | ≤ 600 | ⚙️ | yes |
| 20 | ≤ 900 | 🚧 | yes |
| 21 | ≤ 500 | 🌿 | — |
| 22 | ≤ 600 | ⚙️ | — |
| 23 | ≤ 600 | ⚙️ | — |
| 24 | ≤ 500 | 🌿 | — |
| 25 | ≤ 500 | ⚙️ | yes |
| 26 | ≤ 600 | ⚙️ | — |
| 27 | ≤ 400 | ⚙️ | yes |
| 28 | ≤ 300 | 🌿 | — |
| 29 | ≤ 300 | 🌿 | — |
| 30 | ≤ 700 | 🚧 | — |
| 31 | ≤ 1,200 | 🚧 | yes |
| 32 | ≤ 1,200 | 🚧 | yes |
| 33 | ≤ 500 | ⚙️ | yes |
| 34 | ≤ 800 | 🚧 | yes |
| 35 | ≤ 600 | 🌱 | its own plan review |
| 36 | set at approval | ⚙️ | — |
| 37 | ≤ 600 | 🌱 | — |
| 38 | ≤ 300 | 🌱 | — |

Evidence for a finished step goes in `steps/step-NN.md`, written by that
step's own PR. Step 37 reconciles `docs/regression/`. Step 38 runs the final
matrix below on the merged series, records every cell, and retires the plan to
`.plan/completed/visual-hierarchy/`.

## Regression Documentation And Final Matrix

Affected feature documents:

- `design-catalog.md` — new tokens and the icon lint (5, 9–11).
- `navigation-transitions.md` — desktop fades, modal frames, reduced motion
  (2–4).
- `glass-presentation.md` — modal frames and the retired glass banner (3, 14,
  36).
- `desktop-cockpit-shell.md` — header, sidebar, settings window, home, palette
  (7, 12, 15, 18, 20).
- `projects-and-sessions.md` — rows, Activity, search, project rows, missing
  folders, filtered rows (13, 17, 19, 21, 27, 28).
- `native-activity-indicators.md` — the sparkle's slot (12, 13, 31).
- `questions-and-permissions.md` — the needs-you card (14).
- `diffs-and-source-control.md` — diff colours, file list, counts (10, 16,
  34).
- `tools-and-file-changes.md` — tool expansion, grouping, tool kinds (2, 31,
  32).
- `session-turns.md` — send failures, live transcript (30, 31).
- `session-creation-and-options.md` — pickers, new session page, wording (4,
  23).
- `account-and-onboarding.md` — email form, account, sign-out (8, 26).
- `bridge-connectivity.md` — offline settings and the offline screen (26).
- `popup-alerts.md` and `session-archiving-and-deletion.md` — the held
  failure alert (29).
- `permission-auto-approval.md` — YOLO visibility (33).
- `docs/HARNESS_CAPABILITIES.md` — tool kinds (32).

Highest coverage level: **L3, client end to end**, on both release-target
surfaces, because most steps change shared screens.

| Target | Level | Boundary | Scope |
|---|---|---|---|
| macOS desktop | L3 | Client end to end, live bridge, representative plugin | fades, modals, pickers, header, sidebar, rows, needs-you card, settings window, Changes, home, palette, send failure, transcript |
| iOS (release-target mobile) | L3 | Client end to end, live bridge, representative plugin | title ladder, rows, Activity, search, project rows, session page, new session, folder browser, settings, bridge offline, missing folder, needs-you card, send failure, transcript |
| Android | L2 + smoke | Automated + device smoke | shared screens render; sheets and popovers |
| Windows, Linux desktop | smoke | Client end to end | build, fades, modals, sidebar, palette |
| Bridge | L2 | Headless bridge | `directoryMissing` on the list; drive roots (fake filesystem); change summary |
| Plugins, step 32 | L2 + live | Automated for every supporting production plugin; Live plugin for Claude Code, OpenCode, Codex, Pi and one ACP harness | tool kinds |

Proposed reductions, to be accepted with this plan: Windows and Linux run a
smoke pass, as for the last two desktop plans; Android runs L2 plus a smoke
pass; Windows drive listing is proven by automated tests unless a Windows host
is available; step 32's remaining ACP harnesses are proven by automated tests
because they share one mapper.

## Risks And Accepted Limits

- **Shared edits change the phone on purpose.** Almost every step restyles a
  shared widget; each runs the phone and desktop suites that render it.
- **Token changes ripple everywhere** (5, 9–11). Before and after renders of
  both themes are checked for every touched screen.
- **Figma drift.** Step 5 edits the exported token JSON; the user mirrors it in
  Figma, or the next export reverts it.
- **The phone fetches every project's session list** when Projects opens and
  on every reconnect, as the desktop already does (step 17). Accepted: the
  lists are small, and Activity needs them. If it proves heavy, fetch only
  projects with activity.
- **YOLO can look stale on a second surface** until it reconnects or opens
  Settings (step 33). Accepted: it self-corrects and changes no behaviour.
- **Step 36 can take several rounds.** It blocks only steps 37–38.
- **Search sees loaded titles only.** Accepted (D11).
- **The palette and Activity read loaded session data.** A session the app has
  not loaded does not appear until it loads. Accepted.
- **Windows drives are unproven live** unless a Windows host is available.
- **A failed send blocks later queued messages** until Retry or removal, which
  is the point: they would fail the same way.
- **One large file.** Steps 12 and 20 both edit `desktop_sidebar.dart`; they
  are serialized.
- **Series length.** Steps may split into `x.a`/`x.b` under the sizing policy
  without changing the total.

## Plan Review

The architecture plan review of 2026-09-23 rejected the first draft, round 2
answers included, with 13 findings. All were valid and are applied above
without a second review, as the review rules allow.

- V1: the phone owns its own inventory, and the projection moves under neutral
  names with the phone and home sections as outputs (D12, step 17).
- V2: the home keys a `NewSessionCubit` by the picked project (step 18).
- V3: `ProjectListLoaded` carries a running count computed in `module_core`
  (steps 12, 21).
- V4: no waiting duration (D24).
- V5: one title matcher, one desktop command list, named palette sources
  (steps 19, 20).
- V6: one subtitle rule for every harness (D25).
- V7: the drive probe is layered and the home folder uses
  `resolveUserHomeDirectory` (step 25).
- V8: the missing-folder note stays on the row (D26); Current Behavior is
  corrected.
- V9: a failed-head slot, only real failures stop the queue, and Retry keeps
  the `promptId` (step 30).
- V10: a pure transcript builder and a widget-owned live-row scope (step 31).
- V11: two tool kind enums mapped in the bridge and tolerant of unknown
  values; counts are calls (step 32).
- V12: the YOLO flag reaches the chip through `SessionDetailLoaded` (step 33).
- V13: a named bridge chain, a new cubit and a sealed unsupported result
  (step 34).

Optional suggestions taken: step 3 names the four raw sheets and keeps the
alerts; step 7 adds the missing Cmd/Ctrl+[; step 25 probes asynchronously and
only without a prefix; steps 22 and 30 share one display name; step 30's
bubble owns its timer.

## Relation To Other Plans

- `desktop-ui-polish` (completed) built what steps 7 and 12 restyle. This plan
  replaces its full-width New session button (its step 2) with a quiet row and
  moves its toolbar Mark unread into the more menu (its step 11).
- `instant-session-launch` (proposed) also changes `PromptSendQueue` and
  `NewSessionView`. Steps 23 and 30 change only what they need; whichever lands
  second rebases.
- `desktop-app`, `desktop-distribution`, `path-runtime-authority-split`,
  `session-refresh-reconnects` and `user-analytics` are independent.

## Later Phases (rough intent only; planned when they start)

- **MS2 worktrees (D23).** Fold worktrees made outside Sesori into their
  repository. This is bridge work on which project an imported session belongs
  to, and a new session can no longer start inside that exact folder, so it
  needs its own plan.
- **Thinking time.** "Thought for 3 s" needs plugins to report reasoning
  timing; plan it only if the user wants the seconds (D20).
- **H7.** Review again after step 6 lands.
- **Transcript search** through the bridge, if title search proves too narrow.
- **Per-turn line counts**, only if harnesses start reporting them reliably.

## Expected Result

Every screen has one clear title, readable secondary text and quiet chrome.
Blue marks selection, amber marks what needs you, and the sparkle marks what
is moving. Rows lead with status and always show the time. The desktop has a
real page header, a calm sidebar, a home that starts work, a command palette
and a two-pane Changes page; the phone gains search, Activity and a file list.
A failed send says so. The transcript shows each step live and folds finished
work into short summaries. There is no database change; the only wire changes
are optional fields and one optional request with honest defaults.
