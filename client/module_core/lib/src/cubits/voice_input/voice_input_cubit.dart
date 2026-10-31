import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/voice/voice_dictation_outcome.dart";
import "../../foundation/models/voice/voice_live.dart";
import "../../foundation/models/voice/voice_transcription_error.dart";
import "../../logging/logging.dart";
import "../../services/voice_transcription_service.dart";
import "voice_input_state.dart";

class VoiceInputCubit({
  required final VoiceTranscriptionService _service,
  required final VoiceTranscriptionSession _session,
}) extends Cubit<VoiceInputState> {
  late final StreamSubscription<void> _maxDurationSubscription;
  late final StreamSubscription<VoiceLiveEvent> _liveEventSubscription;

  this : super(const VoiceInputState.idle()) {
    _maxDurationSubscription = _service.maxDurationReachedStream(session: _session).listen((_) {
      unawaited(stopAndTranscribe(limitReached: true));
    });
    _liveEventSubscription = _service.liveEventStream(session: _session).listen(_onLiveEvent);
    unawaited(_service.prewarm(session: _session));
  }

  Stream<double> get amplitudeStream => _service.amplitudeStream(session: _session);

  Future<void> startRecording() async {
    if (state is! VoiceInputIdle) return;
    emit(const VoiceInputState.starting());

    try {
      await _service.start(session: _session);
      if (isClosed || state is! VoiceInputStarting) return;
      final presentation = _service.livePresentation(session: _session);
      emit(
        presentation == null
            ? const VoiceInputState.recording()
            : VoiceInputState.liveRecording(words: LiveWords.none, presentation: presentation),
      );
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
    final current = state;
    if (current is VoiceInputRecording) {
      emit(VoiceInputState.transcribing(limitReached: limitReached));
    } else if (current case VoiceInputLiveRecording(:final words, :final presentation)) {
      emit(VoiceInputState.liveFinishing(words: words, presentation: presentation));
    } else {
      return;
    }

    try {
      final result = await _service.stopAndTranscribe(session: _session);
      if (isClosed || !_isFinishing) return;
      emit(
        VoiceInputState.completed(
          transcript: result.transcript,
          outcome: limitReached && result.outcome == VoiceDictationOutcome.finished
              ? VoiceDictationOutcome.limitReached
              : result.outcome,
          mode: result.mode,
        ),
      );
    } on TranscriptionCancelledError {
      if (isClosed || !_isFinishing) return;
      emit(const VoiceInputState.idle());
    } on VoiceTranscriptionError catch (error, stackTrace) {
      _logTranscriptionFailure(error: error, stackTrace: stackTrace);
      if (isClosed || !_isFinishing) return;
      // Live keeps no recording, so there is nothing to retry (D20).
      if (state is VoiceInputLiveFinishing) {
        emit(VoiceInputState.transcriptionFailed(error: error));
      } else {
        _emitTranscriptionFailure(error: error);
      }
    } catch (error, stackTrace) {
      loge("Transcription failed", error, stackTrace);
      if (isClosed || !_isFinishing) return;
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
      emit(
        VoiceInputState.completed(
          transcript: transcript,
          outcome: VoiceDictationOutcome.finished,
          mode: VoiceDictationMode.afterRecording,
        ),
      );
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
      VoiceInputLiveRecording() ||
      VoiceInputTranscribing() ||
      VoiceInputLiveFinishing() ||
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

  bool get _isFinishing => state is VoiceInputTranscribing || state is VoiceInputLiveFinishing;

  // ignore: no_slop_linter/prefer_required_named_parameters, stream callback signature is positional
  void _onLiveEvent(VoiceLiveEvent event) {
    final current = state;
    switch (event) {
      case VoiceLiveWordsChanged(:final words):
        if (current case VoiceInputLiveRecording(:final presentation)) {
          emit(VoiceInputState.liveRecording(words: words, presentation: presentation));
        } else if (current case VoiceInputLiveFinishing(:final presentation)) {
          emit(VoiceInputState.liveFinishing(words: words, presentation: presentation));
        }
      case VoiceLiveFellBack():
        if (current is VoiceInputLiveRecording) {
          emit(const VoiceInputState.recording());
        } else if (current is VoiceInputLiveFinishing) {
          emit(const VoiceInputState.transcribing(limitReached: false));
        }
      case VoiceLiveEnded(:final transcript, :final outcome):
        if (current is VoiceInputLiveRecording) {
          emit(VoiceInputState.completed(transcript: transcript, outcome: outcome, mode: VoiceDictationMode.live));
        }
      case VoiceLiveFailed(:final error):
        if (current is VoiceInputLiveRecording || current is VoiceInputLiveFinishing) {
          _logTranscriptionFailure(error: error, stackTrace: StackTrace.current);
          emit(VoiceInputState.transcriptionFailed(error: error));
        }
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
    await _liveEventSubscription.cancel();
    await _service.close(session: _session);
    return await super.close();
  }
}
