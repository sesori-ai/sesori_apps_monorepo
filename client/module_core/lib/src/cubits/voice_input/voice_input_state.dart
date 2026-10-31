import "package:freezed_annotation/freezed_annotation.dart";

import "../../foundation/models/voice/voice_dictation_outcome.dart";
import "../../foundation/models/voice/voice_live.dart";
import "../../foundation/models/voice/voice_transcription_error.dart";

part "voice_input_state.freezed.dart";

@Freezed()
sealed class VoiceInputState with _$VoiceInputState {
  const factory idle() = VoiceInputIdle;

  const factory starting() = VoiceInputStarting;

  const factory recording() = VoiceInputRecording;

  const factory liveRecording({required LiveWords words}) = VoiceInputLiveRecording;

  const factory transcribing({required bool limitReached}) = VoiceInputTranscribing;

  const factory liveFinishing({required LiveWords words}) = VoiceInputLiveFinishing;

  const factory retryPending({required VoiceTranscriptionError error}) = VoiceInputRetryPending;

  const factory retrying({required VoiceTranscriptionError previousError}) = VoiceInputRetrying;

  const factory retryCancelling({required VoiceTranscriptionError previousError}) = VoiceInputRetryCancelling;

  const factory discarding() = VoiceInputDiscarding;

  const factory completed({
    required String transcript,
    required VoiceDictationOutcome outcome,
    required VoiceDictationMode mode,
  }) = VoiceInputCompleted;

  const factory startFailed({required VoiceTranscriptionError error}) = VoiceInputStartFailed;

  const factory transcriptionFailed({required VoiceTranscriptionError error}) = VoiceInputTranscriptionFailed;

  const factory cancelling() = VoiceInputCancelling;
}
