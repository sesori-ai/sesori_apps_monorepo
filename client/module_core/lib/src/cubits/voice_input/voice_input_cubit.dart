import "dart:async";

import "package:bloc/bloc.dart";

import "../../logging/logging.dart";
import "../../services/voice_transcription_service.dart";
import "voice_input_state.dart";

class VoiceInputCubit({required final VoiceTranscriptionService _service}) extends Cubit<VoiceInputState> {
  late final VoiceTranscriptionSession _session = _service.createSession();
  late final StreamSubscription<void> _maxDurationSubscription;
  late final StreamSubscription<VoiceRealtimeTerminalCause> _realtimeTerminalSubscription;
  late final StreamSubscription<VoiceTranscriptionPreview> _previewSubscription;
  bool _limitReachedDuringStart = false;
  VoiceRealtimeTerminalCause? _realtimeTerminalDuringStart;
  _VoiceStopOperation? _activeStopOperation;

  this : super(const VoiceInputState.idle()) {
    _maxDurationSubscription = _service.maxDurationReachedStream(session: _session).listen((_) {
      if (state is VoiceInputRecording) {
        unawaited(stopAndTranscribe(limitReached: true));
      } else if (state is VoiceInputStarting) {
        _limitReachedDuringStart = true;
      }
    });
    _realtimeTerminalSubscription = _service
        .realtimeTerminalStream(session: _session)
        .listen(
          _handleRealtimeTerminal,
        );
    _previewSubscription = _service.previewStream(session: _session).listen(_handlePreview);
    unawaited(_service.prewarm(session: _session));
  }

  Stream<double> get amplitudeStream => _service.amplitudeStream(session: _session);

  Future<void> startRecording({required String projectId}) async {
    if (state is! VoiceInputIdle) return;
    _limitReachedDuringStart = false;
    _realtimeTerminalDuringStart = null;
    emit(const VoiceInputState.starting());

    try {
      await _service.start(session: _session, projectId: projectId);
      if (isClosed || state is! VoiceInputStarting) return;
      emit(VoiceInputState.recording(preview: _service.currentPreview(session: _session)));
      final terminalCause = _realtimeTerminalDuringStart;
      if (_limitReachedDuringStart || terminalCause != null) {
        final limitReached = _limitReachedDuringStart || terminalCause == VoiceRealtimeTerminalCause.limitReached;
        _limitReachedDuringStart = false;
        _realtimeTerminalDuringStart = null;
        unawaited(stopAndTranscribe(limitReached: limitReached));
      }
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
    final operation = _VoiceStopOperation();
    _activeStopOperation = operation;
    emit(
      VoiceInputState.transcribing(
        limitReached: limitReached,
        preview: _service.currentPreview(session: _session),
      ),
    );

    try {
      final transcript = await _service.stopAndTranscribe(session: _session);
      if (!_ownsStopOperation(operation) || state is! VoiceInputTranscribing) return;
      emit(VoiceInputState.completed(transcript: transcript));
    } on TranscriptionCancelledError {
      if (!_ownsStopOperation(operation) || state is! VoiceInputTranscribing) return;
      emit(const VoiceInputState.idle());
    } on VoiceRealtimePartialTranscriptionError catch (error, stackTrace) {
      _logTranscriptionFailure(error: error.failure, stackTrace: stackTrace);
      if (!_ownsStopOperation(operation) || state is! VoiceInputTranscribing) return;
      emit(
        VoiceInputState.realtimePartialFailed(
          confirmedText: error.confirmedText,
          error: error.failure,
        ),
      );
    } on VoiceTranscriptionError catch (error, stackTrace) {
      _logTranscriptionFailure(error: error, stackTrace: stackTrace);
      if (!_ownsStopOperation(operation) || state is! VoiceInputTranscribing) return;
      _emitTranscriptionFailure(error: error);
    } catch (error, stackTrace) {
      loge("Transcription failed", error, stackTrace);
      if (!_ownsStopOperation(operation) || state is! VoiceInputTranscribing) return;
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

    _activeStopOperation = null;
    final retryError = switch (current) {
      VoiceInputRetrying(:final previousError) => previousError,
      VoiceInputStarting() ||
      VoiceInputRecording() ||
      VoiceInputTranscribing() ||
      VoiceInputCompleted() ||
      VoiceInputStartFailed() ||
      VoiceInputTranscriptionFailed() ||
      VoiceInputRealtimePartialFailed() => null,
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

  Future<void> composerIdentityChanged() async {
    if (state is VoiceInputRetryPending || state is VoiceInputRetrying) {
      await discard();
    } else {
      await cancel();
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
    if (state is VoiceInputCompleted ||
        state is VoiceInputStartFailed ||
        state is VoiceInputTranscriptionFailed ||
        state is VoiceInputRealtimePartialFailed) {
      emit(const VoiceInputState.idle());
    }
  }

  bool _ownsStopOperation(_VoiceStopOperation operation) => !isClosed && identical(_activeStopOperation, operation);

  void _emitTranscriptionFailure({required VoiceTranscriptionError error}) {
    if (error is NetworkVoiceError || error is RetryableServerVoiceError) {
      emit(VoiceInputState.retryPending(error: error));
    } else {
      emit(VoiceInputState.transcriptionFailed(error: error));
    }
  }

  void _handleRealtimeTerminal(VoiceRealtimeTerminalCause cause) {
    if (isClosed) return;
    if (state is VoiceInputRecording) {
      unawaited(stopAndTranscribe(limitReached: cause == VoiceRealtimeTerminalCause.limitReached));
    } else if (state is VoiceInputStarting) {
      _realtimeTerminalDuringStart = cause;
    }
  }

  void _handlePreview(VoiceTranscriptionPreview preview) {
    if (isClosed) return;
    switch (state) {
      case VoiceInputRecording():
        emit(VoiceInputState.recording(preview: preview));
      case VoiceInputTranscribing(:final limitReached):
        emit(VoiceInputState.transcribing(limitReached: limitReached, preview: preview));
      case VoiceInputIdle() ||
          VoiceInputStarting() ||
          VoiceInputRetryPending() ||
          VoiceInputRetrying() ||
          VoiceInputRetryCancelling() ||
          VoiceInputDiscarding() ||
          VoiceInputCompleted() ||
          VoiceInputStartFailed() ||
          VoiceInputTranscriptionFailed() ||
          VoiceInputRealtimePartialFailed() ||
          VoiceInputCancelling():
        return;
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
    _activeStopOperation = null;
    _service.invalidate(session: _session);
    await _maxDurationSubscription.cancel();
    await _realtimeTerminalSubscription.cancel();
    await _previewSubscription.cancel();
    await _service.close(session: _session);
    return await super.close();
  }
}

final class _VoiceStopOperation();
