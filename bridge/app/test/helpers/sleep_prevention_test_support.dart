import "package:sesori_bridge/src/foundation/device_type_detector.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/wake_lock_repository.dart";
import "package:sesori_bridge/src/services/sleep_prevention_service.dart";

import "plugin_lifecycle_test_support.dart";

/// A sleep prevention service that never touches the real wake lock.
SleepPreventionService createTestSleepPreventionService({
  required BridgeSettingsRepository? bridgeSettingsRepository,
  required RecordingWakeLockRepository? wakeLockRepository,
}) => SleepPreventionService(
  bridgeSettingsRepository: bridgeSettingsRepository ?? createTestBridgeSettingsRepository(),
  wakeLockRepository: wakeLockRepository ?? RecordingWakeLockRepository(),
  deviceTypeDetector: _DesktopDeviceTypeDetector(),
  warningLogger: (_, [_, _]) {},
);

class RecordingWakeLockRepository() implements WakeLockRepository {
  @override
  bool isHeld = false;

  @override
  bool get preventsLidCloseSleep => true;

  @override
  Future<void> enable() async => isHeld = true;

  @override
  Future<void> disable() async => isHeld = false;
}

class _DesktopDeviceTypeDetector() implements DeviceTypeDetector {
  @override
  Future<bool> isLaptop() async => false;
}
