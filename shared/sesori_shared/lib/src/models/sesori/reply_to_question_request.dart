import "package:freezed_annotation/freezed_annotation.dart";

part "reply_to_question_request.freezed.dart";

part "reply_to_question_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class ReplyToQuestionRequest with _$ReplyToQuestionRequest {
  const factory({
    required String requestId, // questions request id
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) = _ReplyToQuestionRequest;

  factory fromJson(Map<String, dynamic> json) => _$ReplyToQuestionRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class RejectQuestionRequest with _$RejectQuestionRequest {
  const factory({
    required String requestId, // questions request id
    required String sessionId,
  }) = _RejectQuestionRequest;

  factory fromJson(Map<String, dynamic> json) => _$RejectQuestionRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ReplyAnswer with _$ReplyAnswer {
  /// One question's selected values. An empty list means the question was
  /// intentionally left unanswered, including when the user declines that
  /// individual question while answering the rest of the request.
  const factory({
    required List<String> values,
  }) = _ReplyAnswer;

  factory fromJson(Map<String, dynamic> json) => _$ReplyAnswerFromJson(json);
}
