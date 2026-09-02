import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/platform/creator_recording.dart";
import "../../logging/logging.dart";
import "../../services/creator_recording_service.dart";
import "creator_recording_state.dart";

class CreatorRecordingCubit({required final CreatorRecordingService _service}) extends Cubit<CreatorRecordingState> {
  late final StreamSubscription<CreatorRecordingWorkflowEvent> _eventSubscription;

  this
    : super(
        CreatorRecordingState(
          capture: _service.isSupported ? const CreatorRecordingIdle() : const CreatorRecordingUnsupported(),
          library: _service.isSupported
              ? const CreatorRecordingLibraryLoading()
              : const CreatorRecordingLibraryLoaded(recordings: []),
          export: const CreatorRecordingExportIdle(),
        ),
      ) {
    _eventSubscription = _service.events.listen(
      _onPlatformEvent,
      onError: (Object error, StackTrace stackTrace) {
        loge("Creator recording event stream failed", error, stackTrace);
        if (isClosed) return;
        emit(
          state.withCapture(
            capture: CreatorRecordingCaptureFailed(failure: _unexpectedFailure(error: error)),
          ),
        );
      },
    );
    if (_service.isSupported) unawaited(refreshLibrary());
  }

  Future<bool> preparePreview() async {
    if (state.capture is! CreatorRecordingIdle &&
        state.capture is! CreatorRecordingPrepareFailed &&
        state.capture is! CreatorRecordingCaptureCompleted &&
        state.capture is! CreatorRecordingCaptureFailed) {
      return false;
    }

    emit(state.withCapture(capture: const CreatorRecordingPreparing()));
    try {
      await _service.preparePreview();
      if (isClosed || state.capture is! CreatorRecordingPreparing) return false;
      emit(state.withCapture(capture: const CreatorRecordingPreviewReady()));
      return true;
    } on CreatorRecordingFailure catch (failure) {
      if (isClosed || state.capture is! CreatorRecordingPreparing) return false;
      emit(state.withCapture(capture: CreatorRecordingPrepareFailed(failure: failure)));
      return false;
    } on Object catch (error, stackTrace) {
      loge("Failed to prepare creator recording", error, stackTrace);
      if (isClosed || state.capture is! CreatorRecordingPreparing) return false;
      emit(
        state.withCapture(
          capture: CreatorRecordingPrepareFailed(failure: _unexpectedFailure(error: error)),
        ),
      );
      return false;
    }
  }

  Future<bool> start() async {
    if (state.capture is! CreatorRecordingPreviewReady && state.capture is! CreatorRecordingStartFailed) {
      return false;
    }

    emit(state.withCapture(capture: const CreatorRecordingStarting()));
    try {
      await _service.start();
      if (isClosed || state.capture is! CreatorRecordingStarting) return false;
      emit(state.withCapture(capture: const CreatorRecordingActive()));
      return true;
    } on CreatorRecordingFailure catch (failure) {
      if (isClosed || state.capture is! CreatorRecordingStarting) return false;
      emit(state.withCapture(capture: CreatorRecordingStartFailed(failure: failure)));
      return false;
    } on Object catch (error, stackTrace) {
      loge("Failed to start creator recording", error, stackTrace);
      if (isClosed || state.capture is! CreatorRecordingStarting) return false;
      emit(
        state.withCapture(
          capture: CreatorRecordingStartFailed(failure: _unexpectedFailure(error: error)),
        ),
      );
      return false;
    }
  }

  Future<void> stop() async {
    if (state.capture is! CreatorRecordingActive) return;

    emit(state.withCapture(capture: const CreatorRecordingSavingCapture()));
    try {
      final completion = await _service.stop();
      if (isClosed || state.capture is! CreatorRecordingSavingCapture) return;
      emit(
        CreatorRecordingState(
          capture: CreatorRecordingCaptureCompleted(artifact: completion.artifact),
          library: CreatorRecordingLibraryLoaded(recordings: completion.recordings),
          export: state.export,
        ),
      );
    } on CreatorRecordingFailure catch (failure) {
      if (isClosed || state.capture is! CreatorRecordingSavingCapture) return;
      emit(state.withCapture(capture: CreatorRecordingCaptureFailed(failure: failure)));
    } on Object catch (error, stackTrace) {
      loge("Failed to stop creator recording", error, stackTrace);
      if (isClosed || state.capture is! CreatorRecordingSavingCapture) return;
      emit(
        state.withCapture(
          capture: CreatorRecordingCaptureFailed(failure: _unexpectedFailure(error: error)),
        ),
      );
    }
  }

