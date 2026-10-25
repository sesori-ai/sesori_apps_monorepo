# App simplification tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 12/13 follows 11/13.
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
| 11.iii/13 | Session list view mode removed | Done | `sesori/app-simplification-step-11-iii` |
| 11.iv/13 | Project-sessions route and list-claim stack removed | Done | `sesori/app-simplification-step-11-iv` |
| 12/13 | Regression documents reconciled | Not started | — |
| 13/13 | L3 matrix run; plan retired | Not started | — |

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
