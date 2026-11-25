import 'package:sesori_shared/sesori_shared.dart' show SleepPreventionStatus;

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
  /// Applies the stored mode. The settings must already be loaded.
  Future<SleepPreventionMode> applyConfiguredMode() async {
    final settings = await _bridgeSettingsRepository.readCommittedSettings();
    await _apply(mode: settings.sleepPrevention);
    return settings.sleepPrevention;
  }

  /// Stores whether the computer stays awake and applies it right away.
  /// Returns the committed choice.
  Future<bool> update({required bool enabled}) async {
    final committed = await _bridgeSettingsRepository.updatePreventSleep(enabled: enabled);
    await _apply(mode: committed.sleepPrevention);
    return committed.preventsSleep;
  }

  /// The stored choice, and for an "on" choice whether the wake lock holds.
  Future<SleepPreventionStatus> status() async {
    final settings = await _bridgeSettingsRepository.readCommittedSettings();
    return switch (settings.sleepPrevention) {
      SleepPreventionMode.off => SleepPreventionStatus.off,
      SleepPreventionMode.always when _wakeLockRepository.isHeld => SleepPreventionStatus.awake,
      SleepPreventionMode.always => SleepPreventionStatus.failed,
    };
  }

  Future<void> _apply({required SleepPreventionMode mode}) async {
    switch (mode) {
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
