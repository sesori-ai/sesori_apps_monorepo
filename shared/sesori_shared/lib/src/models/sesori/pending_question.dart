import "package:freezed_annotation/freezed_annotation.dart";

import "question.dart";

part "pending_question.freezed.dart";

part "pending_question.g.dart";

/// Response body for `POST /session/questions`.
@Freezed(fromJson: true, toJson: true)
sealed class PendingQuestionResponse with _$PendingQuestionResponse {
  const factory PendingQuestionResponse({
    required List<PendingQuestion> data,
  }) = _PendingQuestionResponse;

  factory PendingQuestionResponse.fromJson(Map<String, dynamic> json) => _$PendingQuestionResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PendingQuestion with _$PendingQuestion {
  const factory PendingQuestion({
    required String id,
    required String sessionID,
    required List<QuestionInfo> questions,
  }) = _PendingQuestion;

  factory PendingQuestion.fromJson(Map<String, dynamic> json) => _$PendingQuestionFromJson(json);
}
