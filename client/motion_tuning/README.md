# Motion tuning

Development-only Flutter controls for tuning existing animations in component
previews. The editor provides selection, bounded values, replay, original-value
comparison, target reset, and clipboard presets. Each preview connects the
animations it supports; the editor does not discover arbitrary Flutter widgets.

## Use the editor

Expand **Motion** and set **Global animation speed** to **Normal (1×)**,
**0.5×**, or **0.2×** to inspect timing and glitches. It applies immediately to
all Flutter ticker-driven animations in the preview, including unconnected
widgets and route transitions. Slow speed remains visible in the collapsed
header. Normal restores ordinary timing; leaving the preview restores the
previous global clock. Speed is temporary and does not alter duration values
or clipboard presets. Dart timers, delayed fixture actions, and native platform
animations keep their own clocks.

1. Open a connected preview, expand **Motion**, and choose an animation from the
   list. Alternatively, activate **Select an element** and tap its marked region.
   Selection consumes the tap; overlapping regions offer a choice.
2. Adjust duration, numeric values, or easing. Changes apply when you press
   **Replay**, so a running transition keeps its captured values.
3. Switch to **Original values** to replay the defaults. **Reset** restores only
   the selected target and preserves edits to other targets.
4. **Copy preset** copies the complete fixture settings. **Paste preset** accepts
   only the matching fixture/version and complete, valid parameter values. A
   failed import preserves the current settings.

Drag the panel header to move it, or collapse it to inspect the preview. Hidden
targets remain available in the list. Presets use the clipboard; they do not
write source files or survive restarting the preview unless you copy them out.
Promote chosen values manually into the component's owning source.

From `client/app`, launch feedback with:

```sh
flutter run -d <ios-simulator-id> -t test/playbook/feedback_motion_tuning_playbook.dart
```

For the scan row in a native simulator, use
`test/playbook/catalog_scan_motion_tuning_playbook.dart`. In the full web
Widgetbook, choose **Mobile → Deep scan row → Motion tuning** in
`test/playbook/catalog_scan_row_playbook.dart`.

## Connect another preview

Add `sesori_motion_tuning` as a **dev dependency** of the preview host. Keep its
imports and adapters in development entrypoints such as `test/playbook/`.

- Declare a constant `List<MotionTarget>`. Give each target a fixture-scoped ID,
  readable label, and typed `MotionDuration`, `MotionNumber`, or `MotionCurve`
  descriptors. Use one descriptor per parameter ID; targets may share that same descriptor
  when their labels clearly identify the shared motion group. Match initial
  values to the real component and include source labels for promotion.
- Wrap the preview app in `MotionTuningHost(fixtureId:, targets:, onReplay:,
  child:)`. Keep the manifest fixed for that host's lifetime; key/remount the
  host when switching fixtures.
- Place `MotionTuningOverlay(child: child!)` in the app's `builder`, above its
  Navigator. Provide the PREGO theme and normal Flutter app context so the
  controls remain available above modal sheets.
- Wrap selectable content in `MotionTargetRegion(targetId:, child:)`, using a
  registered target ID once in the mounted preview. Targets without a mounted
  region can still be selected from the manifest list.
- Implement `onReplay({required MotionTarget target, required MotionSnapshot
  values})` in the preview. Capture the supplied immutable snapshot, reset a
  synthetic fixture to the transition's starting state, then trigger it. Read
  typed values with `duration(parameter:)`, `number(parameter:)`, and
  `easing(parameter:)`. Motion and any related delayed step changes must read
  the same captured snapshot.

The preview owns replay and cancellation of prior fixture work. Never wire
replay to live submission, recording, native review prompts, or other product
actions. Production components own ordinary immutable motion configuration;
they never import editor targets, descriptors, or UI. Retain their existing
defaults, accessibility behavior, and controller cleanup.

The package has no Widgetbook dependency. A Widgetbook use case or standalone
Flutter app can supply the host. Current integrations are the
[feedback tuning preview](../app/test/playbook/feedback_motion_tuning_playbook.dart) and the
[catalog scan row's Motion tuning use case](../app/test/playbook/catalog_scan_row_playbook.dart).
The scan example feeds the real
[`CatalogScanRowMotion`](../module_app_ui/lib/src/widgets/catalog_scan_row_motion.dart)
configuration, keeping fixture logic outside the production widget.

## Checks and sources

Run `flutter test` and `flutter analyze` from this package. Follow the
[regression guide](../../docs/regression/motion-tuning.md) for simulator checks
and preview-specific tests; this document records the workflow, not a completed
verification result.

- [Host, overlay, selection, and controls](lib/src/motion_tuning_host.dart)
- [Typed parameters, snapshots, and presets](lib/src/motion_parameters.dart)
- [Preset regression tests](test/motion_parameters_test.dart)
