# Prego Button Interactions

## Capability

`PregoTappable` provides platform-appropriate button feedback: iOS uses the
existing press pulse and release, Android uses a Material ripple, and web and
desktop use static press and hover overlays. A button becoming loading or
disabled keeps its iOS press wrapper mounted so its scale settles from the
current position. Disabling a button while held cancels the press without
activating it.

iOS Reduce Motion and MediaQuery's disable-animations preference keep static
pressed styling and haptics while suppressing the scale controller. The
preference is read when each press starts and ends; a press held while Reduce
Motion turns on returns straight to rest on release.

A screen reader hears every solid button, and every icon-only control built on
`PregoTappable`, as one node holding its name, button flag, enabled state, tap
and focus, on every platform; words and taps never land on a neighbour or on the
surface behind it. An icon-only button always has a name, shown as a tooltip on
hover and long-press where the site asks for one. A disabled or loading button
reads as disabled and takes no screen reader tap. Press-and-hold controls such
as the microphones name themselves through their own wrapper and show no tooltip,
which would race the hold.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: loading preserves release continuity; disabling a held button prevents activation; both reduced-motion sources preserve static press feedback; Android and desktop retain disabled and enabled behavior. |
| L2 Routine | Client end to end on iOS: send feedback and observe the button settle while loading begins; repeat quick taps, holds, cancellation and retry in light and dark mode. |
| L3 Release | Client end to end: enable Reduce Motion, press a button, and confirm stationary feedback; check Android ripple and web press/hover behavior. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Failure Signals

- A loading button jumps directly from the pressed scale to its resting size.
- A disabled button activates or retains pressed styling after cancellation.
- Reduced motion still produces button scaling or a running pulse ticker.
- Android or web buttons acquire iOS scaling or lose their existing interaction.
- A screen reader reaches a button with no name, or its name without a tap on the same node.
- A button's words read as part of a neighbour, a row or the whole surface.
- A disabled or loading button reads as enabled or takes a screen reader tap.

## Sources

- `client/module_prego/lib/components/buttons/prego_button_semantics.dart`
- `client/module_prego/lib/components/buttons/prego_buttons_solid.dart`
- `client/module_prego/lib/interactions/prego_tappable.dart`
- `client/module_prego/lib/motion/prego_reduced_motion.dart`
- `client/module_prego/test/components/prego_buttons_solid_test.dart`
- `client/module_prego/test/interactions/prego_tappable_test.dart`
