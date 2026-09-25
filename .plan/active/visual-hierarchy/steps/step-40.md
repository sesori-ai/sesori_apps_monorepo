# Step 40 — Smaller phone up button

## What changed

- On touch, the folder browser's up button (#1688) draws at
  `PregoButtonsSolidSize.md` (40) instead of `lg` (44).
- A 44-square opaque tap area around it keeps the touch target, so a tap just
  outside the drawn button still opens the parent folder. The "Parent folder"
  semantics wrap that whole area, so screen readers get one 44 × 44 button
  node (review fix).
- The pointer size (`sm`, 36) is unchanged.

## Verification

- `add_project_dialog_test.dart` passes (25). A new case checks the touch
  button is 40 by 40, that one 44 × 44 "Parent folder" semantics node has a
  tap action, and a tap 1 px inside the 44 target still goes up.
- `dart analyze --fatal-infos` is clean in `module_app_ui`.
- Fixture-only before and after phone renders are on `pr-media` under
  `visual-hierarchy/folder-up-size/`.
