import "package:freezed_annotation/freezed_annotation.dart";

part "reply_to_question_request.freezed.dart";

part "reply_to_question_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class ReplyToQuestionRequest with _$ReplyToQuestionRequest {
  const factory ReplyToQuestionRequest({
    required String requestId, // questions request id
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) = _ReplyToQuestionRequest;

  factory ReplyToQuestionRequest.fromJson(Map<String, dynamic> json) => _$ReplyToQuestionRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class RejectQuestionRequest with _$RejectQuestionRequest {
  const factory RejectQuestionRequest({
    required String requestId, // questions request id
    // `required` so callers cannot forget to supply it, but nullable on the
    // wire: older clients that omit it deserialize to null, and the bridge
    // falls back to resolving the owning session from the question id.
    // COMPATIBILITY 2026-06-17 (v1.1.0): Old clients omit sessionId on rejection. Make it non-null and remove bridge null handling once those clients are unsupported.
    required String? sessionId,
  }) = _RejectQuestionRequest;

  factory RejectQuestionRequest.fromJson(Map<String, dynamic> json) => _$RejectQuestionRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ReplyAnswer with _$ReplyAnswer {
  const factory ReplyAnswer({
    required List<String> values,
  }) = _ReplyAnswer;

  factory ReplyAnswer.fromJson(Map<String, dynamic> json) => _$ReplyAnswerFromJson(json);
}
