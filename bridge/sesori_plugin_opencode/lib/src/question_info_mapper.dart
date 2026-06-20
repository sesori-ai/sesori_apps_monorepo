import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/openapi/question_info.g.dart";

/// Maps OpenCode's [QuestionInfo] (shared by the `question.asked` SSE payload
/// and the `GET /session/questions` REST payload) to the plugin-interface
/// [PluginQuestionInfo]. Pure transformation, reused by [PluginModelMapper] and
/// [SseEventMapper] so both question paths stay typed and identical.
class QuestionInfoMapper {
  const QuestionInfoMapper();

  List<PluginQuestionInfo> mapQuestionInfos(List<QuestionInfo> infos) =>
      infos.map(mapQuestionInfo).toList();

  PluginQuestionInfo mapQuestionInfo(QuestionInfo info) => PluginQuestionInfo(
    question: info.question,
    header: info.header,
    options: info.options
        .map((option) => PluginQuestionOption(label: option.label, description: option.description))
        .toList(),
    multiple: info.multiple ?? false,
    custom: info.custom ?? true,
  );
}
