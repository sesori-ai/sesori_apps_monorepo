# Step 41 — Polish the desktop bridge recovery card

Branch `visual-hierarchy/recovery-card`. Client only.

## What changed

- The user compared five rendered variants (A–E) on a local review page and
  picked E, asking for a smaller icon because the warning triangle still stood
  taller than the text.
- `PregoButtonsSolidSize.xs` joins the design system: 30px high,
  `textXs.medium`, 10px by 6px padding, a 4px gap and a 16px icon. An
  icon-only xs button is a 30px square. The design catalog lists the size, and
  it has a new "Primary Alt / Notice" scenario.
- The expanded recovery card uses xs buttons: Retry stays `primaryAlt`, and
  Open logs moves from `secondary` to `tertiary`. In dark mode the secondary
  pill's grey label on a grey fill read as disabled.
- The gap above the buttons grows from md (8px) to lg (12px), and the buttons
  sit 4px apart.
- The message is `textSm.regular` instead of medium, still in `textPrimary`.
- The status icon is 13px and centred on the message's first line box.
  Measured in 2x renders, the triangle's ink runs from the cap top of "The" to
  its baseline. At 12px it starts half a pixel below the cap top, and at 14px
  it overshoots by half a pixel at each end.
- The compact (collapsed sidebar) icon button is unchanged.

## Deviations from the plan

- None. The plan left the variant to the user; E was picked, with the smaller
  icon.

## Verification

- `module_prego` `test/components/prego_buttons_solid_test.dart` passed. A new
  xs case checks the 30px text and icon-only sizes, the text-xs label and the
  16px icon.
- `design_catalog` tests passed after regenerating `web/catalog_manifest.json`.
- `desktop` `test/core/widgets/desktop_cockpit_shell_test.dart` passed.
- `dart analyze --fatal-infos` is clean in module_prego, design_catalog and
  desktop.
- Fixture-only before and after renders, dark and light, are in the PR, with a
  12/13/14px icon comparison.
