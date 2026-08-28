import "package:freezed_annotation/freezed_annotation.dart";

import "../../services/voice_transcription_service.dart";

part "voice_input_state.freezed.dart";

@Freezed()
sealed class VoiceInputState with _$VoiceInputState {
  const factory idle() = VoiceInputIdle;

  const factory starting() = VoiceInputStarting;

  const factory recording({required VoiceTranscriptionPreview preview}) = VoiceInputRecording;

  const factory transcribing({
    required bool limitReached,
    required VoiceTranscriptionPreview preview,
  }) = VoiceInputTranscribing;

  const factory retryPending({required VoiceTranscriptionError error}) = VoiceInputRetryPending;

  const factory retrying({required VoiceTranscriptionError previousError}) = VoiceInputRetrying;

  const factory retryCancelling({required VoiceTranscriptionError previousError}) = VoiceInputRetryCancelling;

  const factory discarding() = VoiceInputDiscarding;

  const factory completed({required String transcript}) = VoiceInputCompleted;

  const factory startFailed({required VoiceTranscriptionError error}) = VoiceInputStartFailed;

  const factory transcriptionFailed({required VoiceTranscriptionError error}) = VoiceInputTranscriptionFailed;

  const factory realtimePartialFailed({
    required String confirmedText,
    required VoiceTranscriptionError error,
  }) = VoiceInputRealtimePartialFailed;

  const factory cancelling() = VoiceInputCancelling;
}
