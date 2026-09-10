# Prego Button Interactions

## Capability

`PregoTappable` provides platform-appropriate button feedback: iOS uses the
existing press pulse and release, Android uses a Material ripple, and web and
desktop use static press and hover overlays. A button becoming loading or
disabled keeps its iOS press wrapper mounted so its scale settles from the
current position. Disabling a button while held cancels the press without
activating it.

iOS Reduce Motion and MediaQuery's disable-animations preference keep static
pressed styling and haptics while suppressing the scale controller. Switching
Reduce Motion on during a pulse immediately settles its scale and cancels
pending release motion. Turning the preference off restores motion on the next
press.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: loading preserves release continuity; disabling a held button prevents activation; both reduced-motion sources preserve static press feedback; changing Reduce Motion during release stops motion; Android and desktop retain disabled and enabled behavior. |
| L2 Routine | Client end to end on iOS: send feedback and observe the button settle while loading begins; repeat quick taps, holds, cancellation and retry in light and dark mode. |
| L3 Release | Client end to end: toggle Reduce Motion while pressing a button and confirm stationary feedback; check Android ripple and web press/hover behavior. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Failure Signals

- A loading button jumps directly from the pressed scale to its resting size.
- A disabled button activates or retains pressed styling after cancellation.
- Reduced motion still produces button scaling or a running pulse ticker.
- Turning Reduce Motion on during a quick tap allows a delayed release to restart.
- Android or web buttons acquire iOS scaling or lose their existing interaction.

## Sources

- `client/module_prego/lib/interactions/prego_tappable.dart`
- `client/module_prego/lib/motion/prego_reduced_motion.dart`
- `client/module_prego/test/interactions/prego_tappable_test.dart`
