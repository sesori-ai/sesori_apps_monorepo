# App simplification tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 13/13. The L3 matrix ran on 2026-10-25 with two Fail cells and nine Not executed cells, so the
  plan stays active until the user decides on fixes or reductions.
- User decisions: D1–D16 in `PLAN.md`, agreed 2026-10-24 over two review rounds.

## Delivery

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/13 | Publish the plan | Done | #2027 |
| 2.a/13 | One session scope; every refresh imports | Done | #2032 |
| 2.b/13 | Scan cancel, dismiss, deep pull and per-harness scan removed | Done | #2035 |
| 3/13 | Searchable picker with Open another folder | Done | #2034 |
| 4/13 | Settings › Projects | Done | #2037 |
| 5/13 | Row logo and project label | Done | #2030 |
| 6/13 | All-projects list model | Done | #2033 |
| 7.a/13 | Archived across projects | Done | #2038 |
| 7.b.i/13 | Home building blocks; Archived's project-list states | Done | #2041 |
| 7.b.ii/13 | All-projects home and route tree | Done | #2043 |
| 8/13 | Projects screen removed | Done | #2044 |
| 9/13 | Wide phone and tablet sidebar | Done | #2045 |
| 9.b/13 | Floating phone and tablet sidebar panel, a step 9 follow-up for the user's request | Done | #2049 |
| 10.a.i/13 | Desktop Archived page and footer entry | Done | #2046 |
| 10.a.ii/13 | Desktop sidebar on the shared list | Done | #2047 |
| 10.b/13 | Desktop Activity and rail removed | Done | #2048 |
| 11.i/13 | Desktop composer home; palette on the shared list; Recent sessions removed | Done | #2052 |
| 11.ii/13 | Desktop project page, its breadcrumbs and exits removed | Done | #2054 |
| 11.iii/13 | Session list view mode removed | Done | #2058 |
| 11.iv/13 | Project-sessions route and list-claim stack removed | Done | #2062 |
| 12/13 | Regression documents reconciled | Done | #2064 |
| 13/13 | L3 matrix run; plan retired | In review | [L3 matrix (2026-10-25)](#l3-matrix-2026-10-25) |

## Evidence and decisions

- 2026-10-24: these were inspected and summarized in `PLAN.md` under “Current behavior”:
  - routing and its `projects` consumers;
  - the scoped inventories;
  - the Projects screen, the session list cubit and rows;
  - catalog rescan and viewed-project claims (client and bridge);
  - the desktop sidebar, home, project page and settings modal;
  - the new-session picker and the folder browser.
- 2026-10-24: round 1 of the UX review settled the list, filter, archived, wide layout, refresh and picker
  questions. Round 2 settled the row logo position, the wording, the phone picker form and the scan-row ending.
  The Harnesses-row offline bug the user reported in round 1 was fixed separately in #2026.
- 2026-10-24: step 6 filled four gaps in `PLAN.md` *Ownership*: `setHiddenSessionIds` (so chip counts skip
  rows held by an Undo window or a launch row), one shared filter for both modes (D6 enters through
  `selectProject`), the `SessionListService` comparators as the single ordering owner, and `retry` plus `isLoading`.
- 2026-10-24: step 7.b measured about 3,100 changed lines in one branch, so it split into 7.b.i (building blocks,
  no route change) and 7.b.ii (route tree and home). 7.b.i also closes a #2038 review thread: Archived showed
  “No archived sessions” while the project list was loading, had failed or the computer was disconnected. The
  `PLAN.md` *Cleanup* list was corrected: 7.b.ii removes the router's `_SessionListPane`, and `activity_tile.dart`
  stays for the desktop home until step 11.
- 2026-10-24: step 10.a split in two. Swapping the sidebar body orphans about 1,100 lines of private sidebar
  widgets and their tests, which the analyzer makes it delete at once, so 10.a.i lands the desktop Archived page and
  its footer entry alone, and 10.a.ii swaps the body, collapse, claim and palette. The Archived page shows nothing
  extra while the computer is disconnected: the connection pill and the footer recovery card already say so.
- 2026-10-25: step 10.a.ii keeps the sidebar's filtered claim through a project page in `ProjectViewingService`:
  list claims form a stack, so releasing the page's claim hands the list back to the sidebar's, with no cubit
  depending on another.
- 2026-10-25: step 10.b keeps the activity projection, because the desktop home's Needs you, Running and Recent
  sections read it until step 11. It drops only the projection's sidebar inputs (set-aside and sticky sessions);
  step 11 removes the rest with the home sections.
- 2026-10-25: step 11 measured well over 2,000 changed lines before its tests, so it splits into four stacked
  branches: 11.i the composer home, the palette and the Recent sessions removal; 11.ii the project page with its
  breadcrumbs and exits; 11.iii the session list's view mode; 11.iv the `projectSessions` route and the claim stack.
  The home follows `AllSessionsCubit.defaultProjectId` as the phone's composer pane does: it waits blank while the
  list loads, shows the shared prompt with no default (with no projects its picker offers only Open another
  folder…, replacing the old empty home), and crossfades between them. The palette's sessions cover every project,
  whatever the sidebar list's filter, search and chip (`AllSessionsState.everyProjectRows`), as its projects do.
- 2026-10-25: step 11.ii sends every exit that opened the project page to the home instead: Mark unread,
  archiving or deleting the open session, and New session's back from a direct open. Pages lose their project
  crumb (the new-session picker already names the project); a subtask keeps its Main session crumb. The sidebar's
  Add project opens New session in the added project, as the phone's picker does.
- 2026-10-25: step 11.iii still measured well over the soft cap, so the `projectSessions` route and the claim
  stack move to 11.iv. Besides the view mode, 11.iii removes `SessionListContent` and the git-context chain it
  alone read (`getGitContext`, `ProjectGitContext`, `RepoProvider` and the client's `getBaseBranch`). The bridge
  keeps serving `/project/base-branch` for older apps.
- 2026-10-25: step 11.iv returns `ProjectViewingService` to one list-claim slot, because `AllSessionsCubit` is
  now the only holder. It also drops the two project-page strings that 11.ii orphaned.
- No reduction of the retirement matrix has been requested or accepted.

## L3 matrix (2026-10-25)

**Setup:**

- The build is `main` at 8fc7ccac13 (step 12/13) with Flutter 3.47.7.
- A slot 1 dev bridge ran from source with an isolated home directory.
- The fixture projects under `/private/tmp`:
  - atlas-api;
  - echo-app;
  - bistro-web;
  - delta-docs, shown as delta-handbook after the rename cell;
  - comet-cli.
- The fixture sessions were OpenCode sessions.
- The devices were the headless iPhone 17 simulator `sesori-dev-1` and the iPad simulator `sesori-dev-1-ipad`.
- A published v1.6.0 bridge was used for the older-bridge cell.

**Evidence** is in `/tmp/app-simplification-l3/` on the test machine and is not committed. Names below drop `.png`;
`(mp4)` marks a recording. I checked each motion cell's recording for jumps with frame-change bursts and contact
sheets.

| Surface | Cell | Result | Evidence |
|---|---|---|---|
| iPhone portrait | Cold start on the merged list | Pass | `iphone-05` |
| iPhone portrait | Date groups; a status change never moves a row | Pass | `iphone-06` (mp4), `iphone-07` |
| iPhone portrait | Filter round trip | Pass | `iphone-08`, `iphone-09`, `iphone-12` |
| iPhone portrait | Archived across projects | Pass | `iphone-18`, `iphone-19` |
| iPhone portrait | New session in the default project | Pass | `iphone-13` |
| iPhone portrait | New session with “Open another folder…” | Pass | `iphone-10`, `iphone-11` |
| iPhone portrait | New session with no projects | Pass | `iphone-28`, `iphone-29` |
| iPhone portrait | Pull refresh imports, the row fades out, new rows slide in | Pass | `iphone-14` (mp4), `iphone-15`, `iphone-16`, `iphone-17` (mp4); `iphone-03` (mp4) and `iphone-04` are an earlier run |
| iPhone portrait | A notification opens over the list | Pass | `iphone-26`, `iphone-27` |
| iPhone portrait | Onboarding | Pass | `iphone-01`, `iphone-02` |
| iPhone portrait | Offline | Pass | `iphone-23` (mp4), `iphone-24`, `iphone-25` |
| iPhone portrait | A computer switch resets the filter | Pass | `iphone-20` |
| iPhone portrait | Settings › Projects rename and hide | Pass | `iphone-30` to `iphone-33` |
| iPhone landscape | Sidebar with the composer pane | Pass | `iphone-34` (mp4), `iphone-35` |
| iPhone landscape | Opening a session | Pass | `iphone-36` |
| iPhone landscape | Collapse and restore | **Fail** | `iphone-37`, `iphone-38-FAIL-…`, `iphone-39` |
| iPhone landscape | Rotation with a session open | Pass | `iphone-40`, `iphone-41`; collapse survives rotation in `iphone-42` |
| iPad portrait and landscape | Sidebar with the composer pane | **Fail** | `ipad-01-FAIL-…`; the draft follows a filter in `ipad-03`, `ipad-04` |
| iPad portrait and landscape | Opening a session | Pass | `ipad-06` |
| iPad portrait and landscape | Collapse and restore | Pass | `ipad-05` (mp4), `ipad-07` |
| iPad portrait and landscape | Rotation with a session open | Pass | `ipad-08`; collapse survives rotation in `ipad-09` |
| iPad portrait and landscape | Picker popover | Pass | `ipad-02` (portrait), `ipad-10` (landscape) |
| macOS desktop | The sidebar list and filter | Not executed | See reason 1 |
| macOS desktop | Collapse and resize | Not executed | See reason 1 |
| macOS desktop | Launch on the composer | Not executed | See reason 1 |
| macOS desktop | The palette filter | Not executed | See reason 1 |
| macOS desktop | Archived from the footer | Not executed | See reason 1 |
| macOS desktop | The folder picker | Not executed | See reason 1 |
| macOS desktop | Settings › Projects | Not executed | See reason 1 |
| Plugins | Refresh across every installed harness | Not executed | See reason 2; the OpenCode refresh passed in the pull refresh cell |
| Plugins | A failing harness shows the documented degradation | Not executed | See reason 3 |
| Plugins | A bridge older than v1.7.0 shows the documented degradation | Pass | `iphone-21` (mp4), `iphone-22`: a v1.6.0 bridge's pull is a plain reload with no scan row |

**Fail cells:**

1. **iPhone landscape, collapse and restore.**
   - With the sidebar collapsed, the pane's content ignores the left safe area. The transcript (the “1 step” chip
     and the reply) sits under the Dynamic Island.
   - Restoring the sidebar works.
   - Repro:
     1. On the iPhone 17 simulator, rotate to landscape-left.
     2. Open any session from the sidebar.
     3. Tap collapse in the sidebar footer.
   - `iphone-38` is a masked capture, so the island is drawn over the content.
2. **iPad, sidebar with the composer pane.**
   - On cold start, the pane's new-session draft named comet-cli. The top row was atlas-api's “Fixture fresh
     external run” (30 min old, against comet-cli's 41 min).
   - D15 sets the default to the project of the newest session, so the draft should name atlas-api.
   - Repro:
     1. Make comet-cli the first project in project order, for example by hiding it and opening it again.
     2. Cold launch the app on the iPad with no session open.
   - Likely cause, not fixed:
     - `HomeComposerPane` takes `AllSessionsCubit.state.defaultProjectId` in `initState`.
     - Its listener follows a changed default only while it holds no project.
     - So a default emitted before every project's sessions have loaded is kept by the hold-once-chosen rule. That
       rule is meant only for a later session turning newest.

**Not executed reasons:**

1. **macOS desktop.**
   - The debug `client/desktop` build uses bundle id `com.sesori.desktop`. That is the same id as the production
     Sesori.app installed on the test machine, which holds the owner's real account in its Application Support
     container and keychain.
   - Two `flutter run` desktop sessions from the owner's main checkout were also already running.
   - Launching the debug build would read and overwrite that real state and show real projects, paths and
     transcripts. This run allowed fixture data only.
   - Isolating it would need a product change, such as a separate bundle id or data directory, or a clean macOS
     user or machine.
2. **Refresh across every installed harness.**
   - The isolated bridge home routes only OpenCode:
     - `omp` is disabled in its config;
     - the Hermes availability probe fails;
     - no other harness is signed in there.
   - Covering every installed harness needs the owner's real home directory. The app would then list the machine's
     real projects, paths and transcripts.
3. **A failing harness.**
   - The documented partial failure needs two routable harnesses at once (see the L3 row in
     `docs/regression/projects-and-sessions.md`). The isolated home has one.
   - Failing OpenCode alone settles a refresh as a plain reload, which does not exercise the degradation.

**Observations outside the cells:**

- Opening a fixture project through the symlinked `/tmp` path and then pulling re-homed its sessions to the
  `/private/tmp` project. The run opened projects through `/private/tmp` instead. This is bridge path
  handling, outside this plan.
- After a mid-session bridge loss, a loaded list stays browsable under the “Bridge disconnected” banner, with the
  computer button reading connecting. The offline page appears when the picked computer is offline. This matches
  `ProjectInventoryService`.
- A project opened again through the bridge debug API while the phone home was showing did not appear until a later
  refresh. The list stayed on All · 7.
- While switching to an offline computer, the computer button's status dot was green during the skeleton, before
  the offline page replaced it (`iphone-23`).
- The `computer_switched` analytics event was not verified on the device, because the Flutter log of that run was
  lost.

## Review record

- 2026-10-24: `architecture-plan-review` rejected the first revision (not as too vague) with 10 findings. All
  were applied in the second revision except one, noted at the end:
  1. One signed-in `SessionScope` owns the inventories on the phone and desktop. No route-level instances, so
     `projectInventoryLoaded` keeps one reporter. Steps 3 and 4 now depend on 2.a.
  2. `DesktopSidebarRefreshService` and its cubit move into `module_core` as `SessionListRefreshService` and
     `SessionListRefreshCubit`; the invented `SessionListRefresher` is dropped. Every pull calls the cubit.
  3. The route tree is defined explicitly. The defs are redefined in place, every `projects` consumer moves to
     `home` in 7.b, desktop serves `home` from 7.b, and `projectPageVisibility` becomes `homeVisibility`.
  4. Claims:
     - `home` maps to the list claim;
     - archived mode never claims;
     - `AllSessionsCubit` owns the list and pane claims, with readiness tied to the filtered entry;
     - one active instance lives at the scope.
  5. The cubit emits a flat ordered row list, with headings left to the UI formatter. Query and chips are cubit
     inputs. Activity and list state come from the inventory, and archived rows from a new inventory projection.
  6. The scan state reaches lists through `SessionListRefreshCubit`. Settled failures carry plugin ids,
     `unsupported` is silent, and `CatalogScanFailureAlerts` is the single alert owner.
  7. `SessionListFilterTracker` replaces `SessionListFilterService`. It depends on
     `ProjectListService.listedProjects` and the connection tracker, and its only writer is
     `AllSessionsCubit.selectProject`.
  8. The D15 default is `AllSessionsCubit.defaultProjectId`. The zero-project composer state is specified.
  9. Removals are assigned to the steps that orphan them. `SessionSplitShell` hosts the new routes between 7.b and
     9, and 9 follows 8.
  10. Steps 2, 7 and 10 are pre-split.

  **Not applied:** the reviewer's route-only 7.a. A route-only step would move every path twice, because the
  per-project pages cannot sit in the new tree. Step 7 instead splits into Archived across projects (7.a) and the
  home switch (7.b). The revised plan was not re-reviewed.
