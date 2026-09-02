import "package:injectable/injectable.dart";

import "../foundation/platform/creator_recording.dart";
import "../repositories/creator_recording_repository.dart";

/// Owns the capture-to-persisted-export workflow above the platform boundary.
@lazySingleton
class CreatorRecordingService({required final CreatorRecordingRepository _repository}) {
  bool get isSupported => _repository.isSupported;

  /// Reconciles native bubble outcomes against the manifest-backed library
  /// before consumers are told that a recording completed.
  Stream<CreatorRecordingWorkflowEvent> get events => _repository.events.asyncMap(_reconcileEvent);

  Future<void> preparePreview() => _repository.preparePreview();

  Future<void> dismissPreview() => _repository.dismissPreview();

  Future<void> start() => _repository.start();

  Future<CreatorRecordingCompletion> stop() async {
    final artifact = await _repository.stop();
    return await _reconcileCompletion(artifact: artifact);
  }

  Future<List<CreatorRecordingArtifact>> loadSavedRecordings() => _repository.listRecordings();

  Future<List<CreatorRecordingArtifact>> deleteRecording({
    required CreatorRecordingArtifact artifact,
  }) async {
    await _repository.deleteRecording(artifact: artifact);
    return await _repository.listRecordings();
  }

  Future<void> shareRecording({
    required CreatorRecordingArtifact artifact,
    required CreatorRecordingExportKind kind,
  }) => _repository.shareRecording(artifact: artifact, kind: kind);

  Future<CreatorRecordingWorkflowEvent> _reconcileEvent(CreatorRecordingEvent event) async {
    switch (event) {
      case CreatorRecordingSaving():
        return const CreatorRecordingWorkflowSaving();
      case CreatorRecordingFailed(:final failure):
        return CreatorRecordingWorkflowFailed(failure: failure);
      case CreatorRecordingCompleted(:final artifact):
        try {
          return CreatorRecordingWorkflowCompleted(
            completion: await _reconcileCompletion(artifact: artifact),
          );
        } on CreatorRecordingFailure catch (failure) {
          return CreatorRecordingWorkflowFailed(failure: failure);
        } on Object catch (error) {
          return CreatorRecordingWorkflowFailed(
            failure: CreatorRecordingFailure(
              reason: CreatorRecordingFailureReason.storage,
              innerError: error,
            ),
          );
        }
    }
  }

  Future<CreatorRecordingCompletion> _reconcileCompletion({
    required CreatorRecordingArtifact artifact,
  }) async {
    final recordings = await _repository.listRecordings();
    for (final persisted in recordings) {
      if (persisted.id == artifact.id) {
        return CreatorRecordingCompletion(artifact: persisted, recordings: recordings);
      }
    }
    throw CreatorRecordingFailure(
      reason: CreatorRecordingFailureReason.storage,
      innerError: StateError("Completed creator recording has no persisted manifest"),
    );
  }
}

final class const CreatorRecordingCompletion({
  required final CreatorRecordingArtifact artifact,
  required final List<CreatorRecordingArtifact> recordings,
});

sealed class const CreatorRecordingWorkflowEvent();

final class const CreatorRecordingWorkflowSaving() extends CreatorRecordingWorkflowEvent;

final class const CreatorRecordingWorkflowCompleted({
  required final CreatorRecordingCompletion completion,
}) extends CreatorRecordingWorkflowEvent;

final class const CreatorRecordingWorkflowFailed({required final CreatorRecordingFailure failure})
    extends CreatorRecordingWorkflowEvent;
