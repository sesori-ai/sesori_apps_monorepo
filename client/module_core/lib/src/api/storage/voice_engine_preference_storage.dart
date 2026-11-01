import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../../foundation/models/voice/voice_engine.dart";
import "../../foundation/persistence/persistence_keys.dart";
import "../../logging/logging.dart";

/// The dictation engine picked on this device. A plaintext preference that survives
/// logout, like the other composer preferences.
@lazySingleton
class VoiceEnginePreferenceStorage({required final PersisterRepository _persister}) {
  /// The stored engine, or [VoiceEngine.device] when nothing was picked, the value
  /// is unknown, or the read fails.
  Future<VoiceEngine> read() async {
    try {
      final stored = await _persister.readString(key: StringPreferenceKey.voiceEngine);
      if (stored == null) return VoiceEngine.device;

      final engine = VoiceEngine.tryParse(value: stored);
      if (engine == null) {
        logw("Ignoring an unknown stored voice engine: $stored");
        return VoiceEngine.device;
      }
      return engine;
    } on Object catch (error, stackTrace) {
      logw("Failed to read the stored voice engine", error, stackTrace);
      return VoiceEngine.device;
    }
  }

  /// A failed write only costs the pick its persistence, because the running app
  /// has already switched.
  Future<void> write({required VoiceEngine engine}) async {
    try {
      await _persister.writeString(key: StringPreferenceKey.voiceEngine, value: engine.storageValue);
    } on Object catch (error, stackTrace) {
      logw("Failed to persist the voice engine", error, stackTrace);
    }
  }
}
