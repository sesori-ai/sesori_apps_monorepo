# Desktop UX — Tracker

Status values: `pending` / `in-progress` / `done` / `blocked`. Evidence for a
finished step lives in `steps/step-NN.md` (created when the step executes);
this table records state only and never mirrors PR review status.

There are 13 PRs across 12 logical steps. Step 2.a maps to PR ordinal 2;
step 2.b maps to ordinal 3; original steps 3–12 map to ordinals 4–13.
Step 2.a retains `steps/step-02.md`; its follow-up uses `steps/step-02b.md`.

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---|---|
| [x] | 1 | `desktop-release-plan` | `🌱 [desktop-ux] Plan the desktop cockpit UX overhaul [step 1/13]` | ≤ 900 | done |
| [x] | 2.a | `desktop-ux/sidebar-frame` | `⚙️ [desktop-ux] Add the resizable collapsible sidebar frame [step 2/13]` | ≤ 1,400 | done |
| [ ] | 2.b | `desktop-ux/sidebar-polish` | `🌿 [desktop-ux] Polish sidebar styling, motion, and activity signals [step 3/13]` | ≤ 900 | in-progress |
| [ ] | 3 | `desktop-ux/recent-sessions` | `⚙️ [desktop-ux] Show recent sessions per project in the sidebar [step 4/13]` | ≤ 1,200 | pending |
| [ ] | 4 | `desktop-ux/main-pane-routes` | `⚙️ [desktop-ux] Route the main pane through the sidebar [step 5/13]` | ≤ 1,400 | pending |
| [ ] | 5 | `desktop-ux/connection-pill` | `🌿 [desktop-ux] Overlay connection state without layout shift [step 6/13]` | ≤ 700 | pending |
| [ ] | 6 | `desktop-ux/bridge-popover` | `⚙️ [desktop-ux] Move bridge controls into a sidebar popover [step 7/13]` | ≤ 900 | pending |
| [ ] | 7 | `desktop-ux/settings-modal` | `⚙️ [desktop-ux] Present settings as a modal [step 8/13]` | ≤ 1,300 | pending |
| [ ] | 8 | `desktop-ux/first-run-defaults` | `🚧 [desktop-ux] Default bridge autostart and ask for macOS file access [step 9/13]` | ≤ 1,000 | pending |
| [ ] | 9 | `desktop-ux/app-log-files` | `🌿 [desktop-ux] Write app logs to rotating files [step 10/13]` | ≤ 700 | pending |
| [ ] | 10 | `desktop-ux/shortcuts-title-bar` | `🌿 [desktop-ux] Add keyboard shortcuts and macOS title-bar integration [step 11/13]` | ≤ 600 | pending |
| [ ] | 11 | `desktop-ux/regression-docs` | `🌿 [desktop-ux] Reconcile regression documentation [step 12/13]` | ≤ 600 | pending |
| [ ] | 12 | `desktop-ux/coverage-retire` | `🌿 [desktop-ux] Run coverage and retire the plan [step 13/13]` | ≤ 300 | pending |

Ordering constraints: 2.a → 2.b → 3 → 4 → 6 → 7; step 8 after 6; steps 5, 9
and 10 may run in any order after 4. Step 11 after every implementation step;
step 12 last. Only one PR is open; one local successor may be prepared.

## Delivery history

- Step 1: [PR #1484](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1484).
- Step 2.a: [PR #1488](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1488).
- Step 2.b: user-requested styling/motion/activity follow-up, not part of #1488.

## Accepted reductions

- Windows/Linux smoke-only final matrix: accepted by the user on 2026-09-15
  (recorded in `PLAN.md`, "Regression Documentation And Final Matrix").

## Verification Log

- Step 2.a: focused automated checks, macOS debug build, and architecture
  implementation review pass. Native project navigation observed; user confirms
  dragging, automatic collapse, and double-click reset. Peekaboo 4.4.0 was
  explicitly approved for this run without changing the repository's 4.2.2 pin.
  Full native appearance/accessibility/relaunch coverage is not claimed.
  See `steps/step-02.md`.
