abstract interface class VoiceCapture() {
  Future<void> prewarm();

  VoiceCaptureSession createSession();
}

abstract interface class VoiceCaptureSession() {
  Stream<double> get amplitudeStream;

  Future<void> start();

  Future<VoiceRecordingArtifact> stop();

  Future<void> cancel();

  Future<void> releaseOperation();

  Future<void> deleteArtifact({required VoiceRecordingArtifact artifact});

  Future<void> close();
}

final class const VoiceRecordingArtifact({
  required final String path,
  required final String mimeType,
});

sealed class const VoiceCaptureError._(final String message) implements Exception {
  factory permissionDenied() = VoiceCapturePermissionDenied._;

  factory failed() = VoiceCaptureFailed._;

  @override
  String toString() => "VoiceCaptureError: $message";
}

final class const VoiceCapturePermissionDenied._() extends VoiceCaptureError {
  this : super._("Microphone permission denied");
}

final class const VoiceCaptureFailed._() extends VoiceCaptureError {
  this : super._("Voice capture failed");
}
