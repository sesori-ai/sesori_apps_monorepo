import '../foundation/device_type_detector.dart';
import '../foundation/warning_logger.dart';
import '../repositories/bridge_settings.dart';
import '../repositories/bridge_settings_repository.dart';
import '../repositories/wake_lock_repository.dart';

class SleepPreventionService({
  required final BridgeSettingsRepository _bridgeSettingsRepository,
  required final WakeLockRepository _wakeLockRepository,
  required final DeviceTypeDetector _deviceTypeDetector,
  required final WarningLogger _warningLogger,
}) {
  Future<SleepPreventionMode> applyConfiguredMode() async {
    final settings = await _bridgeSettingsRepository.loadSettings();

    switch (settings.sleepPrevention) {
      case SleepPreventionMode.always:
        try {
          await _wakeLockRepository.enable();
          await _warnIfLidCloseSleepNotPrevented();
        } on Object catch (error, stackTrace) {
          _warningLogger('[SleepPreventionService] failed to enable wake lock', error, stackTrace);
        }
      case SleepPreventionMode.off:
        try {
          await _wakeLockRepository.disable();
        } on Object catch (error, stackTrace) {
          _warningLogger('[SleepPreventionService] failed to disable wake lock', error, stackTrace);
        }
    }

    return settings.sleepPrevention;
  }

  Future<void> _warnIfLidCloseSleepNotPrevented() async {
    if (_wakeLockRepository.preventsLidCloseSleep) {
      return;
    }

    final bool isLaptop;
    try {
      isLaptop = await _deviceTypeDetector.isLaptop();
    } on Object catch (error, stackTrace) {
      _warningLogger('[SleepPreventionService] failed to detect device type', error, stackTrace);
      return;
    }

    if (!isLaptop) {
      return;
    }

    _warningLogger(
      '[SleepPreventionService] wake lock enabled, but this platform '
      'cannot prevent the system from sleeping when the laptop lid is closed.',
    );
  }

  Future<void> dispose() async {
    try {
      await _wakeLockRepository.disable();
    } on Object catch (error, stackTrace) {
      _warningLogger('[SleepPreventionService] failed to disable wake lock during dispose', error, stackTrace);
    }
  }
}
