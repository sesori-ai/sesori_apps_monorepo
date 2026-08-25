import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/deepseek_acp_api.dart";
import "api/models/deepseek_protocol_dto.dart";

class DeepSeekApprovalRegistry({
  required AcpStdioClient client,
  required super.emit,
  required final DeepSeekAcpApi api,
  super.idGenerator,
  required super.activeSessionResolver,
}) extends AcpApprovalRegistry {
  this
    : super(
        respond: (id, result) => client.respondToServerRequest(id: id, result: result),
        respondError: (id, code, message) =>
            client.respondToServerRequestWithError(id: id, code: code, message: message),
      );

  @override
  bool handleExtensionRequest(AcpServerRequest request) {
    if (request.method != DeepSeekAcpApi.askUserQuestionMethod) return false;
    try {
      final parsed = api.parseQuestionRequest(request.params);
      final questions = parsed.questions.map(_mapQuestion).toList(growable: false);
      addPendingQuestion(
        acpId: request.id,
        sessionId: parsed.sessionId,
        questions: questions,
        replyBuilder: (answers) {
          if (answers.length != parsed.questions.length || answers.any((answer) => answer.isEmpty)) {
            throw const FormatException("Invalid DeepSeek question answers");
          }
          return DeepSeekAskUserQuestionResponseDto(
            answers: [
              for (var index = 0; index < parsed.questions.length; index++)
                _answer(parsed.questions[index], answers: answers[index]),
            ],
          ).toJson();
        },
        resolutionBuilder: null,
      );
    } on Object catch (error, stack) {
      Log.w("[deepseek] invalid question request", error, stack);
      respondError(request.id, -32602, "Invalid DeepSeek question request");
    }
    return true;
  }

  static DeepSeekQuestionAnswerDto _answer(DeepSeekQuestionDto question, {required List<String> answers}) {
    if (answers.isEmpty || answers.any((answer) => answer.length > 2048 || answer.trim().isEmpty)) {
      throw const FormatException("DeepSeek question answers must be nonblank and at most 2048 characters");
    }
    if (answers.toSet().length != answers.length) {
      throw const FormatException("DeepSeek question answers must not contain duplicates");
    }
    final options = question.options;
    if (options == null) {
      if (answers.length != 1) throw const FormatException("DeepSeek custom answers must contain one value");
      return DeepSeekQuestionAnswerDto.custom(questionId: question.id, customAnswer: answers.single);
    }
    if (question.multiSelect != true && answers.length != 1) {
      throw const FormatException("DeepSeek single-select questions require one answer");
    }
    final selectedLabels = answers.where(options.contains).toList();
    final customAnswers = answers.where((answer) => !options.contains(answer)).toList();
    if (customAnswers.length > 1) {
      throw const FormatException("DeepSeek questions support at most one custom answer");
    }
    if (question is DeepSeekPlanReviewQuestionDto && customAnswers.isNotEmpty) {
      throw const FormatException("DeepSeek plan-review questions do not accept custom answers");
    }
    if (selectedLabels.isEmpty) {
      return DeepSeekQuestionAnswerDto.custom(questionId: question.id, customAnswer: customAnswers.single);
    }
    return DeepSeekQuestionAnswerDto.selected(
      questionId: question.id,
      selectedLabels: selectedLabels,
      customAnswer: customAnswers.isEmpty ? null : customAnswers.single,
    );
  }

  static PluginQuestionInfo _mapQuestion(DeepSeekQuestionDto question) => PluginQuestionInfo(
    question: question.options == null && question.detail != null
        ? "${question.text}\n\n${question.detail}"
        : question.text,
    header: question.header ?? "Question",
    options: [
      for (final label in question.options ?? const <String>[])
        PluginQuestionOption(label: label, description: question.detail ?? ""),
    ],
    multiple: question.multiSelect ?? false,
    custom: question is DeepSeekOrdinaryQuestionDto,
  );
}
