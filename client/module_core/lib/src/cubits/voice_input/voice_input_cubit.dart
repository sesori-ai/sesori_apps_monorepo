import "dart:async";

import "package:bloc/bloc.dart";

import "../../logging/logging.dart";
import "../../services/voice_transcription_service.dart";
import "voice_input_state.dart";

class VoiceInputCubit({required final VoiceTranscriptionService _service}) extends Cubit<VoiceInputState> {
  late final VoiceTranscriptionSession _session = _service.createSession();
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
      if (error is! NotAuthenticatedVoiceError && error is! NetworkVoiceError) {
        loge("Transcription failed", error, stackTrace);
      }
      if (isClosed || state is! VoiceInputTranscribing) return;
      emit(VoiceInputState.transcriptionFailed(error: error));
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

  Future<void> cancel() async {
    if (state is VoiceInputIdle || state is VoiceInputCancelling) return;
    emit(const VoiceInputState.cancelling());
    try {
      await _service.cancel(session: _session);
    } catch (error, stackTrace) {
      loge("Failed to cancel the voice interaction", error, stackTrace);
    }
    if (!isClosed && state is VoiceInputCancelling) emit(const VoiceInputState.idle());
  }

  void acknowledgeOutcome() {
    if (state is VoiceInputCompleted || state is VoiceInputStartFailed || state is VoiceInputTranscriptionFailed) {
      emit(const VoiceInputState.idle());
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
