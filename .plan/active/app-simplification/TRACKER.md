# App simplification tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 2.a/13 and 5/13, which are independent.
- User decisions: D1–D16 in `PLAN.md`, agreed 2026-10-24 over two review rounds.

## Delivery

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/13 | Publish the plan | Done | #2027 |
| 2.a/13 | One session scope; every refresh imports | Not started | — |
| 2.b/13 | Scan cancel, dismiss, deep pull and per-harness scan removed | Not started | — |
| 3/13 | Searchable picker with Open another folder | Not started | — |
| 4/13 | Settings › Projects | Not started | — |
| 5/13 | Row logo and project label | Done | `sesori/app-simplification-step-5` |
| 6/13 | All-projects list model | Not started | — |
| 7.a/13 | Archived across projects | Not started | — |
| 7.b/13 | All-projects home and route tree | Not started | — |
| 8/13 | Projects screen removed | Not started | — |
| 9/13 | Wide phone and tablet sidebar | Not started | — |
| 10.a/13 | Desktop sidebar on the shared list | Not started | — |
| 10.b/13 | Desktop Activity and rail removed | Not started | — |
| 11/13 | Desktop composer home; project page removed | Not started | — |
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
