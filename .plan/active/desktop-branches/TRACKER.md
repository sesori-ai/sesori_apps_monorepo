# Desktop branches tracker

Status values: Pending, In progress, PR open, Merged, Blocked, Dropped.

| Step | Status | PR | Notes |
| --- | --- | --- | --- |
| 1 Raise the plan | Merged | #2463 | |
| 2 Fold the subtle desktop differences | Merged | #2475 | 10 items folded (2.11 only its radius), 2.15 done by #2460; 2.6, 2.13 and 2.11's fill and wrap dropped (below). 2.10 and 2.14, also dropped, were decided in round 3 and folded in step 4. 2.1 folded to the phone's values, not the pointer's. |
| 3 Fold the transcript and needs-you card looks | Merged | #2479 | Decisions 1, 2, 3, 8 and 10 folded, nothing dropped (below). The bash step's label branch stays (2.6). Dark secondary button checked on the phone simulator: 6.29:1, shipped; the phone's buttons later went back to before by owner choice C (#2486). |
| 4 Fold the settings, alert, diff and picker looks | Merged | #2482 | Decisions 4, 5, 6, 7 and 9, and round 3's items 2.10 and 2.14; nothing dropped (measurements below). |
| 5 Flag new interaction-mode reads | Merged | #2485 (`eb71881bf4`) | 74 markers on the 74 reads (below): 70 `pending:` and 4 permanent. `unnecessary_ignore` does not report a stale plugin ignore, so the strict phase greps for stale markers. |
| 6 Reconcile regression docs | Merged | #2488 (`d2b38bec4e`) | Docs only, checked against `main` (below). The waiting-dot amber and #2486's needs-you button sentences left as they are. No findings after the merge: Codex reviewed the merged head clean, and cubic added nothing. |
| 7 Run the verification matrix and retire the plan | Blocked | | Matrix run on `main` `d2b38bec4e` (below): every cell passed except Desktop screens, which is Partial because the running macOS app was not launched. The plan stays active until the owner answers the two questions under "With the owner" (below); then it moves to `.plan/completed/`. |

## Outside the series

| Work | State | Notes |
| --- | --- | --- |
| #2460 Drop dead and no-op desktop checks | Merged | Precursor. It included the phone "Waiting" amber (`smallWarningText`), so item 2.15 is done. |
| #2486 Keep both needs-you buttons bright on the phone | Merged (`96d1b1b75d`) | Owner choice C on decision 10's buttons: the phone's go back as before step 3, desktop's stay. Adds 1 read (step 3 measurements). |
| `desktop-text-size` | Local branch, no PR | Shares `prego_anchor_menu.dart` with step 4 (another hunk). |

## Step 2 measurements

Folded, before → after:

| Item | Before | After | Who sees it |
| --- | --- | --- | --- |
| 2.1 presence motion | desktop: enter `pregoContentMoveCurve`, exit 130 ms | the phone's: 200 ms ease-out in, 200 ms ease-in out (85% → 68% grown at 100 ms) | desktop. Fixes a 6.4 pt jump of the rows above a step taking over from Working (measured 6.37 pt on desktop, 0 on the phone; 0 on both after). |
| 2.2 presence opacity | phone: follows the ease (0.9 at 150 ms) | solid at 35% of the ease (46 ms; desktop 40 → 46 ms) | both, barely; exit unchanged |
| 2.3 disclosure motion | phone: open and close 200 ms ease-out/ease-in, resize 200 ms | open 180 ms and resize 180 ms on `Cubic(0.25, 0.55, 0.2, 1)`, close 130 ms ease-in | phone |
| 2.3 header minimum | desktop: zero | `Size(44, 44)`, which density makes 36 × 28; the 28 pt step row already fills it | neither (phone header 44 unchanged) |
| 2.4 live label shimmer base | phone: light `#6A6A6A` (5.27:1 on `bgSecondary`), dark `#999999` (6.17:1) | `textSecondary`: light `#474747` (9.06:1), dark `#AEAEAE` (7.93:1) | phone |
| 2.5 step row inset | desktop: 2 (row 24 pt) | 4 (row 28 pt), +4 pt per row; `heightAsFirstRow` follows | desktop |
| 2.7 label–detail space | desktop: space with `letterSpacing: 3` | plain space, 3 pt narrower | desktop |
| 2.8 leading glyph | desktop: nudged up 1 pt | centred, 1 pt lower | desktop |
| 2.9 button trailing counts | phone: fade and size switch, 200 ms ease-out | content changes at once; only the width eases, 130 ms `pregoPointerEnterCurve`, aligned to the end | phone |
| 2.11 alert radius | phone: 16 | 12 | phone |
| 2.12 live words panel radius | phone: 18 | 16 | phone |

