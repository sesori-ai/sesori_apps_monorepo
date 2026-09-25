# Step 33 — Show when YOLO is on

## What changed

- The settings hint is now one plain sentence: "Sesori approves every
  permission request for you, so the agent never stops to ask." It has no
  warning tone.
- A new `module_core` `BridgeSettingsService` owns the last-known YOLO flag.
  It loads the bridge settings on every connect. A committed YOLO save updates
  the flag. A failed load keeps the last value, and an older bridge without
  the setting reads as off.
- `BridgeSettingsCubit` now loads and saves through the service instead of the
  repository, so a change saved in Settings reaches open session pages at once.
- `SessionDetailCubit` subscribes to the service and carries `yoloEnabled` in
  `SessionDetailLoaded`.
- While the flag is on, the composer's model row shows a neutral "YOLO" chip
  after the model and variant buttons. Tapping it opens a sheet on phone and a
  dialog on desktop. It explains the setting in the same sentence and offers
  "Open Settings".
- `SessionDetailPresentationScope` gained `openBridgeSettings`. The phone
  pushes the settings route, and desktop opens the settings modal on the Bridge
  tab.

## Deviations

- The chip sits in the composer's model row. The session subtitle it could
  have joined was removed in step 22.
- The chip uses the bolt icon from D21. Fast mode uses the same icon in the
  same row. The "YOLO" label tells them apart.
- The new-session page shows no chip. The step names session pages only.
- While Settings is open during a connect, both the service and the settings
  cubit load, so the bridge settings are read twice. Both publish to the same
  stream, and the cost is one small request.
- The flag is not tied to a bridge. After a switch to another bridge, the old
  value shows until the new load completes. This is accepted as low damage,
  like the cross-surface staleness the plan already accepts.

## Verification

- `module_core` `dart test` passes (1912 tests). The new
  `bridge_settings_service_test.dart` checks:
  - it loads on connect;
  - a failed load keeps the flag;
  - an unsupported bridge reads as off;
  - a committed save updates the stream;
  - a failed save leaves it unchanged.

  A new `SessionDetailCubit` test checks that the loaded state carries the
  flag and follows its changes.
- `module_app_ui` `flutter test` passes (480), `app` `flutter test` passes
  (799), and `desktop` `flutter test` passes (295). The new
  `session_detail_body_test` case shows the chip only while YOLO is on. It
  opens the explanation and checks that "Open Settings" calls the shell
  callback and closes the modal.
- `dart analyze --fatal-infos` is clean in module_core, module_app_ui, app and
  desktop.
- The architecture implementation review approved on the first pass, with no
  blocking findings. It made two notes: the bridge-switch staleness and the
  double load. Both are recorded above as accepted.
- `docs/regression/permission-auto-approval.md` records the plain sentence,
  the chip, a failure signal and the last-known-value limitation.
- Fixture before and after renders, for phone and desktop in light and dark,
  are in the PR.
