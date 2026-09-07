import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/codex_user_input_dto.dart";

/// Both Codex question forms use the same backend-neutral question contract.
class const CodexQuestionMapper() {
  List<PluginQuestionInfo> mapUserInput({required CodexUserInputParamsDto request}) => [
    for (final item in request.questions)
      PluginQuestionInfo(
        question: item.question,
        header: item.header,
        options: [
          for (final option in item.options ?? const <CodexUserInputOptionDto>[])
            PluginQuestionOption(label: option.label, description: option.description),
        ],
        multiple: false,
        custom: item.isOther || (item.options?.isEmpty ?? true),
      ),
  ];

  List<PluginQuestionInfo> mapAsyncQuestions({required List<CodexAsyncUserInputQuestionDto> questions}) => [
    for (final item in questions)
      PluginQuestionInfo(
        question: item.title,
        header: "Question",
        options: [
          // Async choices supply labels only. The existing question wire
          // contract uses blank description text for label-only choices.
          for (final option in item.options ?? const <String>[]) PluginQuestionOption(label: option, description: ""),
        ],
        multiple: false,
        custom: true,
      ),
  ];

  String asyncAnswerText({required List<PluginQuestionInfo> questions, required List<List<String>> answers}) {
    final text = StringBuffer("User answers to your questions:\n");
    for (var i = 0; i < questions.length; i++) {
      text.writeln("\nQuestion: ${questions[i].question}");
      final row = i < answers.length ? answers[i] : const <String>[];
      text.writeln(row.isEmpty ? "Answer: Declined to answer." : "Answer: ${row.join('\n')}");
    }
    return text.toString().trimRight();
  }
}
