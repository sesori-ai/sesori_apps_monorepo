abstract interface class VoiceModeConfigSource() {
  /// The voice mode switch: whether dictation runs live.
  Future<bool> fetchLiveEnabled();

  /// Whether transcribing on the device is allowed. False sends every dictation to
  /// the server.
  Future<bool> fetchOnDeviceEnabled();
}
