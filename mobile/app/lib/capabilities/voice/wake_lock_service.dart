import "package:injectable/injectable.dart";
import "package:sesori_dart_core/logging.dart";
import "package:wakelock_plus/wakelock_plus.dart";

/// Thin wrapper around [WakelockPlus] for injectable testability.
///
/// Wake lock failures are logged but never thrown — they must not
/// interrupt the recording flow.
@lazySingleton
class WakeLockService {
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (error, stackTrace) {
      logw("Failed to enable wake lock", error, stackTrace);
    }
  }

  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (error, stackTrace) {
      logw("Failed to disable wake lock", error, stackTrace);
    }
  }
}
