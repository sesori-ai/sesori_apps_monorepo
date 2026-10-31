abstract interface class VoiceModeConfigSource() {
  /// The voice mode switch: whether dictation runs live.
  Future<bool> fetchLiveEnabled();

  /// The kill switch for transcribing on the device. False sends every dictation
  /// to the server.
  Future<bool> fetchOnDeviceEnabled();
}
