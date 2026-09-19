# Desktop UI Polish — Tracker

Status values: `pending` / `in-progress` / `done` / `blocked`. Evidence for a
finished step lives in `steps/step-NN.md` (created when the step executes);
this table records state only and never mirrors PR review status.

One PR at a time, in order. Step 15 carries an approval gate: it is built
locally, shown to the user as screenshots of the running app, and **no PR is
opened until the user explicitly approves the actual UI**. Steps 16–17 wait
for that approval or for the user's explicit decision to drop or defer it.

| Done | Step | Branch | Title | Target | State |
|---|---|---|---|---|---|
| [ ] | 1 | `ux-review-ui-polish-plan` | [1/17](#pr-titles) | ≤ 1,100 | in-progress |
| [ ] | 2 | `desktop-ui-polish/new-session-primary` | [2/17](#pr-titles) | ≤ 350 | pending |
| [ ] | 3 | `desktop-ui-polish/activity-in-motion` | [3/17](#pr-titles) | ≤ 600 | pending |
| [ ] | 4 | `desktop-ui-polish/sidebar-sections` | [4/17](#pr-titles) | ≤ 700 | pending |
| [ ] | 5 | `desktop-ui-polish/rail` | [5/17](#pr-titles) | ≤ 400 | pending |
| [ ] | 6 | `desktop-ui-polish/floating-panel` | [6/17](#pr-titles) | ≤ 450 | pending |
| [ ] | 7 | `desktop-ui-polish/title-bar` | [7/17](#pr-titles) | ≤ 350 | pending |
| [ ] | 8 | `desktop-ui-polish/pointer-menus` | [8/17](#pr-titles) | ≤ 500 | pending |
| [ ] | 9 | `desktop-ui-polish/project-page` | [9/17](#pr-titles) | ≤ 800 | pending |
| [ ] | 10 | `desktop-ui-polish/project-page-filters` | [10/17](#pr-titles) | ≤ 500 | pending |
| [ ] | 11 | `desktop-ui-polish/session-toolbar` | [11/17](#pr-titles) | ≤ 700 | pending |
| [ ] | 12 | `desktop-ui-polish/archive-undo` | [12/17](#pr-titles) | ≤ 900 | pending |
| [ ] | 13 | `desktop-ui-polish/new-session-page` | [13/17](#pr-titles) | ≤ 500 | pending |
| [ ] | 14 | `desktop-ui-polish/agent-entry` | [14/17](#pr-titles) | ≤ 1,000 | pending |
| [ ] | 15 | `desktop-ui-polish/composer-and-sub-agents` | [15/17](#pr-titles) | set at approval | pending (gated) |
| [ ] | 16 | `desktop-ui-polish/regression-docs` | [16/17](#pr-titles) | ≤ 400 | pending |
| [ ] | 17 | `desktop-ui-polish/coverage-retire` | [17/17](#pr-titles) | ≤ 300 | pending |

### PR titles

- 1/17: `🌱 [desktop-ui-polish] Plan the desktop UI polish series [step 1/17]`
- 2/17: `🌿 [desktop-ui-polish] Make New session the primary action [step 2/17]`
- 3/17: `⚙️ [desktop-ui-polish] Show only sessions in motion in Activity [step 3/17]`
- 4/17: `⚙️ [desktop-ui-polish] Label sidebar sections and show more in place [step 4/17]`
- 5/17: `🌿 [desktop-ui-polish] Give every rail button one meaning [step 5/17]`
- 6/17: `⚙️ [desktop-ui-polish] Float the sidebar as an elevated panel [step 6/17]`
- 7/17: `⚙️ [desktop-ui-polish] Unify the macOS title bar with the window [step 7/17]`
- 8/17: `🌿 [desktop-ui-polish] Open compact menus at the pointer [step 8/17]`
- 9/17: `⚙️ [desktop-ui-polish] Rebuild the project page as one timeline [step 9/17]`
- 10/17: `⚙️ [desktop-ui-polish] Add project page filters and hover actions [step 10/17]`
- 11/17: `⚙️ [desktop-ui-polish] Give the session page a toolbar and centred column [step 11/17]`
- 12/17: `⚙️ [desktop-ui-polish] Archive with Undo and compact alerts [step 12/17]`
- 13/17: `⚙️ [desktop-ui-polish] Centre the new session page [step 13/17]`
- 14/17: `⚙️ [desktop-ui-polish] Stop presenting harness modes as agents [step 14/17]`
- 15/17: `⚙️ [desktop-ui-polish] Restyle composer selectors and the sub-agents bar [step 15/17]`
- 16/17: `🌿 [desktop-ui-polish] Reconcile regression documents [step 16/17]`
- 17/17: `🌱 [desktop-ui-polish] Run final coverage and retire the plan [step 17/17]`

A clean split keeps the series total: a split step takes letter suffixes
(14.a, 14.b) and the titles above are renumbered once, in the PR that
introduces the split.
