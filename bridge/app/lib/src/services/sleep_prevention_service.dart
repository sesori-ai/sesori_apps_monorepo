import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../bridge/foundation/device_type_detector.dart';
import '../repositories/bridge_settings.dart';
import '../repositories/bridge_settings_repository.dart';
import '../repositories/wake_lock_repository.dart';

typedef WarningLogger = void Function(String message);

class SleepPreventionService {
  final BridgeSettingsRepository _bridgeSettingsRepository;
  final WakeLockRepository _wakeLockRepository;
  final DeviceTypeDetector _deviceTypeDetector;
  final WarningLogger _warningLogger;

  SleepPreventionService({
    required BridgeSettingsRepository bridgeSettingsRepository,
    required WakeLockRepository wakeLockRepository,
    required DeviceTypeDetector deviceTypeDetector,
    WarningLogger? warningLogger,
  }) : _bridgeSettingsRepository = bridgeSettingsRepository,
       _wakeLockRepository = wakeLockRepository,
       _deviceTypeDetector = deviceTypeDetector,
       _warningLogger = warningLogger ?? Log.w;

  Future<SleepPreventionMode> applyConfiguredMode() async {
    final settings = await _bridgeSettingsRepository.loadSettings();

    switch (settings.sleepPrevention) {
      case SleepPreventionMode.always:
        try {
          await _wakeLockRepository.enable();
          await _warnIfLidCloseSleepNotPrevented().catchError((error) {
            _warningLogger("[SleepPreventionService] Failed to determine device type and lid close behavior");
          });
        } on Object catch (error) {
          _warningLogger(
            '[SleepPreventionService] failed to enable wake lock: $error',
          );
        }
      case SleepPreventionMode.off:
        try {
          await _wakeLockRepository.disable();
        } on Object catch (error) {
          _warningLogger(
            '[SleepPreventionService] failed to disable wake lock: $error',
          );
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
    } on Object catch (error) {
      _warningLogger(
        '[SleepPreventionService] failed to detect device type: $error',
      );
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
    } on Object catch (error) {
      _warningLogger(
        '[SleepPreventionService] failed to disable wake lock during dispose: '
        '$error',
      );
    }
  }
}
