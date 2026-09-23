# Step 4 — Anchored pickers

Step 4 measured about 2,080 changed lines against a ≤ 600 target, about 980
of them deletions of the replaced sheets. It lands as three PRs that each
stand alone, following the plan's `31.a` convention:

- **4.a** Prego popover capabilities, and the plan update that added steps
  35–37.
- **4.b** The shared picker search list and the model picker.
- **4.c** The command picker and the regression docs.

## 4.a — Prego popover capabilities

### What changed

- `PregoPopover` gains `popoverMaxHeight` and `contentScrolls`. A picker can
  cap its height and bring its own scroll view, keeping a search field pinned
  above its rows. Every existing caller passes `null` and `false`, and keeps
  its behaviour.
- `AnchoredFlatPanel` measures room and screen clamps from where its trigger
  is now, not where it was when the popup opened. It reads the shift the
  `CompositedTransformFollower` painted with after each frame, and hands it
  back to the follower. Before this, a composer lifted by the keyboard dragged
  an open popover up past the top edge.
- Plan: steps 35–37 were added at the user's request: the modal lint rule,
  the compaction row, and turn navigation prototypes. Sign-in, the header
  backdrop, docs and retirement moved to 38–41.

### Verification

- `client/module_prego`: `prego_popover_test.dart` adds three cases: content
  that scrolls itself gets the capped height; the popover stays above a
  trigger the keyboard lifts after it opens; and it keeps inside the window
  edges beside a corner trigger. The package suite passed (341), and
  `dart analyze --fatal-infos` is clean.
- `client/desktop`: `desktop_bridge_popover_test.dart` passed (7).

## 4.b — Search list and model picker

### What changed

- New `prego_picker_search_list.dart` in `module_prego`, where reusable
  visual primitives live:
  - `PregoPickerPopover` anchors a picker to its composer button: 380 px high at
    most, 300 or 360 wide under a pointer, and screen-wide on the phone.
  - `PregoPickerSearchList` is a search field over a lazy list of headings and
    options.
  - Under a pointer the field takes focus as it opens. Up and Down move one
    highlight, skipping headings and holding at either end, and the mouse
    moves the same highlight. Enter picks the highlighted option and Esc
    closes the picker.
  - On the phone nothing is highlighted and the keyboard waits for a tap.
- The model pill opens `ModelPicker` in that popover on both apps. The phone
  quick menu and its full-screen search sheet merge into this one popover.
  - Provider headings use the menus' uppercase label style instead of the
    sheet's brand colour.
  - The highlight starts at the first option, not the selected model.
  - A search that matches nothing shows an empty list, as before.
- An open picker rebuilds its rows, keeping the search, when the catalog or
  the selection changes.
- Regression docs: `session-creation-and-options.md` describes the model
  picker's popover, desktop keys and failure signals.
- Removed: `model_picker_sheet.dart`, `model_picker_list_items.dart`, the
  search affordance row, and the unused "Select Model" string.

### Verification

- `client/app`: `model_picker_test.dart` covers:
  - the representative models, headings and check;
  - opening above the pill within the height cap;
  - search;
  - tap selection;
  - pointer Up, Down, mouse highlight and Enter;
  - pointer Esc;
  - touch with no focus or highlight.

  With `agent_model_buttons_test`, `command_picker_sheet_test` and
  `session_detail_body_test`, 151 passed.
- `client/module_app_ui`: `test/features/session_detail` passed (217).
- `dart analyze --fatal-infos` is clean in module_app_ui and app.
- Size: about 1,200 changed lines; about 580 are deleted sheet code, and
  about 230 are the rewritten test.

## 4.c — Command picker

### What changed

- The composer's "/" button opens `CommandPicker` in a `PregoPickerPopover` on
  both apps, replacing `command_picker_sheet.dart`.
  - The catalog still loads in a background isolate behind a spinner.
  - Search matches names, descriptions and hints, including a query typed
    while it loads.
  - Rows show the name, source tag, description and hints, and drop the
    grouped-card style.
  - A selection closes the popover and refocuses the composer, unless an app
    shortcut changed the session under the open picker.
- An open picker reloads a catalog the session refreshes, and ignores an
  older load that finishes late.
- The composer keeps its typing layout while the picker is open. The search
  takes focus from the composer, and the layout swap would drop the picker's
  anchor. `PregoPopover` gains `onClosed` for this.
- "Filters as you type after /" is the popover's focused search field on
  desktop. The composer text itself does not open the picker.
- The no-match state keeps the existing "No slash commands are available for
  this project." text.
- Removed: the sheet, its test, and the unused search hint string.
- Regression docs: `session-creation-and-options.md` describes both pickers,
  their desktop keys, and new failure signals.

### Verification

- `client/app`: `command_picker_test.dart` covers:
  - loading, then sorted rows;
  - search, including a query typed during loading;
  - every source label;
  - tap selection;
  - empty and no-match states, and recovering from no match;
  - a narrow phone with large text in both themes;
  - a lazy 40-command catalog within the height cap, with the last row
    reachable;
  - the desktop placement above a bottom-corner trigger inside the window,
    with typing and Enter.

  The picker tests passed (19), and `session_detail_body_test` with
  `agent_model_buttons_test` passed (132).
- `client/module_app_ui`: `test/features/session_detail` passed (217).
- `client/module_prego`: `test/components` passed (302).
- `dart analyze --fatal-infos` is clean in module_prego, module_app_ui, app
  and desktop, apart from local render files that are never committed.
