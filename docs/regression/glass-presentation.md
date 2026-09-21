# Glass Presentation

## Capability

Shared glass controls retain readable, platform-appropriate presentation on the
mobile and desktop shells without turning solid content or product menus into glass.

## Required Behavior

- Both shells initialize standard shaders before their UI starts, skipping unused
  premium preload. Desktop does so only after the primary-launch gate succeeds.
- Adaptive quality starts at standard, stays between minimal and standard, and
  can recover to standard. Mobile retains its 8 ms runtime target; desktop uses
  the package's default 16 ms target. These are policies, not measured GPU results.
- Glass follows the app's Material appearance even when it differs from the OS.
  Package accessibility defaults remain enabled. The package's high-contrast
  fallback must not be described as actual iOS Reduce Transparency detection.
- Only the staged-command chip materializes/dematerializes. Ordinary picker,
  recording-helper, and saved-recording actions keep their ordinary transitions.
  Prego reduced motion (Remove animations or iOS Reduce Motion) makes this slot
  change instantly. Staging/clearing retains existing draft and focus behavior.
- The scroll-capable Prego glass menu uses tap-only glow, anchors in its nearest
  overlay coordinates, and permits custom rows to dismiss it. This is shared
  dormant-path correctness: all current product menu callers remain flat.
- Spotlights belong to the touch presentation of a flat anchored menu; the
  desktop app's pointer menus never dim the window (see
  `desktop-cockpit-shell.md`).
- Flat anchored-menu spotlights blur the page on iOS. macOS uses a deeper scrim
  instead because hybrid-composed AppKit views cannot join Flutter's backdrop
  sample and would remain sharp against blurred rows. Android uses the same
  scrim-only treatment to avoid full-screen blur cost. Both retain the sharp
  cut-out and outline around the selected row.
- Solid surfaces, flat menus, custom scaffold gradients, and sheet controls retain
  their existing composition. Premium and glass navigation-shell morphing are not enabled.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated shell policy and app/OS brightness mismatch; staged-chip show/clear, draft/focus, voice/retry exclusion and reduced motion; nested-overlay glass menu geometry, scrolling and custom dismissal; anchored-menu spotlight blur and scrim platform policy; existing scaffold and sheet suites. |
| L3 Release | Client end to end on iOS and macOS with a real renderer: light/dark including app/OS mismatch, staged-chip show/clear, sheet controls, and solid content behind glass. Android fallback smoke. |
| L4 Extended | Repeat the presentation flow with reduced motion and high contrast; inspect quality recovery under representative load without inferring a refresh rate or premium performance. |
| L5 Full | No additional coverage. |

## Failure Signals

- A secondary desktop invocation initializes shaders, or premium preload runs.
- Glass follows OS brightness instead of the pinned app appearance.
- Clearing/staging drops the draft, unrelated voice/picker content materializes,
  or the chip still scales/blurs under reduced motion.
- A nested overlay applies its origin twice, a custom row cannot dismiss, or a
  scrolling gesture starts the glass menu's touch glow.
- A desktop pointer menu dims or blurs the window, or lifts its row.
- A macOS anchored menu blurs around an AppKit view, leaving its native activity
  indicator sharp against blurred Flutter rows, or loses the deeper scrim,
  selected-row cut-out, or outline.

## Sources

- `client/app/lib/main.dart` and `client/app/test/main_startup_notification_wiring_test.dart`
- `client/desktop/lib/main.dart`, `client/desktop/lib/app.dart`, and `client/desktop/test/app_smoke_test.dart`
- `client/module_app_ui/lib/src/features/session_detail/widgets/prompt_input.dart`
- `client/module_app_ui/test/features/session_detail/widgets/prompt_input_capabilities_test.dart`
- `client/module_prego/lib/components/menus/prego_anchor_menu.dart`
- `client/module_prego/lib/components/menus/anchored_spotlight_backdrop.dart`
- `client/module_prego/test/components/prego_anchor_menu_test.dart`
