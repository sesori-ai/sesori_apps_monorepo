import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/deepseek_acp_api.dart";
import "api/models/deepseek_protocol_dto.dart";

class DeepSeekApprovalRegistry({
  required AcpStdioClient client,
  required super.emit,
  required super.onFireAndForgetNotification,
  required final DeepSeekAcpApi api,
  super.idGenerator,
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
      final bridgeId = generateBridgeId();
      addPendingQuestion(
        bridgeRequestId: bridgeId,
        acpId: request.id,
        sessionId: parsed.sessionId,
        questions: questions,
        replyBuilder: (answers) => DeepSeekAskUserQuestionResponseDto(
          answers: [
            for (var index = 0; index < parsed.questions.length; index++)
              if (parsed.questions[index].options == null)
                DeepSeekQuestionAnswerDto.custom(
                  questionId: parsed.questions[index].id,
                  customAnswer: answers[index].first,
                )
              else
                DeepSeekQuestionAnswerDto.selected(
                  questionId: parsed.questions[index].id,
                  selectedLabels: answers[index],
                ),
          ],
        ).toJson(),
        resolutionBuilder: null,
      );
      emit(
        BridgeSseQuestionAsked(
          id: bridgeId,
          sessionID: parsed.sessionId,
          displaySessionId: parsed.sessionId,
          questions: questions,
        ),
      );
    } on Object {
      respondError(request.id, -32602, "Invalid DeepSeek question request");
    }
    return true;
  }

  static PluginQuestionInfo _mapQuestion(DeepSeekQuestionDto question) => PluginQuestionInfo(
    question: question.text,
    header: question.header ?? "Question",
    options: [
      for (final label in question.options ?? const <String>[])
        PluginQuestionOption(label: label, description: question.detail ?? ""),
    ],
    multiple: question.multiSelect ?? false,
    custom: question.options == null,
  );
}
