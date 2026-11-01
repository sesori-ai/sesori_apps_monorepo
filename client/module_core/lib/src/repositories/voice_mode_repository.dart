import "package:injectable/injectable.dart";

import "../api/storage/voice_engine_preference_storage.dart";
import "../api/voice_mode_config_api.dart";
import "../foundation/models/voice/voice_engine.dart";
import "../foundation/models/voice/voice_mode.dart";

@lazySingleton
class VoiceModeRepository({
  required final VoiceModeConfigApi _configApi,
  required final VoiceEnginePreferenceStorage _engineStorage,
}) {
  VoiceMode _mode = const VoiceModeAfterRecording();
  bool _onDeviceEnabled = false;
  VoiceEngine _engine = VoiceEngine.device;
  Future<void>? _engineLoad;

  /// The last loaded mode, and after-recording until a load has finished.
  /// Synchronous because a hold never waits on the switch.
  VoiceMode get mode => _mode;

  /// Whether on-device transcription is allowed. False until a load has finished,
  /// so a hold before the answer stays on the server.
  bool get onDeviceEnabled => _onDeviceEnabled;

  /// The engine picked in Settings, and device until [loadEngine] has finished.
  VoiceEngine get engine => _engine;

  /// Reads the switch into [mode]. This can take seconds on a phone, so a
  /// recording path must not await it.
  Future<void> load() async {
    final liveEnabled = await _configApi.fetchLiveEnabled();
    _mode = liveEnabled ? const VoiceModeLive() : const VoiceModeAfterRecording();
    _onDeviceEnabled = await _configApi.fetchOnDeviceEnabled();
  }

  /// Reads the picked engine into [engine], once per process. Apart from [load], so
  /// that no Remote Config failure can skip it.
  Future<void> loadEngine() => _engineLoad ??= _readEngine();

  Future<void> _readEngine() async => _engine = await _engineStorage.read();

  /// Waits for [loadEngine], so a pick made during the first read can't be overwritten by it.
  Future<void> setEngine({required VoiceEngine engine}) async {
    await loadEngine();
    _engine = engine;
    await _engineStorage.write(engine: engine);
  }
}
