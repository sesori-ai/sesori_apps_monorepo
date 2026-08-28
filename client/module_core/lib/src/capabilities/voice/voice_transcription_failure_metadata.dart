import "package:freezed_annotation/freezed_annotation.dart";

part "voice_transcription_failure_metadata.freezed.dart";
part "voice_transcription_failure_metadata.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class VoiceTranscriptionFailureMetadata with _$VoiceTranscriptionFailureMetadata {
  const factory({required bool? retryable}) = _VoiceTranscriptionFailureMetadata;

  factory fromJson(Map<String, dynamic> json) => _$VoiceTranscriptionFailureMetadataFromJson(json);
}