Dropped, branch left as it is, for the owner and the metrics phase:

| Item | Measurement | Why dropped |
| --- | --- | --- |
| 2.1 pointer's values on both | The pointer's ease-in and fold-away are not mirror images, so the rows above a step that takes over from Working move 6.4 pt mid-handoff | Breaks "content never jumps"; the phone's values went to both instead (above) |
| 2.6 settled step label colour | Phone light `#474747` → `#141414` (9.06:1 → 17.96:1), dark `#AEAEAE` → `#FDFDFD` (7.93:1 → 17.29:1) | Every settled step label on the phone turns from grey to near black or white |
| 2.11 dark fill | `#333333` (luminance 0.033) vs `bgSurface3` `#252525` (0.019) | Not the same surface on both |
| 2.11 action wrap | At 3.2× text on a 390 pt phone, a wrapped Undo moves 76.8 pt to the end, close 263 → 340 | Visible beyond subtle on the phone |
| 2.13 harness chevron | Phone: the chevron centre moves 12 pt and the switch 24 pt toward the edge; row stays 68 pt. The 44 box also keeps the switch still when the 44 pt install button or progress swaps in | Visible on the phone |

2.10 (the alert fade) and 2.14 (the waiting dot) left this list when the owner decided them in round 3; step 4 folds
them (below).

## Step 4 measurements

Folded, before → after. Nothing was dropped.

