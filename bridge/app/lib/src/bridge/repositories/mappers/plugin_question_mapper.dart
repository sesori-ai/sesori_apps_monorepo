import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginPendingQuestionMapping on PluginPendingQuestion {
  /// Maps to the shared [PendingQuestion] wire model for the mobile client.
  PendingQuestion toSharedPendingQuestion() => PendingQuestion(
    id: id,
    sessionID: sessionID,
    displaySessionId: displaySessionId,
    questions: questions
        .map(
          (qi) => QuestionInfo(
            question: qi.question,
            header: qi.header,
            options: qi.options
                .map((o) => QuestionOption(label: o.label, description: o.description))
                .toList(),
            multiple: qi.multiple,
            custom: qi.custom,
          ),
        )
        .toList(),
  );
}
