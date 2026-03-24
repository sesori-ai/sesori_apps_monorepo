import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps a list of [PluginPendingQuestion]s to their shared [PendingQuestion]
/// counterparts.
///
/// Used by both [GetSessionQuestionsHandler] and [GetProjectQuestionsHandler].
List<PendingQuestion> mapPluginQuestions(List<PluginPendingQuestion> pluginQuestions) {
  return pluginQuestions
      .map(
        (q) => PendingQuestion(
          id: q.id,
          sessionID: q.sessionID,
          questions: q.questions
              .map(
                (qi) => QuestionInfo(
                  question: qi.question,
                  header: qi.header,
                  options: qi.options
                      .map(
                        (o) => QuestionOption(
                          label: o.label,
                          description: o.description,
                        ),
                      )
                      .toList(),
                  multiple: qi.multiple,
                  custom: qi.custom,
                ),
              )
              .toList(),
        ),
      )
      .toList();
}
