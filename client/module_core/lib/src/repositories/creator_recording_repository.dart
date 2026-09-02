import "package:injectable/injectable.dart";

import "../foundation/platform/creator_recording.dart";

/// Layer-2 boundary for locally persisted creator-recording artifacts.
@lazySingleton
class CreatorRecordingRepository({required final CreatorRecording _recording}) {
  bool get isSupported => _recording.isSupported;

  Stream<CreatorRecordingEvent> get events => _recording.events;

  Future<void> preparePreview() => _recording.preparePreview();

  Future<void> dismissPreview() => _recording.dismissPreview();

  Future<void> start() => _recording.start();

  Future<CreatorRecordingArtifact> stop() => _recording.stop();

  Future<List<CreatorRecordingArtifact>> listRecordings() => _recording.listRecordings();

  Future<void> deleteRecording({required CreatorRecordingArtifact artifact}) =>
      _recording.deleteRecording(artifact: artifact);

  Future<void> shareRecording({
    required CreatorRecordingArtifact artifact,
    required CreatorRecordingExportKind kind,
  }) => _recording.shareRecording(artifact: artifact, kind: kind);
}
