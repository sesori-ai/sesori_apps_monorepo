import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../repositories/bridge_settings.dart';
import '../repositories/bridge_settings_repository.dart';
import '../repositories/wake_lock_repository.dart';

class SleepPreventionService {
  final BridgeSettingsRepository _bridgeSettingsRepository;
  final WakeLockRepository _wakeLockRepository;

  SleepPreventionService({
    required BridgeSettingsRepository bridgeSettingsRepository,
    required WakeLockRepository wakeLockRepository,
  }) : _bridgeSettingsRepository = bridgeSettingsRepository,
       _wakeLockRepository = wakeLockRepository;

  Future<SleepPreventionMode> applyConfiguredMode() async {
    final settings = await _bridgeSettingsRepository.loadSettings();

    switch (settings.sleepPrevention) {
      case SleepPreventionMode.always:
        try {
          await _wakeLockRepository.enable();
        } on Object catch (error) {
          Log.w('[SleepPreventionService] failed to enable wake lock: $error');
        }
      case SleepPreventionMode.off:
        try {
          await _wakeLockRepository.disable();
        } on Object catch (error) {
          Log.w('[SleepPreventionService] failed to disable wake lock: $error');
        }
    }

    return settings.sleepPrevention;
  }

  Future<void> dispose() async {
    try {
      await _wakeLockRepository.disable();
    } on Object catch (error) {
      Log.w('[SleepPreventionService] failed to disable wake lock during dispose: $error');
    }
  }
}
