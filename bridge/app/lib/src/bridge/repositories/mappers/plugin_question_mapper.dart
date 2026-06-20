import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginPendingQuestionMapping on PluginPendingQuestion {
  /// Maps to the shared [PendingQuestion] wire model for the mobile client.
  PendingQuestion toSharedPendingQuestion() => PendingQuestion(
    id: id,
    sessionID: sessionID,
    displaySessionId: displaySessionId,
    questions: questions.map((qi) => qi.toSharedQuestionInfo()).toList(),
  );
}

extension PluginQuestionInfoMapping on PluginQuestionInfo {
  /// Maps a plugin-interface question info to the shared [QuestionInfo] wire
  /// model. Shared by the REST ([PendingQuestion]) and SSE
  /// ([SesoriQuestionAsked]) question paths.
  QuestionInfo toSharedQuestionInfo() => QuestionInfo(
    question: question,
    header: header,
    options: options.map((o) => QuestionOption(label: o.label, description: o.description)).toList(),
    multiple: multiple,
    custom: custom,
  );
}
