import "package:injectable/injectable.dart";

import "../api/voice_mode_config_api.dart";
import "../foundation/models/voice/voice_mode.dart";

@lazySingleton
class VoiceModeRepository({required final VoiceModeConfigApi _configApi}) {
  VoiceMode _mode = const VoiceModeAfterRecording();

  /// The last loaded mode, and after-recording until a load has finished.
  /// Synchronous because a hold never waits on the switch.
  VoiceMode get mode => _mode;

  /// Reads the switch into [mode]. This can take seconds on a phone, so a
  /// recording path must not await it.
  Future<void> load() async {
    final values = await _configApi.fetchValues();
    _mode = values.liveEnabled
        ? VoiceModeLive(presentation: _parsePresentation(value: values.presentation))
        : const VoiceModeAfterRecording();
  }
}

VoiceLivePresentation _parsePresentation({required String? value}) => switch (value) {
  "panel" => VoiceLivePresentation.panel,
  _ => VoiceLivePresentation.focus,
};
