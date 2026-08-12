# Phone Harness Install — Tracker

| Step | PR | Status | Notes |
|---|---|---|---|
| 1/6 Raise the plan | #777 | merged | |
| 2/6 Capability, contracts, descriptor seams | #778 | merged | |
| 3/6 Bridge install command end to end | #779 | merged | |
| 4/6 Phone install button and progress | #780 | merged | |
| 5/6 Cursor managed runtime and install | — | ready for PR | Recovered the unpublished local successor, reconciled current `origin/main`, and refreshed the official `2026.08.11-e8db854` pin. |
| 6/6 Retire the plan | — | pending | |

## Working Rules

- One open PR at a time; build at most one successor branch locally.
- After a step merges, merge `origin/main` into the successor before opening it.
