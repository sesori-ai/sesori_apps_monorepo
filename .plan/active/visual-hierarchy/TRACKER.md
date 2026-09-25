# Visual Hierarchy — Tracker

Status values: `pending` / `in-progress` / `done` / `blocked` / `dropped`.
Evidence for a finished step lives in `steps/step-NN.md` (created when the step
executes); this table records state only and never mirrors PR review status.
Step 1 is the plan itself, so it has no evidence file.

One PR at a time, in order. Steps 2–36 need no further input. Step 37 is a
discussion backed by prototypes; no production code before the user picks a
direction. Step 38 waits for the user to scope the sign-in rebuild (PLAN
D16). Step 39 is an approval gate: it is built locally, shown as before and
after screenshots of the running app, and **no PR opens until the user
explicitly approves it**. Steps 40–41 wait for that approval or for the
user's explicit decision to drop or defer step 39. Steps 35–37 were added on
2026-09-23, which moved the total from 38 to 41; steps 1–3 merged as `/38`.

| Done | Step | Branch | Title | Target | State |
|---|---|---|---|---|---|
| [x] | 1 | `visual-hierarchy/plan` | [1/38](#pr-titles) | ≤ 1,000 | done |
| [x] | 2 | `visual-hierarchy/motion` | [2/38](#pr-titles) | ≤ 250 | done |
| [x] | 3 | `visual-hierarchy/modal-entry` | [3/38](#pr-titles) | ≤ 600 | done |
| [x] | 4 | `visual-hierarchy/anchored-pickers-{a,b,c}` | [4/41](#pr-titles) | see PLAN | done |
| [x] | 5 | `visual-hierarchy/grey-ramp` | [5/41](#pr-titles) | ≤ 500 | done |
| [x] | 6 | `visual-hierarchy/title-ladder` | [6/41](#pr-titles) | ≤ 600 | done |
| [x] | 7 | `visual-hierarchy/desktop-header` | [7/41](#pr-titles) | ≤ 500 | done |
| [x] | 8 | `visual-hierarchy/blue` | [8/41](#pr-titles) | ≤ 400 | done |
| [x] | 9 | `visual-hierarchy/icon-mono-tokens` | [9/41](#pr-titles) | ≤ 900 | done |
| [x] | 10 | `visual-hierarchy/diff-colours` | [10/41](#pr-titles) | ≤ 600 | done |
| [x] | 11 | `visual-hierarchy/{icons-and-case,sentence-case}` | [11/41](#pr-titles) | ≤ 900 | done |
| [x] | 12 | `visual-hierarchy/{sidebar,sidebar-new-session}` | [12/41](#pr-titles) | ≤ 700 | done |
| [x] | 13 | `visual-hierarchy/{subtitle-ellipsis,session-rows}` | [13/41](#pr-titles) | ≤ 700 | done |
| [x] | 14 | `visual-hierarchy/needs-you-card` | [14/41](#pr-titles) | ≤ 600 | done |
| [x] | 15 | `visual-hierarchy/{settings-window,bridge-popover}` | [15/41](#pr-titles) | ≤ 600 | done |
| [x] | 16 | `visual-hierarchy/{changes-file-list,changes-split}` | [16/41](#pr-titles) | ≤ 800 | done |
| [x] | 17 | `visual-hierarchy/{shared-activity,phone-activity}` | [17/41](#pr-titles) | ≤ 900 | done |
| [x] | 18 | `visual-hierarchy/{desktop-home,empty-project-composer}` | [18/41](#pr-titles) | ≤ 800 | done |
| [x] | 19 | `visual-hierarchy/phone-search` | [19/41](#pr-titles) | ≤ 600 | done |
| [x] | 20 | `visual-hierarchy/command-palette` | [20/41](#pr-titles) | ≤ 900 | done |
| [x] | 21 | `visual-hierarchy/project-rows` | [21/41](#pr-titles) | ≤ 500 | done |
| [x] | 22 | `visual-hierarchy/{session-subtitle,composer-fold,code-blocks}` | [22/41](#pr-titles) | ≤ 600 | done |
| [x] | 23 | `visual-hierarchy/new-session` | [23/41](#pr-titles) | ≤ 600 | done |
| [x] | 24 | `visual-hierarchy/folder-browser` | [24/41](#pr-titles) | ≤ 500 | done |
| [x] | 25 | `visual-hierarchy/windows-drives` | [25/41](#pr-titles) | ≤ 500 | done |
| [x] | 26 | `visual-hierarchy/settings-states` | [26/41](#pr-titles) | ≤ 600 | done |
| [x] | 27 | `visual-hierarchy/missing-folders` | [27/41](#pr-titles) | ≤ 400 | done |
| [x] | 28 | `visual-hierarchy/filtered-rows` | [28/41](#pr-titles) | ≤ 300 | done |
| [x] | 29 | `visual-hierarchy/archive-alert` | [29/41](#pr-titles) | ≤ 300 | done |
| [x] | 30 | `visual-hierarchy/failed-sends` | [30/41](#pr-titles) | ≤ 700 | done |
| [x] | 31 | `visual-hierarchy/live-transcript` | [31/41](#pr-titles) | ≤ 1,200 | done (2 parts) |
| [ ] | 32 | `visual-hierarchy/tool-kinds` | [32/41](#pr-titles) | ≤ 1,200 | pending |
| [ ] | 33 | `visual-hierarchy/yolo` | [33/41](#pr-titles) | ≤ 500 | pending |
| [x] | 34 | `visual-hierarchy/changes-count` | [34/41](#pr-titles) | ≤ 800 | done |
| [ ] | 35 | `visual-hierarchy/modal-lint` | [35/41](#pr-titles) | ≤ 600 | pending |
| [ ] | 36 | `visual-hierarchy/compaction-row` | [36/41](#pr-titles) | ≤ 900 | pending |
| [ ] | 37 | `visual-hierarchy/turn-navigation` | [37/41](#pr-titles) | later | blocked on discussion |
| [ ] | 38 | `desktop-sign-in/plan` | [38/41](#pr-titles) | ≤ 600 | blocked on scoping |
| [ ] | 39 | `visual-hierarchy/header-backdrop` | [39/41](#pr-titles) | set at approval | blocked on approval |
| [ ] | 40 | `visual-hierarchy/regression-docs` | [40/41](#pr-titles) | ≤ 600 | pending |
| [ ] | 41 | `visual-hierarchy/retire` | [41/41](#pr-titles) | ≤ 300 | pending |

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
4. Three PRs:
   - `⚙️ [visual-hierarchy] Let popovers cap their height and follow a moving trigger [step 4.a/41]`
   - `⚙️ [visual-hierarchy] Open the model picker as an anchored popover [step 4.b/41]`
   - `⚙️ [visual-hierarchy] Open the command picker as an anchored popover [step 4.c/41]`
5. `⚙️ [visual-hierarchy] Make tertiary text readable and section headers quieter [step 5/41]`
6. `⚙️ [visual-hierarchy] Give phone screens one title ladder [step 6/41]`
7. `⚙️ [visual-hierarchy] Add a breadcrumb header to desktop pages [step 7/41]`
8. `🌿 [visual-hierarchy] Keep blue for selection and calm the email form [step 8/41]`
9. `⚙️ [visual-hierarchy] Add icon size, radius and code text tokens [step 9/41]`
10. `⚙️ [visual-hierarchy] Derive diff colours from status tokens [step 10/41]`
11. Split in two:
   - `🌿 [visual-hierarchy] Use one icon set everywhere [step 11.a/41]`
   - `🌿 [visual-hierarchy] Use sentence case everywhere [step 11.b/41]`
12. Split in two:
   - `⚙️ [visual-hierarchy] Rebuild the desktop sidebar hierarchy [step 12.a/41]`
   - `🌿 [visual-hierarchy] Replace the sidebar's New session button and slim its footer [step 12.b/41]`
13. Split in two:
   - `🌿 [visual-hierarchy] Shorten long slugs in the middle and drop the subtitle popover [step 13.a/41]`
   - `⚙️ [visual-hierarchy] Lead session rows with status and keep the time visible [step 13.b/41]`
14. `⚙️ [visual-hierarchy] Dock one amber needs-you card above the composer [step 14/41]`
15. `⚙️ [visual-hierarchy] Simplify the desktop settings window [step 15/41]`
   - `⚙️ [visual-hierarchy] Simplify the desktop settings window [step 15.a/41]`
   - `🌿 [visual-hierarchy] Quiet the bridge popover [step 15.b/41]`
16. `⚙️ [visual-hierarchy] Add a file list to Changes [step 16/41]`
   - `🌿 [visual-hierarchy] List changed files at the top of Changes [step 16.a/41]`
   - `⚙️ [visual-hierarchy] Split desktop Changes into a file list and one diff [step 16.b/41]`
17. `🚧 [visual-hierarchy] Share the activity projection and show Activity on the phone [step 17/41]`
   - `🌿 [visual-hierarchy] Share the activity projection [step 17.a/41]`
   - `⚙️ [visual-hierarchy] Show Activity at the top of the phone's Projects [step 17.b/41]`
18. `⚙️ [visual-hierarchy] Start sessions from the desktop home and empty projects [step 18/41]`
   - `⚙️ [visual-hierarchy] Start sessions from the desktop home [step 18.a/41]`
   - `🌿 [visual-hierarchy] Show the composer in an empty project [step 18.b/41]`
19. `⚙️ [visual-hierarchy] Search project and session titles on the phone [step 19/41]`
20. `🚧 [visual-hierarchy] Add a Cmd+K command palette to the desktop [step 20/41]`
21. `🌿 [visual-hierarchy] Tell projects apart and open the one just added [step 21/41]`
22. `⚙️ [visual-hierarchy] Say who is working and tidy code blocks and composer tools [step 22/41]`
   - `🌿 [visual-hierarchy] Name the harness and model under the session title [step 22.a/41]`
   - `🌿 [visual-hierarchy] Give code blocks the tool output inset and cap long ones [step 22.b/41]`
   - `🌿 [visual-hierarchy] Fold the composer tools away while typing [step 22.c/41]`
23. `⚙️ [visual-hierarchy] Simplify the new session page [step 23/41]`
24. `🌿 [visual-hierarchy] Give the folder browser a title, breadcrumb and clear states [step 24/41]`
25. `⚙️ [visual-hierarchy] List Windows drives in the folder browser [step 25/41]`
26. `⚙️ [visual-hierarchy] Say each settings state once and confirm sign-out [step 26/41]`
27. `⚙️ [visual-hierarchy] Show projects whose folder is missing [step 27/41]`
28. `🌿 [visual-hierarchy] Build filtered session rows as they appear [step 28/41]`
29. `🌿 [visual-hierarchy] Keep the archive Undo visible when an archive fails [step 29/41]`
30. `🚧 [visual-hierarchy] Show failed sends under the message with Retry [step 30/41]`
31. `🚧 [visual-hierarchy] Group transcript steps and show live progress [step 31/41]`
32. `🚧 [visual-hierarchy] Report tool kinds from every plugin [step 32/41]`
33. `⚙️ [visual-hierarchy] Show when YOLO is on [step 33/41]`
34. `🚧 [visual-hierarchy] Show live change counts on Changes [step 34/41]`
35. `⚙️ [visual-hierarchy] Enforce the one modal entry point with a lint rule [step 35/41]`
36. `🚧 [visual-hierarchy] Show compaction as its own row with the summary in a modal [step 36/41]`
37. `🌱 [visual-hierarchy] Prototype turn navigation for discussion [step 37/41]`
38. `🌱 [visual-hierarchy] Plan the desktop sign-in rebuild [step 38/41]`
39. `⚙️ [visual-hierarchy] Give headers a soft backdrop [step 39/41]`
40. `🌱 [visual-hierarchy] Reconcile regression docs [step 40/41]`
41. `🌱 [visual-hierarchy] Record the final matrix and retire the plan [step 41/41]`
