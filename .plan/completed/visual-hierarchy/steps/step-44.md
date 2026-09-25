# Step 44 — A YOLO icon of its own

## What changed

- `YoloChip.icon` is the one icon for YOLO: Tabler `shield_x`. The composer's
  YOLO chip uses it instead of the fast-mode bolt.
- The Settings YOLO row, shared by phone and desktop, uses the same constant
  instead of `shield_off`.
- Fast mode keeps the bolt.

## Deviations

- The bundled Tabler font has no `shield_exclamation`, `shield_bolt` or
  warning shield. `shield_x` is the closest shield with a mark, in the spirit of
  Codex's "Full access". In this font version the x sits as a small badge at
  the lower corner, not inside the shield.
- The icon stays in the chip's neutral colour. The warning colour belongs to
  the per-session YOLO choice in step 45.

## Verification

- `dart analyze --fatal-infos` is clean in `module_app_ui` and `app`.
- `session_detail_body_test.dart` (now asserts the chip shows `shield_x`) and
  `settings_screen_test.dart` pass in `app`; `desktop_settings_screens_test.dart`
  passes in `desktop`.
- Before/after fixture renders of the chip and the Settings row are in the PR.
