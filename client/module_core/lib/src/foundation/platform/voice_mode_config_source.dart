abstract interface class VoiceModeConfigSource() {
  /// The voice mode switch: whether dictation runs live.
  Future<bool> fetchLiveEnabled();

  /// Whether transcribing on the device is allowed. False, which is what the
  /// `voice_on_device_disabled` kill switch gives, sends every dictation to the server.
  Future<bool> fetchOnDeviceEnabled();
}
