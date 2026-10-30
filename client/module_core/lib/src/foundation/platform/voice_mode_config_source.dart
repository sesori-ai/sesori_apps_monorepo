/// Raw values for the voice mode switch. [presentation] is null when the source
/// has none; the repository parses it.
typedef VoiceModeConfigValues = ({bool liveEnabled, String? presentation});

abstract interface class VoiceModeConfigSource() {
  Future<VoiceModeConfigValues> fetchValues();
}
