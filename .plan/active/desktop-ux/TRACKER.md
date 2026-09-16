# Desktop UX — Tracker

Status values: `pending` / `in-progress` / `done` / `blocked`. Evidence for a
finished step lives in `steps/step-NN.md` (created when the step executes);
this table records state only and never mirrors PR review status.

There are 17 PRs across 12 logical steps. Step 2.a/2.b map to ordinals 2/3;
original 3–6 to 4–7; 7.a/7.b/7.c to 8/9/10; step 8 to 11.
Logging remains ordinal 12 as 9.a; sidebar follow-ups 9.b/9.c are 13/14;
original steps 10–12 are 15–17. Earlier evidence filenames stay unchanged;
logging and its follow-ups use `step-09a.md`, `step-09b.md`, `step-09c.md`.

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---|---|
| [x] | 1 | `desktop-release-plan` | `🌱 [desktop-ux] Plan the desktop cockpit UX overhaul [step 1/17]` | ≤ 900 | done |
| [x] | 2.a | `desktop-ux/sidebar-frame` | `⚙️ [desktop-ux] Add the resizable collapsible sidebar frame [step 2/17]` | ≤ 1,400 | done |
| [x] | 2.b | `desktop-ux/sidebar-polish` | `🌿 [desktop-ux] Polish sidebar styling, motion, and activity signals [step 3/17]` | ≤ 900 | done |
| [x] | 3 | `desktop-ux/recent-sessions` | `⚙️ [desktop-ux] Show recent sessions per project in the sidebar [step 4/17]` | ≤ 1,200 | done |
| [x] | 4 | `desktop-ux/main-pane-routes` | `⚙️ [desktop-ux] Route the main pane through the sidebar [step 5/17]` | ≤ 1,400 | done |
| [x] | 5 | `desktop-ux/connection-pill` | `🌿 [desktop-ux] Overlay connection state without layout shift [step 6/17]` | ≤ 700 | done |
| [x] | 6 | `desktop-ux/bridge-popover` | `⚙️ [desktop-ux] Move bridge controls into a sidebar popover [step 7/17]` | ≤ 1,500 | done |
| [x] | 7.a | `desktop-ux/settings-composition` | `🌿 [desktop-ux] Prepare shared settings composition [step 8/17]` | ≤ 500 | done |
| [x] | 7.b | `desktop-ux/overlay-navigation` | `🚧 [desktop-ux] Preserve session focus across root overlays [step 9/17]` | ≤ 700 | done |
| [x] | 7.c | `desktop-ux/settings-modal` | `⚙️ [desktop-ux] Present settings as a modal [step 10/17]` | ≤ 1,750 | done |
| [x] | 8 | `desktop-ux/first-run-defaults` | `🚧 [desktop-ux] Default bridge autostart and ask for macOS file access [step 11/17]` | ≤ 1,000 | done |
| [ ] | 9.a | `desktop-ux/app-logs` | `⚙️ [desktop-ux] Write app logs to rotating files [step 12/17]` | ≤ 1,450 | in-progress |
| [ ] | 9.b | `desktop-ux/sidebar-interactions` | `🌿 [desktop-ux] Fix sidebar resizing and project hit targets [step 13/17]` | ≤ 500 | pending |
| [ ] | 9.c | `desktop-ux/sidebar-activity-controls` | `⚙️ [desktop-ux] Prioritize sidebar activity and simplify controls [step 14/17]` | ≤ 1,200 | pending |
| [ ] | 10 | `desktop-ux/shortcuts-title-bar` | `🌿 [desktop-ux] Add keyboard shortcuts and macOS title-bar integration [step 15/17]` | ≤ 600 | pending |
| [ ] | 11 | `desktop-ux/regression-docs` | `🌿 [desktop-ux] Audit controls and reconcile regression documentation [step 16/17]` | ≤ 600 | pending |
| [ ] | 12 | `desktop-ux/coverage-retire` | `🌿 [desktop-ux] Run coverage and retire the plan [step 17/17]` | ≤ 300 | pending |

Next: 9.a → 9.b → 9.c → 10 → 11 → 12. The sidebar additions implement the
user's drag/hit-target, priority activity, footer/wording, refresh, animation and
tooltip feedback. Only one PR is open; one local successor may be prepared.

## Delivery history

