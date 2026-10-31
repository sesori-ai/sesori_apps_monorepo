import "dart:typed_data";

import "../foundation/models/voice/voice_realtime.dart";

/// The rate of [VoiceCaptureSession.startPcmStream]'s frames, to announce to the
/// realtime endpoint.
const VoiceRealtimeSampleRate voiceCapturePcmSampleRate = VoiceRealtimeSampleRate.hz16000;

abstract interface class VoiceCapture() {
  Future<void> prewarm();

  VoiceCaptureSession createSession();
}

abstract interface class VoiceCaptureSession() {
  Stream<double> get amplitudeStream;

  Future<void> start();

  /// Whether this host can attempt [startPcmStream]: the recorder implements it
  /// and the tools it runs are installed. A yes is not proof that a microphone
  /// delivers audio here, so [startPcmStream] and its frames can still fail.
  Future<bool> supportsPcmStream();

  /// Starts capturing PCM16 little-endian mono at [voiceCapturePcmSampleRate], kept
  /// in memory only. Throws a [VoiceCaptureError] if capture can't start.
  ///
  /// Every frame is even and within the realtime endpoint's frame size. The stream
  /// is single-subscription and closes after [stopPcmStream] or [cancel]. If capture
  /// fails, or the recorder ends it or changes its format, the stream delivers a
  /// [VoiceCaptureFailed] and closes, and the caller still has to [cancel].
  ///
  /// After [cancel], [start] works, which is how a dictation falls back to
  /// recording a file.
  Future<Stream<Uint8List>> startPcmStream();

  /// Stops the microphone. Frames still on their way arrive before the stream
  /// closes. A last half sample is dropped. Like [stop], this keeps the operation
  /// held until [releaseOperation].
  Future<void> stopPcmStream();

  Future<VoiceRecordingArtifact> stop();

  Future<void> cancel();

  Future<void> releaseOperation();

  Future<bool> artifactExists({required VoiceRecordingArtifact artifact});

  Future<void> deleteArtifact({required VoiceRecordingArtifact artifact});

  Future<void> close();
}

final class const VoiceRecordingArtifact({
  required final String path,
  required final String mimeType,
});

sealed class const VoiceCaptureError._(
  final String message, {
  required final Object? innerError,
}) implements Exception {
  factory permissionDenied({required Object? innerError}) = VoiceCapturePermissionDenied._;

  factory failed({required Object? innerError}) = VoiceCaptureFailed._;

  @override
  String toString() => "VoiceCaptureError: $message";
}

final class const VoiceCapturePermissionDenied._({required super.innerError}) extends VoiceCaptureError {
  this : super._("Microphone permission denied");
}

final class const VoiceCaptureFailed._({required super.innerError}) extends VoiceCaptureError {
  this : super._("Voice capture failed");
}
