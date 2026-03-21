import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

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

extension PendingQuestionToPluginExtension on PendingQuestion {
  PluginPendingQuestion toPlugin() {
    return PluginPendingQuestion(
      id: id,
      sessionID: sessionID,
      questions: questions
          .map(
            (question) => PluginQuestionInfo(
              question: question.question,
              header: question.header,
              options: question.options
                  .map((option) => PluginQuestionOption(label: option.label, description: option.description))
                  .toList(),
              multiple: question.multiple,
              custom: question.custom,
            ),
          )
          .toList(),
    );
  }
}
