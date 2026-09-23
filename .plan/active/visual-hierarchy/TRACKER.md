# Visual Hierarchy — Tracker

Status values: `pending` / `in-progress` / `done` / `blocked` / `dropped`.
Evidence for a finished step lives in `steps/step-NN.md` (created when the step
executes); this table records state only and never mirrors PR review status.
Step 1 is the plan itself, so it has no evidence file.

One PR at a time, in order. Steps 2–34 need no further input. Step 35 waits
for the user to scope the sign-in rebuild (PLAN D16). Step 36 is an approval
gate: it is built locally, shown as before and after screenshots of the
running app, and **no PR opens until the user explicitly approves it**. Steps
37–38 wait for that approval or for the user's explicit decision to drop or
defer step 36.

| Done | Step | Branch | Title | Target | State |
|---|---|---|---|---|---|
| [x] | 1 | `visual-hierarchy/plan` | [1/38](#pr-titles) | ≤ 1,000 | done |
| [ ] | 2 | `visual-hierarchy/motion` | [2/38](#pr-titles) | ≤ 250 | in-progress |
| [ ] | 3 | `visual-hierarchy/modal-entry` | [3/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 4 | `visual-hierarchy/anchored-pickers` | [4/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 5 | `visual-hierarchy/grey-ramp` | [5/38](#pr-titles) | ≤ 500 | pending |
| [ ] | 6 | `visual-hierarchy/title-ladder` | [6/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 7 | `visual-hierarchy/desktop-header` | [7/38](#pr-titles) | ≤ 500 | pending |
| [ ] | 8 | `visual-hierarchy/blue` | [8/38](#pr-titles) | ≤ 400 | pending |
| [ ] | 9 | `visual-hierarchy/size-tokens` | [9/38](#pr-titles) | ≤ 900 | pending |
| [ ] | 10 | `visual-hierarchy/diff-colours` | [10/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 11 | `visual-hierarchy/icons-and-case` | [11/38](#pr-titles) | ≤ 900 | pending |
| [ ] | 12 | `visual-hierarchy/sidebar` | [12/38](#pr-titles) | ≤ 700 | pending |
| [ ] | 13 | `visual-hierarchy/session-rows` | [13/38](#pr-titles) | ≤ 700 | pending |
| [ ] | 14 | `visual-hierarchy/needs-you-card` | [14/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 15 | `visual-hierarchy/settings-window` | [15/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 16 | `visual-hierarchy/changes-file-list` | [16/38](#pr-titles) | ≤ 800 | pending |
| [ ] | 17 | `visual-hierarchy/shared-activity` | [17/38](#pr-titles) | ≤ 900 | pending |
| [ ] | 18 | `visual-hierarchy/desktop-home` | [18/38](#pr-titles) | ≤ 800 | pending |
| [ ] | 19 | `visual-hierarchy/phone-search` | [19/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 20 | `visual-hierarchy/command-palette` | [20/38](#pr-titles) | ≤ 900 | pending |
| [ ] | 21 | `visual-hierarchy/project-rows` | [21/38](#pr-titles) | ≤ 500 | pending |
| [ ] | 22 | `visual-hierarchy/session-page` | [22/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 23 | `visual-hierarchy/new-session` | [23/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 24 | `visual-hierarchy/folder-browser` | [24/38](#pr-titles) | ≤ 500 | pending |
| [ ] | 25 | `visual-hierarchy/windows-drives` | [25/38](#pr-titles) | ≤ 500 | pending |
| [ ] | 26 | `visual-hierarchy/settings-states` | [26/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 27 | `visual-hierarchy/missing-folders` | [27/38](#pr-titles) | ≤ 400 | pending |
| [ ] | 28 | `visual-hierarchy/filtered-rows` | [28/38](#pr-titles) | ≤ 300 | pending |
| [ ] | 29 | `visual-hierarchy/archive-alert` | [29/38](#pr-titles) | ≤ 300 | pending |
| [ ] | 30 | `visual-hierarchy/failed-sends` | [30/38](#pr-titles) | ≤ 700 | pending |
| [ ] | 31 | `visual-hierarchy/live-transcript` | [31/38](#pr-titles) | ≤ 1,200 | pending |
| [ ] | 32 | `visual-hierarchy/tool-kinds` | [32/38](#pr-titles) | ≤ 1,200 | pending |
| [ ] | 33 | `visual-hierarchy/yolo` | [33/38](#pr-titles) | ≤ 500 | pending |
| [ ] | 34 | `visual-hierarchy/changes-count` | [34/38](#pr-titles) | ≤ 800 | pending |
| [ ] | 35 | `desktop-sign-in/plan` | [35/38](#pr-titles) | ≤ 600 | blocked on scoping |
| [ ] | 36 | `visual-hierarchy/header-backdrop` | [36/38](#pr-titles) | set at approval | blocked on approval |
| [ ] | 37 | `visual-hierarchy/regression-docs` | [37/38](#pr-titles) | ≤ 600 | pending |
| [ ] | 38 | `visual-hierarchy/retire` | [38/38](#pr-titles) | ≤ 300 | pending |

## Round 2 Answers

Answered 2026-09-23; every answer took the recommended option.

- **R1.1** Counts by kind, plus failures (PLAN D20).
- **R1.2** A group ends at every piece of text (D19).
- **R1.3** The jump button shows the live row, and a turning sparkle leads the
  title (D19).
- **R1.4** Running sub-agents are live rows and fold into the group; the pill
  by the composer stays (D19).
- **R2** A neutral chip in every session and a calm sentence in Settings
  (D21).
- **R3** Live numbers on Changes (D22).
- **R4** Outside worktrees fold into their repository; own plan later (D23).
- **R5** Edits fold into the group summary with no line counts (D20).
- **R6** Hide zero counts and use one minus sign (D20).

## PR Titles

1. `🌱 [visual-hierarchy] Plan the cross-surface visual hierarchy series [step 1/38]`
2. `🌿 [visual-hierarchy] Animate tool details and desktop page changes [step 2/38]`
3. `⚙️ [visual-hierarchy] Open sheets and dialogs through one modal entry point [step 3/38]`
4. `⚙️ [visual-hierarchy] Open model and command pickers as anchored popovers [step 4/38]`
5. `⚙️ [visual-hierarchy] Make tertiary text readable and section headers quieter [step 5/38]`
6. `⚙️ [visual-hierarchy] Give phone screens one title ladder [step 6/38]`
7. `⚙️ [visual-hierarchy] Add a breadcrumb header to desktop pages [step 7/38]`
8. `🌿 [visual-hierarchy] Keep blue for selection and calm the email form [step 8/38]`
9. `⚙️ [visual-hierarchy] Add icon size, radius and code text tokens [step 9/38]`
10. `⚙️ [visual-hierarchy] Derive diff colours from status tokens [step 10/38]`
11. `⚙️ [visual-hierarchy] Use one icon set and sentence case everywhere [step 11/38]`
12. `⚙️ [visual-hierarchy] Rebuild the desktop sidebar hierarchy [step 12/38]`
13. `⚙️ [visual-hierarchy] Lead session rows with status and keep the time visible [step 13/38]`
14. `⚙️ [visual-hierarchy] Dock one amber needs-you card above the composer [step 14/38]`
15. `⚙️ [visual-hierarchy] Simplify the desktop settings window [step 15/38]`
16. `⚙️ [visual-hierarchy] Add a file list to Changes [step 16/38]`
17. `🚧 [visual-hierarchy] Share the activity projection and show Activity on the phone [step 17/38]`
18. `⚙️ [visual-hierarchy] Start sessions from the desktop home and empty projects [step 18/38]`
19. `⚙️ [visual-hierarchy] Search project and session titles on the phone [step 19/38]`
20. `🚧 [visual-hierarchy] Add a Cmd+K command palette to the desktop [step 20/38]`
21. `🌿 [visual-hierarchy] Tell projects apart and open the one just added [step 21/38]`
22. `⚙️ [visual-hierarchy] Say who is working and tidy code blocks and composer tools [step 22/38]`
23. `⚙️ [visual-hierarchy] Simplify the new session page [step 23/38]`
24. `🌿 [visual-hierarchy] Give the folder browser a title, breadcrumb and clear states [step 24/38]`
25. `⚙️ [visual-hierarchy] List Windows drives in the folder browser [step 25/38]`
26. `⚙️ [visual-hierarchy] Say each settings state once and confirm sign-out [step 26/38]`
27. `⚙️ [visual-hierarchy] Show projects whose folder is missing [step 27/38]`
28. `🌿 [visual-hierarchy] Build filtered session rows as they appear [step 28/38]`
29. `🌿 [visual-hierarchy] Keep the archive Undo visible when an archive fails [step 29/38]`
30. `🚧 [visual-hierarchy] Show failed sends under the message with Retry [step 30/38]`
31. `🚧 [visual-hierarchy] Group transcript steps and show live progress [step 31/38]`
32. `🚧 [visual-hierarchy] Report tool kinds from every plugin [step 32/38]`
33. `⚙️ [visual-hierarchy] Show when YOLO is on [step 33/38]`
34. `🚧 [visual-hierarchy] Show live change counts on Changes [step 34/38]`
35. `🌱 [visual-hierarchy] Plan the desktop sign-in rebuild [step 35/38]`
36. `⚙️ [visual-hierarchy] Give headers a soft backdrop [step 36/38]`
37. `🌱 [visual-hierarchy] Reconcile regression docs [step 37/38]`
38. `🌱 [visual-hierarchy] Record the final matrix and retire the plan [step 38/38]`
