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
