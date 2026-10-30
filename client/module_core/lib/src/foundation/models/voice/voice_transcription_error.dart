sealed class const VoiceTranscriptionError._(final String message) implements Exception {
  factory microphonePermissionDenied({required Object innerError}) = MicrophonePermissionDeniedError._;

  factory recordingFailed({required Object innerError}) = RecordingFailedError._;

  factory notRecording() = NotRecordingError._;

  factory notAuthenticated({required Object? innerError}) = NotAuthenticatedVoiceError._;

  factory retryableServerError({required int statusCode, required Object? innerError}) = RetryableServerVoiceError._;

  factory serverError({required int statusCode, required Object? innerError}) = ServerVoiceError._;

  factory emptyTranscript() = EmptyTranscriptError._;

  factory networkError({required Object? innerError}) = NetworkVoiceError._;

  factory missingRecording() = MissingRecordingArtifactError._;

  factory cancelled() = TranscriptionCancelledError._;

  @override
  String toString() => "VoiceTranscriptionError: $message";
}

final class const MicrophonePermissionDeniedError._({required final Object innerError})
    extends VoiceTranscriptionError {
  this : super._("Microphone permission denied");
}

final class const RecordingFailedError._({required final Object innerError}) extends VoiceTranscriptionError {
  this : super._("Recording failed");
}

final class const NotRecordingError._() extends VoiceTranscriptionError {
  this : super._("Not currently recording");
}

final class const NotAuthenticatedVoiceError._({required final Object? innerError}) extends VoiceTranscriptionError {
  this : super._("Not authenticated");
}

final class const RetryableServerVoiceError._({
  required final int statusCode,
  required final Object? innerError,
}) extends VoiceTranscriptionError {
  this : super._("Retryable server error ($statusCode)");
}

final class const ServerVoiceError._({required final int statusCode, required final Object? innerError})
    extends VoiceTranscriptionError {
  this : super._("Server error ($statusCode)");
}

final class const EmptyTranscriptError._() extends VoiceTranscriptionError {
  this : super._("Server returned empty transcript");
}

final class const NetworkVoiceError._({required final Object? innerError}) extends VoiceTranscriptionError {
  this : super._("Network error");
}

final class const MissingRecordingArtifactError._() extends VoiceTranscriptionError {
  this : super._("Saved recording is no longer available");
}

final class const TranscriptionCancelledError._() extends VoiceTranscriptionError {
  this : super._("Transcription cancelled");
}
