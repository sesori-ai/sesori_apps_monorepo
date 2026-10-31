import "package:injectable/injectable.dart";

import "../foundation/platform/voice_mode_config_source.dart";

@lazySingleton
class VoiceModeConfigApi({required final VoiceModeConfigSource _source}) {
  Future<bool> fetchLiveEnabled() => _source.fetchLiveEnabled();
}