  Future<void> dismissPreview() async {
    if (state.capture is! CreatorRecordingPreviewReady && state.capture is! CreatorRecordingStartFailed) {
      return;
    }
    try {
      await _service.dismissPreview();
      if (!isClosed) emit(state.withCapture(capture: const CreatorRecordingIdle()));
    } on CreatorRecordingFailure catch (failure) {
      if (!isClosed) {
        emit(state.withCapture(capture: CreatorRecordingCaptureFailed(failure: failure)));
      }
    } on Object catch (error, stackTrace) {
      loge("Failed to dismiss creator recording preview", error, stackTrace);
      if (!isClosed) {
        emit(
          state.withCapture(
            capture: CreatorRecordingCaptureFailed(failure: _unexpectedFailure(error: error)),
          ),
        );
      }
    }
  }

  Future<void> refreshLibrary() async {
    if (!_service.isSupported) return;
    emit(state.withLibrary(library: const CreatorRecordingLibraryLoading()));
    try {
      final recordings = await _service.loadSavedRecordings();
      if (isClosed) return;
      emit(state.withLibrary(library: CreatorRecordingLibraryLoaded(recordings: recordings)));
    } on CreatorRecordingFailure catch (failure) {
      if (!isClosed) {
        emit(state.withLibrary(library: CreatorRecordingLibraryFailed(failure: failure)));
      }
    } on Object catch (error, stackTrace) {
      loge("Failed to load creator recordings", error, stackTrace);
      if (!isClosed) {
        emit(
          state.withLibrary(
            library: CreatorRecordingLibraryFailed(failure: _unexpectedFailure(error: error)),
          ),
        );
      }
    }
  }

  Future<void> deleteRecording({required CreatorRecordingArtifact artifact}) async {
    if (state.library is CreatorRecordingLibraryLoading) return;
    emit(state.withLibrary(library: const CreatorRecordingLibraryLoading()));
    try {
      final recordings = await _service.deleteRecording(artifact: artifact);
      if (!isClosed) {
        emit(state.withLibrary(library: CreatorRecordingLibraryLoaded(recordings: recordings)));
      }
    } on CreatorRecordingFailure catch (failure) {
      if (!isClosed) {
        emit(state.withLibrary(library: CreatorRecordingLibraryFailed(failure: failure)));
      }
    } on Object catch (error, stackTrace) {
      loge("Failed to delete creator recording", error, stackTrace);
      if (!isClosed) {
        emit(
          state.withLibrary(
            library: CreatorRecordingLibraryFailed(failure: _unexpectedFailure(error: error)),
          ),
        );
      }
    }
  }

  Future<void> shareRecording({
    required CreatorRecordingArtifact artifact,
    required CreatorRecordingExportKind kind,
  }) async {
    if (state.export is CreatorRecordingSharing) return;
    emit(
      state.withExport(
        export: CreatorRecordingSharing(artifact: artifact, kind: kind),
      ),
    );
    try {
      await _service.shareRecording(artifact: artifact, kind: kind);
      if (!isClosed) emit(state.withExport(export: const CreatorRecordingExportIdle()));
    } on CreatorRecordingFailure catch (failure) {
      if (!isClosed) {
        emit(
          state.withExport(
            export: CreatorRecordingShareFailed(artifact: artifact, kind: kind, failure: failure),
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      loge("Failed to share creator recording", error, stackTrace);
      if (!isClosed) {
        emit(
          state.withExport(
            export: CreatorRecordingShareFailed(
              artifact: artifact,
              kind: kind,
              failure: _unexpectedFailure(error: error),
            ),
          ),
        );
      }
    }
  }

  void acknowledgeCaptureOutcome() {
    if (state.capture is CreatorRecordingCaptureCompleted ||
        state.capture is CreatorRecordingCaptureFailed ||
        state.capture is CreatorRecordingPrepareFailed) {
      emit(state.withCapture(capture: const CreatorRecordingIdle()));
    }
  }

  void acknowledgeShareFailure() {
    if (state.export is CreatorRecordingShareFailed) {
      emit(state.withExport(export: const CreatorRecordingExportIdle()));
    }
  }

  void _onPlatformEvent(CreatorRecordingWorkflowEvent event) {
    if (isClosed) return;
    switch (event) {
      case CreatorRecordingWorkflowSaving():
        if (state.capture is CreatorRecordingActive) {
          emit(state.withCapture(capture: const CreatorRecordingSavingCapture()));
        }
      case CreatorRecordingWorkflowCompleted(:final completion):
        emit(
          CreatorRecordingState(
            capture: CreatorRecordingCaptureCompleted(artifact: completion.artifact),
            library: CreatorRecordingLibraryLoaded(recordings: completion.recordings),
            export: state.export,
          ),
        );
      case CreatorRecordingWorkflowFailed(:final failure):
        emit(state.withCapture(capture: CreatorRecordingCaptureFailed(failure: failure)));
    }
  }

  static CreatorRecordingFailure _unexpectedFailure({required Object error}) =>
      CreatorRecordingFailure(reason: CreatorRecordingFailureReason.unexpected, innerError: error);

  @override
  Future<void> close() async {
    await _eventSubscription.cancel();
    return await super.close();
  }
}