- Step 1: [PR #1484](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1484).
- Step 2.a: [PR #1488](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1488).
- Step 2.b: [PR #1491](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1491),
  user-requested styling/motion/activity follow-up, not part of #1488.
- Step 3: [PR #1494](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1494).
- Step 4: [PR #1496](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1496).

- Step 5: [PR #1497](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1497).
- Step 6: [PR #1498](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1498).
- Step 7.a: [PR #1500](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1500).
- Step 7.b: [PR #1502](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1502).
- Step 7.c: [PR #1501](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1501),
  merged after #1502's forward integration, preserving published history without force-pushing.
- Step 8: [PR #1505](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1505).

## Unattended execution

The user reaffirmed autonomous completion on 2026-09-15: do not stop/restart
or take over the running bridge. Continue every implementation, review and
merge step without questions. Record checks that cannot be performed safely
for the final testing decision; this does not claim unexecuted coverage passed
or waive shipping qualification.

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
- Step 2.b: 18 desktop widget tests, 2 avatar tests, both owning analyzers, and
  five font-loaded render probes pass. Light/dark expanded and compact previews
  were shown to the user; the current GUI and bridge were left untouched.
  Native macOS rendering is retained; 18 tests pass after restoration. An
  isolated debug probe built and started, but its native inspection attempt
  met a locked macOS session. Profile mode also hit a pinned-SDK AOT failure.
  These native checks remain required plan-level coverage, not a draft/review
  gate. Neither previews nor startup establish native interaction/performance
  coverage. See `steps/step-02b.md`.
- Step 3: focused cache/list/service, sidebar/storage and cockpit/router checks,
  all five owning analyzers, four inspected production-widget fixtures, and
  architecture implementation review pass. The GUI and bridge remain untouched.
  Native tree/menu/performance and live-action checks remain pre-shipping
  coverage, not a merge/successor gate. See [step 3 evidence](steps/step-03.md#reproducible-verification-and-size)
  for measured revisions, cwd, commands and size accounting.
- Step 4: 149 distinct focused desktop/mobile/shared UI/font/avatar cases pass
  across scoped checkpoints, with affected home/cockpit/avatar tests rerun after
  small follow-ups. Five font-loaded fixtures and all three owning analyzers pass. Native
  route/action/performance coverage remains pre-shipping work. Architecture
  review approved the frozen routing scope. PR feedback then corrected explicit
  detail Back presentation; 34 affected tests, two header fixtures and desktop
  analysis pass. See [step 4 evidence](steps/step-04.md).
- Step 5: 25 cockpit and 9 shared grace tests, six inspected font-loaded fixtures,
  and both owning analyzers pass across documented checkpoints. Architecture
  review approves the frozen implementation. Native/live coverage remains
  pre-shipping work; the GUI and bridge were untouched.
  See [step 5 evidence](steps/step-05.md).
- Step 6: user review prompted a content/label audit, removal of app-scoped
  popover options and explicit contextual bridge actions. 133 currently relevant
  cases pass across documented checkpoints, including canonical-home notification
  routing; plus three revised real-font renders
  and all owning analyzers. The running GUI/bridge remain untouched; native work
  stays in the final testing handoff. See [step 6 evidence](steps/step-06.md).
- Step 7.a: 68 focused cases across native preference commands and existing
  desktop/mobile settings consumers; four analyzers and fresh scoped
  architecture review pass. No visible navigation change or native mutation.
  See `steps/step-07a.md`; modal delivery is now step 7.c.
- Step 7.b: 97 distinct focused cases pass across pinned checkpoints; all five
  affected analyzers and scoped architecture plan/implementation reviews pass.
  No production app/DI/native/bridge work was run.
  See [step 7.b evidence](steps/step-07b.md); native/live qualification is unchanged.
- Step 7.c: 61 revision-scoped desktop cases, clean analysis and three fresh inspected fixtures.
  Earlier mobile/shared-UI evidence is retained, not rerun; see [step 7.c evidence](steps/step-07c.md).
  The 250% shared-header overflow remains for step 11; native qualification is not waived.
- Step 8 (#1505): 150 distinct retained revision-scoped cases (96 rerun for review fixes),
  three owning analyzers and four inspected synthetic renders. Follow-up scoped
  architecture review approved; no native permission, login registration or production
  bridge work ran. See [step 8 evidence](steps/step-08.md).
- Step 9.a: 91 distinct retained cases, five owning analyzers and frozen-scope
  implementation architecture review pass. Tests use fakes/temporary directories, not production
  startup or native folder opening. See [logging evidence](steps/step-09a.md).
  New sidebar work is planned only, not included in this implementation.
