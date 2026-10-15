# Computer management tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 7/8 in PR.
- User decisions: D1–D9 in `PLAN.md`, agreed 2026-10-15 over two review rounds.

## Delivery

| Step | Repository | Outcome | State | PR/evidence |
|---|---|---|---|---|
| 1/8 | monorepo | Publish the plan | Done | #1977 (merged 2026-10-15) |
| 2/8 | auth | Nicknames stored; summaries and pushes use them | Done | sesori_auth_server#96 (merged 2026-10-15) |
| 3/8 | monorepo | Flat Settings computer entry | Done | #1978 (merged 2026-10-15) |
| 4/8 | monorepo | Hostname, rename and remove in the computer list | Done | #1979 (merged 2026-10-15) |
| 5/8 | monorepo | Computers page with switch and rename | Done | #1982 (merged 2026-10-15) |
| 6/8 | monorepo | Remove offline computers | Done | #1985 (merged 2026-10-15) |
| 7/8 | monorepo | Reconcile regression documents | In PR | — |
| 8/8 | monorepo | Run the L3 matrix; retire | Not started | — |

## Evidence and decisions

- 2026-10-15: inspected these and recorded the findings in `PLAN.md` under “Current behavior”:
  - auth: the bridge schema, registration name overwrite, summary builder, revoke and push titles;
  - client: the bridge API and repository, `RegisteredBridgesService`, switching, `ComputerMenu` and its callers;
  - the Settings entry, the phone and desktop settings routes, desktop bridge control, analytics, and the Prego
    dialogs.
- 2026-10-15: round 1 of the UX review settled D1–D7 and D9. Round 2 settled D8, and the user corrected the D4
  wording: turning the bridge off makes the computer unreachable from this device too.
- No reduction of the retirement matrix has been requested or accepted.

## Review record

- 2026-10-15: `architecture-plan-review` rejected the first revision with 9 findings. All were applied in the same
  revision:
  - switching goes through the shell's `onSwitchComputer` callback, not a cubit;
  - the replacement pick moves to `SelectedComputerService`;
  - the rules are surface-neutral, using `localBridgeId`, and the desktop's removal of a viewed remote computer is
    recorded;
  - the page reuses `ComputerSwitcherCubit`, with `isThisComputer`/`canRemove` getters, and `ComputersCubit` keeps
    only the actions;
  - `RegisteredBridgesService` logs `computer_managed`;
  - one `localBridgeTurnOffActionBuilder` replaces two nullables;
  - the bridge registration response and its test fixtures are in scope;
  - one `displayName` in the auth service, with the rename chain named;
  - the phone route factory and mapping and the desktop `showDesktopComputersSettings` opener are named.
  Per `AGENTS.md` the applied fixes are not re-reviewed.
- 2026-10-15: `architecture-implementation-review` of step 5 rejected one finding: the rename sheet decided the
  nickname (blank or hostname clears it; unchanged sends nothing). Applied: `ComputersCubit.rename` takes the computer
  and the raw name and owns those rules, with cubit tests. The page's private `_RenameComputerSheet`, used instead of
  the shared `RenameSheet` because that sheet rejects empty input and owns its failure alert, was judged acceptable;
  `ComputersView` shows the rename failure alert.
- 2026-10-15: `architecture-implementation-review` of step 6 approved with no findings. It confirmed that the
  replacement pick lives in `SelectedComputerService`, that switching goes through the shell callback, and that making
  `PregoGroupedRowPosition` public (two users) is acceptable.
