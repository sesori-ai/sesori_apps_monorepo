/// Which locally produced creator-recording output the user wants to share.
enum CreatorRecordingExportKind() {
  composedVideo,
  sourceLayers,
}

/// Stable failure categories parsed at the platform boundary.
enum CreatorRecordingFailureReason() {
  unsupported,
  cameraPermissionDenied,
  microphonePermissionDenied,
  portraitRequired,
  screenCaptureUnavailable,
  recordingAlreadyInProgress,
  recordingNotInProgress,
  storage,
  capture,
  export,
  unexpected,
}

/// A completed local creator recording and every file needed to export it.
final class const CreatorRecordingArtifact({
  required final String id,
  required final DateTime createdAt,
  required final Duration duration,
  required final String composedVideoPath,
  required final String screenVideoPath,
  required final String cameraVideoPath,
  required final String microphoneAudioPath,
  required final String movementMetadataPath,
  required final String manifestPath,
});

/// A privacy-safe platform recording failure that retains its original cause.
final class const CreatorRecordingFailure({
  required final CreatorRecordingFailureReason reason,
  // The platform may report only a closed reason with no underlying exception.
  // ignore: no_slop_linter/prefer_specific_type, platform failures can be Error or Exception
  required final Object? innerError,
}) implements Exception {
  @override
  String toString() => "CreatorRecordingFailure(${reason.name})";
}

/// Native lifecycle outcomes that can occur without a Flutter button press.
sealed class const CreatorRecordingEvent();

/// The native bubble's stop control was pressed and the recording is rendering.
final class const CreatorRecordingSaving() extends CreatorRecordingEvent;

/// Native capture and composition completed successfully.
final class const CreatorRecordingCompleted({required final CreatorRecordingArtifact artifact})
    extends CreatorRecordingEvent;

/// Native capture stopped without a complete exportable recording.
final class const CreatorRecordingFailed({required final CreatorRecordingFailure failure})
    extends CreatorRecordingEvent;

/// Local screen, front-camera, microphone, movement, and export capability.
abstract interface class CreatorRecording() {
  bool get isSupported;

  Stream<CreatorRecordingEvent> get events;

  Future<void> preparePreview();

  Future<void> dismissPreview();

  Future<void> start();

  Future<CreatorRecordingArtifact> stop();

  Future<List<CreatorRecordingArtifact>> listRecordings();

  Future<void> deleteRecording({required CreatorRecordingArtifact artifact});

  Future<void> shareRecording({
    required CreatorRecordingArtifact artifact,
    required CreatorRecordingExportKind kind,
  });
}