| Item | Before | After | Who sees it |
| --- | --- | --- | --- |
| 4 computer entry | phone: flat 54 pt row on the page, 12 pt gap below, selector 22 pt | a 54 pt card (radius 26, insets 18/12), 8 pt gap, selector 14 pt; the platform icon stays 22 pt, centred about 29 pt from the card's start (the rows' glyphs at 28). The whole card opens the menu, and its hover and press fill take the card's shape, as the rows' do (desktop's was an 8 pt-radius rect inset 18/12) | phone; desktop while the list loads, which now shows no empty card, and on hover |
| 5 alert accent | phone: a radial glow over the dark card (`#333333`), edges success `#39614D` (1.80:1), warning `#6E4F26` (1.69:1), error `#6C3835` (1.35:1) | no glow; the icon alone carries the variant | phone |
| 6 diff "M" | phone: light `#DC6803` (3.49:1 on `bgSurface3`), dark `#FDB022` (8.33:1) | `textSecondary`: light `#474747` (9.29:1), dark `#AEAEAE` (6.91:1); also in the file header and the selected file's header | phone |
| 7 section headings | desktop: sentence case at 11.5 pt, e.g. Recent 36.0 pt, OpenRouter (free) 92.6 pt | spaced capitals, 0.8 tracking: RECENT 49.2 pt, OPENROUTER (FREE) 127.0 pt; menus give 196–216 pt and pickers 280–340 pt, so nothing truncates. The command palette's headings change too | desktop |
| 9 harness overview cards | desktop: `bgSurface3`, light `#FFFFFF` (1.026:1 on the pane's `#FCFCFC`), dark `#252525` (1.148:1 on `#18191B`) | `bgSurface2`, as the detail and MCP pages: light `#FCFCFC` (1.000:1, outlined by the pointer hairline), dark `#1E1E1E` (1.055:1). Text on it: light 17.96, 9.06, 5.27:1; dark 16.39, 7.51, 5.85:1 | desktop |
| 2.10 alert fade | desktop with Reduce Motion: 0.9 opaque at 6.9 ms; on close, solid until 52 ms, 0.1 at 100 ms | the phone's fade: 0.9 at 79.6 ms; on close 0.5 at 21 ms, 0.1 at 58 ms. Without Reduce Motion unchanged on both (desktop solid within 40 ms), so the pointer check stays | desktop with Reduce Motion |
| 2.14 waiting dots | desktop light `#D98200`: sidebar `#F0F0F0` 2.58:1, hover `#F5F5F5` 2.70:1, selected `#E6E6E6` 2.36:1, page title and toggle on `#FCFCFC` 2.87:1, toggle hover `#FAFAFA` 2.82:1 | `fgWarningPrimary` `#DC6803`: 3.06, 3.20, 2.79, 3.40 and 3.34:1. Dark is `#F79009` before and after (7.10, 6.29, 5.94, 7.85 and 5.47:1) | desktop, light mode |

Selector alignment, for the owner: in the card, the 14 pt selector is centred 19 pt from the card's end, while the rows'
chevrons are centred 26 pt from it on the phone (20 pt glyph) and 24 pt on desktop (16 pt glyph). Desktop already had
this 5 pt offset; the phone now has 7 pt. No shared value aligns both.

## Step 3 measurements

Folded, before → after:

| Item | Before | After | Who sees it |
| --- | --- | --- | --- |
| 1 agent pill and picker glyph | desktop: wrench | robot | desktop |
| 1 finished sub-agent glyph | desktop: check | robot, `textTertiary` | desktop |
| 1 settled shell glyph | desktop: check, `textTertiary` | terminal, the line's colour (`textSecondary`, red on failure) | desktop |
| 1 settled tool glyph | desktop: check | wrench | desktop |
| 1 settled thought glyph | desktop: 14 pt bulb, `textTertiary` | the still 20 pt outline AI loader, `textSecondary` | desktop |
| 1 New Session harness pill caret | desktop: up-and-down selector | the phone's down chevron, at desktop's 14 pt and colour; both open the same anchored menu. The 14 vs 18 pt size stays with the pill's metrics | desktop |
| 2 shell command | desktop: monospace (live in `textPrimary`) | Satoshi, underlined, the row's colour | desktop |
| 2 tool title or path | desktop: monospace, `textSecondary` | plain text | desktop |
| 2 permission request line | desktop: monospace 12 w400 | Satoshi 12.5 w500, matching a question's line | desktop |
| 3 needs-you cards | desktop: grow in and fold away (200 ms since step 2) | the same on the phone, holding the newest row's gap on every frame | phone |
| 8 inline code chip | desktop: no chip | `alphaBlack10`: light page `#FCFCFC` → `#E2E2E2` (text 17.96 → 14.22:1), dark page `#141414` → `#2C2C2C` (18.11 → 13.73:1); bubbles light `#F0F0F0` → `#D8D8D8` (16.17 → 12.93:1), dark `#1E1E1E` → `#353535` (16.39 → 12.06:1). Light is 10% black, dark 10% white | desktop |
| 10 card height | phone: 62 pt | 54 pt (desktop 50) | phone |
| 10 card padding and icon | phone: 12 all round, icon 18 | 12/8/8/8, icon 16 | phone |
| 10 card label | phone light `#B54708` (5.20:1) | `#854B00` (6.70:1); dark `#FDB022` 8.63 → 9.08:1 | phone |
| 10 card fill and border | phone light border `#F4CEA5`; dark fill `#2B2013`, border `#684210` | light border `#F7D7B3`; dark fill `#241D13`, border `#573811` | phone |
| 10 card actions | phone: light secondary on both cards, dark white on both | the first card's solid (light `#18191B`, white text 17.59:1; dark white), a second card's secondary (light white, `#474747` 9.29:1; dark `#2C2C2C`, `#AEAEAE` 6.29:1, fill on card 1.20:1). Reverted on the phone by owner choice C ("The before is better"), in #2486; desktop keeps it | phone, until #2486 |
| 10 action minimum width | 0 | 72 (buttons are 112 wide, so nothing moves) | neither |

Dropped: none. The dark secondary button was measured on the phone simulator's screenshot
(`#AEAEAE` on `#2C2C2C`, 6.29:1) and is legible, so decision 10 shipped whole. The owner then chose C,
"The before is better": #2486 puts the phone's buttons back as they were (light: both secondary; dark:
both white) and keeps desktop's first-card-solid rule, with one interaction-mode read. The rest of
decision 10 stays.

## Read counts

| Point | Reads | Files |
| --- | --- | --- |
| `origin/main` `478ea1c15e` | 105 | 46 |
| After #2460 | 101 | 44 |
| After step 2 (`c799ab8775`) | 91 | 41 |
| After step 3 | 82 | 38 |
| After step 4 (planned) | about 71 | about 35 |
| After step 4 | 74 | 36 |
| After step 5 | 74, all marked | 36 |
| After #2486 (phone needs-you buttons) | 75, all marked | 37 |
| Step 7, on `main` `d2b38bec4e` | 75, all marked: 71 `pending:` and 4 permanent | 37 |

Every row is counted with this command from `client/`, on the commit named or the step's merge:

```sh
git grep -hoE 'PregoInteractionScope\.of\(|InheritedWidgetOfExactType<PregoInteractionScope>|isDesktopScale|ComposerPresentation\.(pointer|touch)' \
  -- 'module_app_ui/lib' 'module_prego/lib' \
  ':!**/interactions/prego_interaction_scope.dart' ':!**/theme/prego_design_system.dart' | wc -l
```

Use `-l` instead of `-o` for files. Step 2 recorded 92 from its PR head; `7e36369232` (the desktop text size
setting) removed one more read on `main` before step 2 merged, so `main` held 91 after it.

Step 3 removed 9 reads, not the 10 planned: the bash label read stays with item 2.6. The harness pill's caret
fold removes no read: the same read still sets the pill's radius, fill, height, padding and its text, logo and
caret sizes, which wait for the metrics phase.

Step 4 removed 8 reads: 3 in the computer entry, 1 in the diff "M", 3 in the harness cards and 1 in the session
row's waiting dot. The alert, picker and menu folds remove none: the alert keeps its pointer check for the fade
without Reduce Motion (2.10) and for step 2's dropped fill and wrap, and the picker keeps its padding read.

#2486 adds 1 read back, in the needs-you card: it picks the button's look (owner choice C on decision 10). Its
marker's home is `variant`, the needs-you card's desktop variant, so 71 `pending:` markers remain. That card is
not one of the four planned variants. Like the all-sessions filter line (below), the variants phase decides whether
it becomes a fifth variant or a metrics value.

## Step 5 markers

The rule's 74 findings before markers sat exactly on the 74 lines the command above counts. Each now carries a
marker on the line above it. Count what the later phases owe with
`git grep -ho 'avoid_interaction_mode_reads, pending:' -- client/module_app_ui/lib client/module_prego/lib | wc -l`
(70 at step 5; 71 after #2486, whose marker is a 22nd `variant`).

| Home | Markers | Where |
| --- | --- | --- |
| `metrics` | 44 | the read only picks values: sizes, padding, radii, colours, motion, text styles, fade edges |
| `variant` | 21 | structure inside the four planned variants: the composer (all 11 `prompt_input` reads and `session_detail_composer_controls`), the session row (3), the permission request (1) and new-session setup (4); and the all-sessions filter line, which picks `_PointerFilterChip` over `PregoButtonsSolid` (outside the four, so its phase decides between a fifth variant and one chip with metrics) |
| `wrapper` | 3 | generic interaction behaviour: the add-project breadcrumb, the anchor menu's flat list and the picker search list |
| `presenter` | 2 | popover or sheet: the project picker and the transcript group |
| permanent | 4 | the adaptive presenters: `prego_modal.dart` (3) and `prego_action_sheet.dart` (1), with their reason in place of `pending:` |

A read that mixes values with structure or behaviour takes the structural home. The sticky prompt's
`fadesTopEdge` read is marked `metrics`; the audit also suggested a shell parameter for it, which the metrics
phase can decide.

Stale markers: a `// ignore: no_slop_linter/avoid_interaction_mode_reads` above a line with no read gives no
diagnostic, while a stale `// ignore: avoid_print` on the same line reports `unnecessary_ignore`. So a PR that
removes a read must delete its marker by hand, and the strict phase greps for markers with no read under them.

## Step 6 doc fixes

Steps 2–4 had already updated the docs for what they folded. Step 6 read the ten docs and `multi-computer.md`
against `main` and fixed what was still wrong:

| Doc | Was | Now |
| --- | --- | --- |
| `tools-and-file-changes.md` | step rows: a 14 px line in secondary text on both | 14 px on the phone, 12.5 px on desktop; desktop's label in primary text (2.6, dropped) |
| `tools-and-file-changes.md` | the Shell panel shares code blocks' inset | it shares the phone's; desktop code blocks are quieter with a hairline (`session-turns.md`) |
| `tools-and-file-changes.md` | the phone is the only transcript surface | the phone and the desktop both show it |
| `diffs-and-source-control.md` | the Changes counts fade, and a phone circle stretches into a pill | desktop's counts have their own slot and change at once (2.9); the phone has only the menu row |
| `popup-alerts.md` | every alert fades in over 220 ms | adds desktop's solid within 40 ms without reduced motion, as `desktop-cockpit-shell.md` says |
| `session-creation-and-options.md` | the harness name "over" a chevron; its menu below the pill | the mark, the name and the chevron in one row; the menu beside the pill, toward the side with more room |
| `multi-computer.md` | the entry sits under "Bridge" on both apps | "Connected bridge" on desktop |
| `multi-computer.md` | the desktop footer row ends in a chevron | an up-and-down picker glyph, as `desktop-cockpit-shell.md` says |

For step 7, the differences that remain on purpose: the step row's size, label colour and strut; the alert's dark
fill, wrap and fade without Reduce Motion; the harness chevron's 44 box; desktop's code block fill; and the needs-you
buttons (#2486).

## Step 7 verification

Run on `main` `d2b38bec4e0708f31cc041e1e75de27e0984f043`, in a clean checkout of that commit, at level L2. The bridge
ran from source on slot 2, with Claude Code as the representative plugin on a throwaway Git fixture. The phone ran on
headless `sesori-dev-2` (iPhone 17), in light and dark, driven by a throwaway integration test that was not committed.
That test followed the docs' exploration guidance, so a rerun varies the prompts and the order. Desktop looks were
rendered under a pointer `PregoInteractionScope`. Screenshots stay outside the repository.

| Cell | Result | What ran |
| --- | --- | --- |
| Owning tests | Pass | `flutter test` in `client/module_prego` (432 tests), `client/module_app_ui` (1738), `client/app` (867) and `client/desktop` (451); `dart test` in `client/module_desktop_core` (468) and `shared/no_slop_linter` (233) |
| Analyzer | Pass | `dart analyze --fatal-infos client`, run from the repository root: no issues |
| Reads and markers | Pass | the commands in "Read counts" and "Step 5 markers": 75 reads in 37 files, all marked: 71 `pending:` and 4 permanent. By home: `metrics` 44, `variant` 22, `wrapper` 3, `presenter` 2. Every marker sits over a read |
| Phone screens | Pass | the docs' L2 surfaces, below |
| Desktop screens | Partial | everything steps 2–4 changed on desktop, rendered and measured, plus the `desktop` suite, which is also `desktop-cockpit-shell.md`'s L2 entry. The running macOS app was not launched, so the items under "Owed" are unchecked |

The series changed no bridge, shared or plugin code; it touched only client presentation, docs and the linter. So the
bridge-only halves of these L2 entries were not re-run, for example option discovery, diff base branches, project
import and question variants beyond single choice. They ran only where the live journey passes through them. Their
automated halves are in Owning tests.

| Doc | Phone, both themes |
| --- | --- |
| `account-and-onboarding.md` | Email sign-in and logout from Settings |
| `projects-and-sessions.md` | A project opened. Sessions created with a first prompt get their title and go from busy to idle. The row's waiting dot and "Waiting" label |
| `session-creation-and-options.md` | The harness pill shows the mark, the name and a down chevron in one row; its menu opens below the pill, the side with more room |
| `session-turns.md` | Prompts stream and return to idle. Inline code chips and a fenced code block (white on light, dark on dark, radius 4, no border) |
| `tools-and-file-changes.md` | An Edit row with its path and status. A shell row with the command underlined and paths plain, and its bounded output in the Shell panel. A live row with the sparkle. The "4 steps" disclosure and its sheet, with 44 pt rows in 14 pt `w700` grey labels |
| `questions-and-permissions.md` | A single-choice question answered from its needs-you card, and a permission allowed once from its card; the turn went on after each. Both cards' buttons are bright, as #2486 set them: light secondary, dark white. Cards about 54 pt tall, amber label, 16 pt icon |
| `diffs-and-source-control.md` | The menu's Changes row with its count. The file list with "A" in green and "M" in grey: light `#474747`, dark `#AEAEAE` |
| `popup-alerts.md` | The archive alert outlives its removed row. A folder-exists alert renders above the add-project sheet. Radius 12, no glow, dark fill `#333333` |
| `plugin-setup-and-lifecycle.md` | Harness overview chevrons in 44 pt boxes beside the switches |
| `multi-computer.md` (Settings) | The computer card under "Bridge" |

The differences that stay on purpose all look as documented:

| Difference | Phone | Desktop |
| --- | --- | --- |
| Step row | 44 pt; label 14 pt `w700`, `#474747` light, `#AEAEAE` dark; no strut | 28 pt; label 12.5 pt `w500`, `#141414` light, `#FDFDFD` dark; strut 1.44 |
| Alert | dark fill `#333333`; at 3.2× text the action wraps to the start | dark fill `#252525`; the action wraps to the end; solid within 40 ms without Reduce Motion (widget test) |
| Harness overview chevron | in a 44 pt box, row 68 pt | bare 16 pt chevron, row 60 pt |
| Code block | light `#FFFFFF`, dark `#2C2C2C`; radius 4; no border | light `#F0F0F0`, dark `#1E1E1E`, with a hairline; radius 8 |
| Needs-you buttons | both bright (#2486) | the first card's button solid, a second card's secondary |

Recorded only: the session row's waiting dot is `#DC6803` in light and `#F79009` in dark, on the phone and on
desktop. It counts as neither pass nor fail.

### Open owner decision, outliving the plan

The waiting-dot amber in light mode is undecided. The options are `#D98200` (desktop's colour before step 4) and the
shipped `fgWarningPrimary` `#DC6803` (2.14, step 4). Dark stays `#F79009` either way. Nothing here changes it.

### Found for the owner

The New Session harness menu's "Harnesses" header is in sentence case on both apps (`_HarnessesMenuHeader` in
`new_session_plugin_chooser.dart`). Decision 7 put menu and picker section headings in spaced capitals on both. This
header is a title row with a settings action, not a `PregoMenuLabel`. It has no mode read, and the series did not
touch it, so it is not a regression. Whether it follows decision 7 is a design choice the owner has not made yet.

### With the owner

Two questions are on the owner's review page:

- whether to retire the plan now and check the six owed items below while trying the build, or keep it open until
  they are checked;
- whether the "Harnesses" header above takes decision 7's spaced capitals.

Step 7 stays Blocked until the owner answers. Then a small follow-up writes the answer into `PLAN.md` and moves the
plan to `.plan/completed/`.

### Owed: desktop items that need the running app

These are not marked passed:

- the computer card's hover and press fill, which take the card's shape, and menu hover;
- the alert fade end to end with macOS Reduce Motion on and off (widget tests cover both);
- the waiting dot in the real shell's page title and hidden-sidebar toggle (widget tests cover its colour);
- the desktop text-size setting at non-default sizes on the folded rows, headings and cards;
- where the harness menu and other anchored menus land in a real window;
- step 2's presence and disclosure motion seen live.
