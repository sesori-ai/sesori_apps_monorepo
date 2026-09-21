# Desktop UI Polish — Tracker

Status values: `pending` / `in-progress` / `done` / `blocked`. Evidence for a
finished step lives in `steps/step-NN.md` (created when the step executes);
this table records state only and never mirrors PR review status. Step 1 is
the plan itself, so it has no evidence file.

One PR at a time, in order. Step 15 carries an approval gate: it is built
locally, shown to the user as screenshots of the running app, and **no PR is
opened until the user explicitly approves the actual UI**. Steps 21–22 wait
for that approval or for the user's explicit decision to drop or defer it;
steps 16–20 do not.

The series total grew from 17 to 22 on 2026-09-21 (PLAN D20: what suits the
phone is built shared). Steps 1–12 were published with `/17` titles and keep
them.

| Done | Step | Branch | Title | Target | State |
|---|---|---|---|---|---|
| [x] | 1 | `ux-review-ui-polish-plan` | [1/17](#pr-titles) | ≤ 1,100 | done |
| [x] | 2 | `desktop-ui-polish/new-session-primary` | [2/17](#pr-titles) | ≤ 350 | done |
| [x] | 3 | `desktop-ui-polish/activity-in-motion` | [3/17](#pr-titles) | ≤ 600 | done |
| [x] | 4 | `desktop-ui-polish/sidebar-sections` | [4/17](#pr-titles) | ≤ 700 | done |
| [x] | 5 | `desktop-ui-polish/rail` | [5/17](#pr-titles) | ≤ 400 | done |
| [x] | 6 | `desktop-ui-polish/floating-panel` | [6/17](#pr-titles) | ≤ 450 | done |
| [x] | 7 | `desktop-ui-polish/title-bar` | [7/17](#pr-titles) | ≤ 350 | done |
| [x] | 8 | `desktop-ui-polish/pointer-menus` | [8/17](#pr-titles) | ≤ 500 | done |
| [x] | 9 | `desktop-ui-polish/project-page` | [9/17](#pr-titles) | ≤ 800 | done |
| [x] | 10 | `desktop-ui-polish/project-page-filters` | [10/17](#pr-titles) | ≤ 500 | done |
| [x] | 11 | `desktop-ui-polish/session-toolbar` | [11/17](#pr-titles) | ≤ 700 | done |
| [x] | 12 | `desktop-ui-polish/archive-undo` | [12/17](#pr-titles) | ≤ 900 | done |
| [x] | 13 | `desktop-ui-polish/new-session-page` | [13/22](#pr-titles) | ≤ 600 | done |
| [x] | 14 | `desktop-ui-polish/agent-entry` | [14/22](#pr-titles) | ≤ 600 | done |
| [ ] | 15 | `desktop-ui-polish/composer-and-sub-agents` | [15/22](#pr-titles) | set at approval | pending (gated) |
| [x] | 16 | `desktop-ui-polish/phone-timeline` | [16/22](#pr-titles) | ≤ 500 | done |
| [x] | 17 | `desktop-ui-polish/shared-filter-chips` | [17/22](#pr-titles) | ≤ 500 | done |
| [ ] | 18 | `desktop-ui-polish/shared-archive-undo` | [18/22](#pr-titles) | ≤ 900 | pending |
| [ ] | 19 | `desktop-ui-polish/phone-session-actions` | [19/22](#pr-titles) | ≤ 500 | pending |
| [ ] | 20 | `desktop-ui-polish/shared-cleanup` | [20/22](#pr-titles) | ≤ 400 | pending |
| [ ] | 21 | `desktop-ui-polish/regression-docs` | [21/22](#pr-titles) | ≤ 400 | pending |
| [ ] | 22 | `desktop-ui-polish/coverage-retire` | [22/22](#pr-titles) | ≤ 300 | pending |

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
- 13/22: `⚙️ [desktop-ui-polish] Centre the new session page and share its header [step 13/22]`
- 14/22: `⚙️ [desktop-ui-polish] Stop presenting harness modes as agents [step 14/22]`
- 15/22: `⚙️ [desktop-ui-polish] Restyle composer selectors and the sub-agents bar [step 15/22]`
- 16/22: `⚙️ [desktop-ui-polish] Show the phone session list as one timeline [step 16/22]`
- 17/22: `🌿 [desktop-ui-polish] Share the session filter chips with the phone [step 17/22]`
- 18/22: `⚙️ [desktop-ui-polish] Archive with Undo on the phone [step 18/22]`
- 19/22: `🌿 [desktop-ui-polish] Share Mark unread and session actions with the phone [step 19/22]`
- 20/22: `🌿 [desktop-ui-polish] Delete what the shared implementations replaced [step 20/22]`
- 21/22: `🌿 [desktop-ui-polish] Reconcile regression documents [step 21/22]`
- 22/22: `🌱 [desktop-ui-polish] Run final coverage and retire the plan [step 22/22]`

A clean split keeps the series total: a split step takes letter suffixes
(14.a, 14.b) and the titles above are renumbered once, in the PR that
introduces the split.
