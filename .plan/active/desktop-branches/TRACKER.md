# Desktop branches tracker

Status values: Pending, In progress, PR open, Merged, Blocked, Dropped.

| Step | Status | PR | Notes |
| --- | --- | --- | --- |
| 1 Raise the plan | Merged | #2463 | |
| 2 Fold the subtle desktop differences | Merged | #2475 | 10 items folded (2.11 only its radius), 2.15 done by #2460; 2.6, 2.13 and 2.11's fill and wrap dropped (below). 2.10 and 2.14, also dropped, were decided in round 3 and folded in step 4. 2.1 folded to the phone's values, not the pointer's. |
| 3 Fold the transcript and needs-you card looks | Merged | #2479 | Decisions 1, 2, 3, 8 and 10 folded, nothing dropped (below). The bash step's label branch stays (2.6). Dark secondary button checked on the phone simulator: 6.29:1, shipped. |
| 4 Fold the settings, alert, diff and picker looks | PR open | #2482 | Decisions 4, 5, 6, 7 and 9, and round 3's items 2.10 and 2.14; nothing dropped (measurements below). |
| 5 Flag new interaction-mode reads | Pending | | Waits for steps 3 and 4. Record whether `unnecessary_ignore` reports stale plugin ignores. |
| 6 Reconcile regression docs | Pending | | |
| 7 Run the verification matrix and retire the plan | Pending | | |

## Outside the series

| Work | State | Notes |
| --- | --- | --- |
| #2460 Drop dead and no-op desktop checks | Merged | Precursor. It included the phone "Waiting" amber (`smallWarningText`), so item 2.15 is done. |
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
| 10 card actions | phone: light secondary on both cards, dark white on both | the first card's solid (light `#18191B`, white text 17.59:1; dark white), a second card's secondary (light white, `#474747` 9.29:1; dark `#2C2C2C`, `#AEAEAE` 6.29:1, fill on card 1.20:1) | phone |
| 10 action minimum width | 0 | 72 (buttons are 112 wide, so nothing moves) | neither |

Dropped: none. The dark secondary button was measured on the phone simulator's screenshot
(`#AEAEAE` on `#2C2C2C`, 6.29:1) and is legible, so decision 10 shipped whole. Whether it reads as
disabled is an open owner question.

## Read counts

| Point | Reads | Files |
| --- | --- | --- |
| `origin/main` `478ea1c15e` | 105 | 46 |
| After #2460 | 101 | 44 |
| After step 2 (`c799ab8775`) | 91 | 41 |
| After step 3 | 82 | 38 |
| After step 4 (planned) | about 71 | about 35 |
| After step 4 | 74 | 36 |

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
