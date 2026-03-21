import "package:freezed_annotation/freezed_annotation.dart";

import "question.dart";

part "pending_question.freezed.dart";

part "pending_question.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class PendingQuestion with _$PendingQuestion {
  const factory PendingQuestion({
    required String id,
    required String sessionID,
    required List<QuestionInfo> questions,
  }) = _PendingQuestion;

  factory PendingQuestion.fromJson(Map<String, dynamic> json) => _$PendingQuestionFromJson(json);
}
