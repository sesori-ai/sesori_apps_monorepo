import "package:injectable/injectable.dart";

import "../api/voice_mode_config_api.dart";
import "../foundation/models/voice/voice_mode.dart";

@lazySingleton
class VoiceModeRepository({required final VoiceModeConfigApi _configApi}) {
  VoiceMode _mode = const VoiceModeAfterRecording();
  bool _onDeviceEnabled = false;

  /// The last loaded mode, and after-recording until a load has finished.
  /// Synchronous because a hold never waits on the switch.
  VoiceMode get mode => _mode;

  /// Whether on-device transcription is allowed: the inverse of the
  /// `voice_on_device_disabled` kill switch. False until a load has finished, so a
  /// hold before the answer stays on the server.
  bool get onDeviceEnabled => _onDeviceEnabled;

  /// Reads the switch into [mode]. This can take seconds on a phone, so a
  /// recording path must not await it.
  Future<void> load() async {
    final liveEnabled = await _configApi.fetchLiveEnabled();
    _mode = liveEnabled ? const VoiceModeLive() : const VoiceModeAfterRecording();
    _onDeviceEnabled = await _configApi.fetchOnDeviceEnabled();
  }
}
