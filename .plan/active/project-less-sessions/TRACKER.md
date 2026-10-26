# Project-less sessions tracker

## Current state

- Plan: [PLAN.md](PLAN.md).
- Current step: 6/7 in review.
- User decisions: D1–D15 in `PLAN.md`, agreed 2026-10-25 over two review rounds.

## Delivery

| Step | Outcome | State | PR/evidence |
|---|---|---|---|
| 1/7 | Publish the plan | Done | #2067 |
| 2/7 | Floating new-session button; Archived in Settings | Done | #2070 |
| 3/7 | Picker actions in a footer | Done | #2071 |
| 4/7 | Sesori folder and per-session scratch folders (inert) | Done | #2069 |
| 5/7 | No project project turned on | Done | #2074 |
| 6/7 | No project in the apps | In review | — |
| 7/7 | L3 matrix run; plan retired | Not started | — |

## Decision log

- 2026-10-25: two review rounds settled D1–D15.
  - Round 1 covered folders, defaults, the list label, folder lifetime, git, Archived and the floating +.
  - Round 2 covered the picker and switcher footers, and no bottom bar for now.
- 2026-10-25: D2 corrects round 1. `~/.sesori-worktrees` never reached a public release, so it gets no legacy path.
- 2026-10-25: the plan review's findings were applied.
  - Step order: inert scratch machinery first, then the row.
  - The docs-only step was folded into retirement.
  - Older apps' deletes keep the folder (`deleteSessionFolder` defaults to false).
  - The bridge refuses to hide "No project".
  - A folder is removed only when no session row still uses it.
- No reduction of the retirement matrix has been requested or accepted.

## Review record

- Architecture plan review, 2026-10-25: rejected with 14 findings, all applied directly.
  - Layering and ownership:
    - folder access goes through `FilesystemApi`;
    - `ScratchRepository` owns the row, with a named startup call before hydration;
    - `kind` maps by id in `ProjectRepository`;
    - the calculator is the single owner of the scratch-path rule;
    - the binding sites are listed, including active-root hydration.
  - Deletion: it reads the `DeletedSessionSubtree` and removes a folder only when unused.
  - Compatibility: the hide refusal, and the additive delete flag for older apps.
  - Client: the project-list derivations, and `kind` reaching analytics.
  - Steps: the order was swapped and the docs step folded.
  - Smaller items: the sealed footer, the private home helper, and the async delete.
