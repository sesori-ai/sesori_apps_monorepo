import "dart:async";

import "package:bloc/bloc.dart";

import "../../logging/logging.dart";
import "../../services/voice_transcription_service.dart";
import "voice_input_state.dart";

class VoiceInputCubit({
  required final VoiceTranscriptionService _service,
  required final String? projectId,
}) extends Cubit<VoiceInputState> {
  late final VoiceTranscriptionSession _session = _service.createSession(projectId: projectId);
  late final StreamSubscription<void> _maxDurationSubscription;

  this : super(const VoiceInputState.idle()) {
    _maxDurationSubscription = _service.maxDurationReachedStream(session: _session).listen((_) {
      if (state is VoiceInputRecording) {
        unawaited(stopAndTranscribe(limitReached: true));
      }
    });
    unawaited(_service.prewarm(session: _session));
  }

  Stream<double> get amplitudeStream => _service.amplitudeStream(session: _session);

  Future<void> startRecording() async {
    if (state is! VoiceInputIdle) return;
    emit(const VoiceInputState.starting());

    try {
      await _service.start(session: _session);
      if (isClosed || state is! VoiceInputStarting) return;
      emit(const VoiceInputState.recording());
    } on VoiceTranscriptionError catch (error, stackTrace) {
      if (error is! MicrophonePermissionDeniedError) {
        loge("Failed to start recording", error, stackTrace);
      }
      if (isClosed || state is! VoiceInputStarting) return;
      emit(VoiceInputState.startFailed(error: error));
    } catch (error, stackTrace) {
      loge("Failed to start recording", error, stackTrace);
      if (isClosed || state is! VoiceInputStarting) return;
      emit(VoiceInputState.startFailed(error: VoiceTranscriptionError.recordingFailed(innerError: error)));
    }
  }

  Future<void> stopAndTranscribe({required bool limitReached}) async {
    if (state is! VoiceInputRecording) return;
    emit(VoiceInputState.transcribing(limitReached: limitReached));

    try {
      final transcript = await _service.stopAndTranscribe(session: _session);
      if (isClosed || state is! VoiceInputTranscribing) return;
      emit(VoiceInputState.completed(transcript: transcript));
    } on TranscriptionCancelledError {
      if (isClosed || state is! VoiceInputTranscribing) return;
      emit(const VoiceInputState.idle());
    } on VoiceTranscriptionError catch (error, stackTrace) {
      _logTranscriptionFailure(error: error, stackTrace: stackTrace);
      if (isClosed || state is! VoiceInputTranscribing) return;
      _emitTranscriptionFailure(error: error);
    } catch (error, stackTrace) {
      loge("Transcription failed", error, stackTrace);
      if (isClosed || state is! VoiceInputTranscribing) return;
      emit(
        VoiceInputState.transcriptionFailed(
          error: VoiceTranscriptionError.recordingFailed(innerError: error),
        ),
      );
    }
  }

  Future<void> retry() async {
    final pending = state;
    if (pending is! VoiceInputRetryPending) return;

    emit(VoiceInputState.retrying(previousError: pending.error));
    try {
      final transcript = await _service.retry(session: _session);
      if (isClosed || state is! VoiceInputRetrying) return;
      emit(VoiceInputState.completed(transcript: transcript));
    } on TranscriptionCancelledError {
      if (isClosed || state is! VoiceInputRetrying) return;
      emit(VoiceInputState.retryPending(error: pending.error));
    } on VoiceTranscriptionError catch (error, stackTrace) {
      _logTranscriptionFailure(error: error, stackTrace: stackTrace);
      if (isClosed || state is! VoiceInputRetrying) return;
      _emitTranscriptionFailure(error: error);
    } catch (error, stackTrace) {
      loge("Transcription retry failed", error, stackTrace);
      if (isClosed || state is! VoiceInputRetrying) return;
      emit(
        VoiceInputState.transcriptionFailed(
          error: VoiceTranscriptionError.recordingFailed(innerError: error),
        ),
      );
    }
  }

  Future<void> cancel() async {
    final current = state;
    if (current is VoiceInputIdle ||
        current is VoiceInputRetryPending ||
        current is VoiceInputCancelling ||
        current is VoiceInputRetryCancelling ||
        current is VoiceInputDiscarding) {
      return;
    }

    final retryError = switch (current) {
      VoiceInputRetrying(:final previousError) => previousError,
      VoiceInputStarting() ||
      VoiceInputRecording() ||
      VoiceInputTranscribing() ||
      VoiceInputCompleted() ||
      VoiceInputStartFailed() ||
      VoiceInputTranscriptionFailed() => null,
      VoiceInputIdle() ||
      VoiceInputRetryPending() ||
      VoiceInputRetryCancelling() ||
      VoiceInputDiscarding() ||
      VoiceInputCancelling() => null,
    };
    emit(
      retryError == null
          ? const VoiceInputState.cancelling()
          : VoiceInputState.retryCancelling(previousError: retryError),
    );
    try {
      await _service.cancel(session: _session);
    } catch (error, stackTrace) {
      loge("Failed to cancel the voice interaction", error, stackTrace);
    }
    if (isClosed) return;
    if (state is VoiceInputCancelling) {
      emit(const VoiceInputState.idle());
    } else if (state is VoiceInputRetryCancelling && retryError != null) {
      emit(VoiceInputState.retryPending(error: retryError));
    }
  }

  Future<void> discard() async {
    if (state is VoiceInputRetrying) await cancel();
    if (state is! VoiceInputRetryPending) return;

    emit(const VoiceInputState.discarding());
    try {
      await _service.discard(session: _session);
    } catch (error, stackTrace) {
      loge("Failed to discard the saved voice recording", error, stackTrace);
    }
    if (!isClosed && state is VoiceInputDiscarding) emit(const VoiceInputState.idle());
  }

  void acknowledgeOutcome() {
    if (state is VoiceInputCompleted || state is VoiceInputStartFailed || state is VoiceInputTranscriptionFailed) {
      emit(const VoiceInputState.idle());
    }
  }

  void _emitTranscriptionFailure({required VoiceTranscriptionError error}) {
    if (error is NetworkVoiceError || error is RetryableServerVoiceError) {
      emit(VoiceInputState.retryPending(error: error));
    } else {
      emit(VoiceInputState.transcriptionFailed(error: error));
    }
  }

  static void _logTranscriptionFailure({
    required VoiceTranscriptionError error,
    required StackTrace stackTrace,
  }) {
    if (error is! NotAuthenticatedVoiceError && error is! NetworkVoiceError) {
      loge("Transcription failed", error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    _service.invalidate(session: _session);
    await _maxDurationSubscription.cancel();
    await _service.close(session: _session);
    return await super.close();
  }
}
