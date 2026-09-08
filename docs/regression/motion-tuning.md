# Motion tuning

## Capability

The private `sesori_motion_tuning` Flutter package supplies a reusable editor
for explicitly connected preview animations. The feedback preview and real
catalog scan row preview provide independent fixtures. Production components
retain their normal defaults and never depend on the editor.

Selection highlights a connected region without triggering its action. A
manifest list also exposes hidden transitions; overlapping regions require a
choice. Typed controls edit a draft snapshot. Replay captures one immutable
snapshot for the animation and its related timing. Original comparison and
target reset leave unrelated draft values intact. Numeric fields and slider
announcements retain the precision declared by each parameter step. The floating
panel stays within the screen safe area, including landscape side insets and
the home indicator, while accommodating the keyboard.

The feedback star bounce defaults to 470 ms, with a subtle 0.99 dip and a 1.18
peak before settling. Only the chosen star scales; the selected range fills
immediately, and reduced-motion settings preserve the fill without scaling.

The feedback result target replays the shared top toast with its standard
motion and automatic dismissal. It is labeled replay only and exposes no
target-specific tuning controls. Whole-flow replay uses that same presenter;
native rating requests remain disabled in tuning mode.

The feedback voice preview supports holding to record, releasing to transcribe,
and dragging onto the red X to cancel. Cancellation preserves existing text and
selected issues. The destructive gradient and flattened waveform follow the
finger, and moving away restores recording. The X also supports a direct tap.
Transcription failure displays the shared top error toast, then returns to the
composer for a fresh recording or keyboard input without changing the draft.

The explicitly selected microphone permission scenario opens real iOS/Android
system permission UI, or app settings when access is denied. Recording remains
simulated. Returning from that UI requires a fresh gesture; permission completion
must never start a recording after the original hold ended or the sheet closed.
Already-authorized access continues the current gesture without requiring an
extra hold. Restricted iOS access does not send users to an inapplicable settings
page.
Automatic motion replay never opens permission UI.

Global animation speed offers Normal (1×), 0.5×, and 0.2× without selecting a
target. It changes Flutter's scheduler clock immediately across the preview,
including unconnected animations, and shows slow speed in the collapsed header.
It leaves tuned durations and presets unchanged and restores the previous clock
when the host is removed. Dart timers/delayed fixture actions and native platform
animations are outside Flutter's animation clock.

Clipboard presets contain a fixture ID, format version, and complete parameter
values. Invalid imports leave the previous settings intact. Presets do not
change source code or add persistent runtime settings.

## Regression levels

| Level | Coverage to execute |
|---|---|
| L1 Smoke | Automated: selection consumes taps while interact mode preserves actions; overlapping and hidden targets remain selectable; edits/replay receive the selected target and immutable values; original comparison and target reset preserve other edits; typed preset round-trips and malformed/wrong-fixture/wrong-version/missing/unknown/out-of-range/nonfinite inputs reject atomically. Run feedback timing/replay tests, including native-review suppression, and scan-row default, replay, lifecycle, and reduced-motion tests. Check editor imports remain confined to development entrypoints and dev dependencies. |
| L2 Routine | iOS simulator: run both feedback and the catalog scan row **Motion tuning** use case. Select visually and through the list, edit/replay repeatedly, compare/reset, copy/paste valid and invalid presets, and switch light/dark themes. Exercise keyboard-visible feedback, modal sheets, overlapping/hidden scan targets, long durations, rapid replays, and reduced motion. Confirm the panel stays accessible and does not resize the preview. Check the normal product entrypoint exposes no tuning route or controls. |
| L3 Release | No additional coverage. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

These are checks to perform, not claims that a simulator run or release
inspection has passed.

## Execution

From `client/motion_tuning`, run `flutter test` and `flutter analyze`. From
`client/app`, run the relevant tests under `test/playbook/`, then launch each
preview with the existing pinned Flutter toolchain:

```sh
flutter run -d <ios-simulator-id> -t test/playbook/feedback_motion_tuning_playbook.dart
flutter run -d <ios-simulator-id> -t test/playbook/catalog_scan_motion_tuning_playbook.dart
```

The full web catalog playbook also offers **Mobile → Deep scan row → Motion tuning**.
When shared scan motion configuration changes, run
`flutter test test/widgets/catalog_scan_row_test.dart` from
`client/module_app_ui`, analyze that module and the app, and check affected
mobile/desktop consumers using `CatalogScanRowMotion.standard`.

## Material failure signals

- Global speed changes only the selected target, changes stored duration values,
  uses the inverse speed incorrectly, or leaks after leaving or replacing the
  tuning host. Reparenting a retained host must preserve its selected speed.

- Selecting triggers a feedback action or scan cancel/dismiss callback.
- Replay invokes native rating, real recording/submission, backend scanning,
  or another external operation instead of its synthetic fixture.
- A prior replay changes a newly started preview, or the feedback step advances
  using a different duration than its visible animation.
- Editing one target changes values outside its explicitly labeled shared group, or rejected paste changes
  part of the current settings.
- Tuning controls become covered by a modal sheet, home indicator, landscape
  cutout, or keyboard; expanding the panel changes the preview's available layout size.
- Numeric fields or slider announcements round away a parameter's declared step precision.
- Composer action reveals clip the native button's pressed scale or shadow
  against a rectangular boundary inside the voice-input surface.
- Cancelling a recording starts transcription, deletes an existing draft, or
  leaves the destructive gradient visible during transcription.
- Microphone failure adds inline error copy instead of opening native permission
  UI/settings; transcription failure fails to show the shared top error toast.
- Denying the first retryable Android microphone prompt immediately opens Settings
  instead of returning to the preview and allowing another permission request.
- Permission completion starts a recording after the original hold ended or the
  sheet closed, or returning from permission UI resumes without a fresh gesture.
- Already-authorized microphone access discards the first recording gesture.
- Ordinary scan-row defaults change, reduced motion is lost, or controllers
  continue after the widget is removed.
- Production entrypoints import the toolkit or expose its controls.

## Sources

- [Toolkit API and integration instructions](../../client/motion_tuning/README.md)
- [Host and controls](../../client/motion_tuning/lib/src/motion_tuning_host.dart)
- [Snapshot and preset tests](../../client/motion_tuning/test/motion_parameters_test.dart)
- [Feedback preview](../../client/app/test/playbook/feedback_flow_playbook.dart)
- [Feedback preview tests](../../client/app/test/playbook/feedback_flow_playbook_test.dart)
- [Feedback animation tests](../../client/app/test/playbook/feedback_motion_test.dart)
- [Scan preview and replay adapter](../../client/app/test/playbook/catalog_scan_row_playbook.dart)
- [Scan preview tests](../../client/app/test/playbook/catalog_scan_row_playbook_test.dart)
- [Production scan motion](../../client/module_app_ui/lib/src/widgets/catalog_scan_row_motion.dart)
- [Production scan tests](../../client/module_app_ui/test/widgets/catalog_scan_row_test.dart)
