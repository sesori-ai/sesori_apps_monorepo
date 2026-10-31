abstract interface class VoiceModeConfigSource() {
  /// The voice mode switch: whether dictation runs live.
  Future<bool> fetchLiveEnabled();
}
