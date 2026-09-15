# Desktop UX — Tracker

Status values: `pending` / `in-progress` / `done` / `blocked`. Evidence for a
finished step lives in `steps/step-NN.md` (created when the step executes);
this table records state only and never mirrors PR review status.

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---|---|
| [x] | 1 | `desktop-release-plan` | `🌱 [desktop-ux] Plan the desktop cockpit UX overhaul [step 1/12]` | ≤ 900 | done |
| [ ] | 2 | `desktop-ux/sidebar-frame` | `⚙️ [desktop-ux] Add the resizable collapsible sidebar frame [step 2/12]` | ≤ 1,200 | pending |
| [ ] | 3 | `desktop-ux/recent-sessions` | `⚙️ [desktop-ux] Show recent sessions per project in the sidebar [step 3/12]` | ≤ 1,200 | pending |
| [ ] | 4 | `desktop-ux/main-pane-routes` | `⚙️ [desktop-ux] Route the main pane through the sidebar [step 4/12]` | ≤ 1,400 | pending |
| [ ] | 5 | `desktop-ux/connection-pill` | `🌿 [desktop-ux] Overlay connection state without layout shift [step 5/12]` | ≤ 700 | pending |
| [ ] | 6 | `desktop-ux/bridge-popover` | `⚙️ [desktop-ux] Move bridge controls into a sidebar popover [step 6/12]` | ≤ 900 | pending |
| [ ] | 7 | `desktop-ux/settings-modal` | `⚙️ [desktop-ux] Present settings as a modal [step 7/12]` | ≤ 1,300 | pending |
| [ ] | 8 | `desktop-ux/first-run-defaults` | `🚧 [desktop-ux] Default bridge autostart and ask for macOS file access [step 8/12]` | ≤ 1,000 | pending |
| [ ] | 9 | `desktop-ux/app-log-files` | `🌿 [desktop-ux] Write app logs to rotating files [step 9/12]` | ≤ 700 | pending |
| [ ] | 10 | `desktop-ux/shortcuts-title-bar` | `🌿 [desktop-ux] Add keyboard shortcuts and macOS title-bar integration [step 10/12]` | ≤ 600 | pending |
| [ ] | 11 | `desktop-ux/regression-docs` | `🌿 [desktop-ux] Reconcile regression documentation [step 11/12]` | ≤ 600 | pending |
| [ ] | 12 | `desktop-ux/coverage-retire` | `🌿 [desktop-ux] Run coverage and retire the plan [step 12/12]` | ≤ 300 | pending |

Ordering constraints: 2 → 3 → 4 → 6 → 7; step 8 after 6; steps 5, 9 and 10
may run in any order after 4. Step 11 after every implementation step; step 12
last.

## Open acceptance

- Windows/Linux smoke-only reduction of the final matrix: pending the user's
  explicit acceptance in `PLAN.md` (see "Regression Documentation And Final
  Matrix"). Step 12 must not retire the plan under the reduced matrix without
  it.

## Verification Log

(empty until steps execute)
