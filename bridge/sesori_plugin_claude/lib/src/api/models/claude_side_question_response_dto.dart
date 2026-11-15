import "package:freezed_annotation/freezed_annotation.dart";

part "claude_side_question_response_dto.freezed.dart";
part "claude_side_question_response_dto.g.dart";

/// One earlier side question and its answer, in the `history` shape of the
/// `side_question` control request.
typedef ClaudeSideQuestionHistoryEntry = ({String question, String response});

/// The success payload of a `side_question` control request (verified on CLI
/// 2.1.322). [synthetic] marks a stand-in the CLI wrote because the model gave
/// no usable text; [response] is null when there was nothing to answer.
@Freezed(copyWith: false, fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeSideQuestionResponseDto with _$ClaudeSideQuestionResponseDto {
  const factory({
    required String? response,
    required bool synthetic,
    @JsonKey(name: "refusal_fallback") required ClaudeSideQuestionRefusalFallbackDto? refusalFallback,
  }) = _ClaudeSideQuestionResponseDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeSideQuestionResponseDtoFromJson(json);
}

/// Present when a fallback model answered after the selected model refused.
/// Only the user-facing notice is kept.
@Freezed(copyWith: false, fromJson: true, toJson: false, toStringOverride: false)
sealed class ClaudeSideQuestionRefusalFallbackDto with _$ClaudeSideQuestionRefusalFallbackDto {
  const factory({required String? content}) = _ClaudeSideQuestionRefusalFallbackDto;

  factory fromJson(Map<String, dynamic> json) => _$ClaudeSideQuestionRefusalFallbackDtoFromJson(json);
}
