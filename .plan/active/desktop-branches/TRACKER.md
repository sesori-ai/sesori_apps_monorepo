# Desktop branches tracker

Status values: Pending, In progress, PR open, Merged, Blocked, Dropped.

| Step | Status | PR | Notes |
| --- | --- | --- | --- |
| 1 Raise the plan | Merged | #2463 | |
| 2 Fold the subtle desktop differences | PR open | | 10 items folded (2.11 only its radius), 2.15 done by #2460; 2.6, 2.10, 2.13, 2.14 and 2.11's fill and wrap dropped (below). 2.1 folded to the phone's values, not the pointer's. |
| 3 Fold the transcript and needs-you card looks | Pending | | Waits for step 2. Item 2.6 was dropped, so the bash step's label branch stays for the metrics phase. `pointerWarningText` is already `smallWarningText` (#2460). |
| 4 Fold the settings, alert, diff and picker looks | Pending | | Waits for step 2. Can run in parallel with step 3. |
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
| 2.10 alert fade (`_opacity` on both) | `_opacity` also drives the phone's Reduce Motion entry: the alert would pop in solid within 10 ms instead of fading (touch reaches 0.9 at 80 ms) | Removes the phone's reduced-motion fade. Keeping that fade means a reduced-motion branch that changes desktop: owner's call |
| 2.11 dark fill | `#333333` (luminance 0.033) vs `bgSurface3` `#252525` (0.019) | Not the same surface on both |
| 2.11 action wrap | At 3.2× text on a 390 pt phone, a wrapped Undo moves 76.8 pt to the end, close 263 → 340 | Visible beyond subtle on the phone |
| 2.13 harness chevron | Phone: the chevron centre moves 12 pt and the switch 24 pt toward the edge; row stays 68 pt. The 44 box also keeps the switch still when the 44 pt install button or progress swaps in | Visible on the phone |
| 2.14 waiting dot | Desktop light `#D98200` → `#DC6803` (dark identical `#F79009`) | Desktop's other waiting dots (`DesktopSessionSignals`, the collapsed sidebar's dot) stay `pointerWarningFill` and are outside this step, so folding the tile alone splits desktop's amber between the sidebar row and the page title. `pointerWarningFill` on both is the owner's call |

## Read counts

| Point | Reads | Files |
| --- | --- | --- |
| `origin/main` `478ea1c15e` | 105 | 46 |
| After #2460 | 101 | 44 |
| After step 2 | 92 | 41 |
| After step 4 (planned) | about 71 | about 35 |
