import "package:acp_plugin/acp_plugin.dart" show AcpStdioClient;

import "models/deepseek_protocol_dto.dart";

class const DeepSeekAcpApi() {
  static const String catalogMethod = "deepseek/catalog";
  static const String historyMethod = "deepseek/session/history";
  static const String renameMethod = "deepseek/session/rename";
  static const String askUserQuestionMethod = "deepseek/ask_user_question";
  static const String sessionStatusMethod = "deepseek/session/status";
  static const String initializeMetadataKey = "sesori.ai/deepseek";
  static const int extensionProtocolVersion = 1;

  DeepSeekInitializeMetadataDto parseInitializeMetadata(Map<String, dynamic> json) {
    final metadata = DeepSeekInitializeMetadataDto.fromJson(json);
    if (metadata.extensionProtocolVersion != extensionProtocolVersion ||
        metadata.persistenceOwner != "sesori" ||
        !_nonblank(metadata.adapterVersion, 64) ||
        !_nonblank(metadata.harnessVersion, 64)) {
      throw const FormatException("Invalid DeepSeek initialize metadata");
    }
    return metadata;
  }

  DeepSeekPromptMetadataDto parsePromptMetadata(Map<String, dynamic> json) {
    final metadata = DeepSeekPromptMetadataDto.fromJson(json);
    if (metadata.messageId case final messageId? when !_nonblank(messageId, 256)) {
      throw const FormatException("Invalid DeepSeek prompt metadata");
    }
    return metadata;
  }

  Future<DeepSeekCatalogResponseDto> catalog({
    required AcpStdioClient client,
    required String cwd,
    required Duration timeout,
  }) async {
    if (!_absolutePath(cwd)) throw const FormatException("DeepSeek catalog cwd must be absolute");
    final raw = await client.request(method: catalogMethod, params: {"cwd": cwd}, timeout: timeout);
    return parseCatalogResponse(_json(raw, catalogMethod));
  }

  DeepSeekCatalogResponseDto parseCatalogResponse(Map<String, dynamic> json) {
    final response = DeepSeekCatalogResponseDto.fromJson(json);
    _validateCatalog(response);
    return response;
  }

  Future<DeepSeekHistoryResponseDto> history({
    required AcpStdioClient client,
    required String sessionId,
    required int? beforeSeq,
    required int maxMessages,
    required Duration timeout,
  }) async {
    if (!_nonblank(sessionId, 256) || beforeSeq != null && beforeSeq < 1 || maxMessages < 1 || maxMessages > 100) {
      throw const FormatException("Invalid DeepSeek history request");
    }
    final raw = await client.request(
      method: historyMethod,
      params: {"sessionId": sessionId, "beforeSeq": ?beforeSeq, "maxMessages": maxMessages},
      timeout: timeout,
    );
    final response = DeepSeekHistoryResponseDto.fromJson(_json(raw, historyMethod));
    _validateHistoryResponse(response);
    return response;
  }

  Future<DeepSeekRenameResponseDto> rename({
    required AcpStdioClient client,
    required String sessionId,
    required String title,
    required Duration timeout,
  }) async {
    if (!_nonblank(sessionId, 256) || !_nonblank(title, 256)) {
      throw const FormatException("Invalid DeepSeek rename request");
    }
    final raw = await client.request(
      method: renameMethod,
      params: {"sessionId": sessionId, "title": title},
      timeout: timeout,
    );
    final response = DeepSeekRenameResponseDto.fromJson(_json(raw, renameMethod));
    if (!_nonblank(response.title, 256)) throw const FormatException("Invalid DeepSeek rename response");
    return response;
  }

  DeepSeekAskUserQuestionRequestDto parseQuestionRequest(Map<String, dynamic> json) {
    final request = DeepSeekAskUserQuestionRequestDto.fromJson(json);
    if (!_nonblank(request.sessionId, 256) || request.questions.isEmpty || request.questions.length > 32) {
      throw const FormatException("Invalid DeepSeek question request");
    }
    for (final question in request.questions) {
      if (!_nonblank(question.id, 256) ||
          !_nonblank(question.text, 2048) ||
          !_optionalNonblank(question.header, 128) ||
          !_optionalNonblank(question.detail, 4096) ||
          !_validQuestionOptions(question) ||
          !_validApproveLabel(question)) {
        throw const FormatException("Invalid DeepSeek question request");
      }
    }
    return request;
  }

  DeepSeekAskUserQuestionResponseDto parseQuestionResponse(Map<String, dynamic> json) {
    final response = DeepSeekAskUserQuestionResponseDto.fromJson(json);
    if (response.answers.isEmpty || response.answers.length > 32) {
      throw const FormatException("Invalid DeepSeek question response");
    }
    for (final answer in response.answers) {
      if (!_nonblank(answer.questionId, 256) ||
          answer.selectedLabels.length > 32 ||
          answer.selectedLabels.toSet().length != answer.selectedLabels.length ||
          !answer.selectedLabels.every((label) => _nonblank(label, 256)) ||
          !_optionalNonblank(answer.customAnswer, 2048)) {
        throw const FormatException("Invalid DeepSeek question answer");
      }
    }
    return response;
  }

  DeepSeekSessionStatusNotificationDto parseSessionStatus(Map<String, dynamic> json) {
    final status = DeepSeekSessionStatusNotificationDto.fromJson(json);
    if (!_nonblank(status.sessionId, 256) || !_validStatus(status)) {
      throw const FormatException("Invalid DeepSeek session status");
    }
    return status;
  }

  static Map<String, dynamic> _json(Object? raw, String method) {
    if (raw is! Map) throw FormatException("$method returned a non-object result");
    return raw.cast<String, dynamic>();
  }

  static void _validateHistoryResponse(DeepSeekHistoryResponseDto response) {
    if (response.updates.length > 10000) {
      throw const FormatException("Invalid DeepSeek history response");
    }
    if (response case DeepSeekPaginatedHistoryResponseDto(nextBeforeSeq: final cursor) when cursor < 1) {
      throw const FormatException("Invalid DeepSeek history response");
    }
  }

  static bool _optionalNonblank(String? value, int maxLength) => value == null || _nonblank(value, maxLength);

  static bool _validQuestionOptions(DeepSeekQuestionDto question) => switch (question) {
    DeepSeekPlanReviewQuestionDto(:final options) => _validOptions(options),
    DeepSeekOrdinaryQuestionDto(:final options) => options == null || _validOptions(options),
  };

  static bool _validOptions(List<String> options) =>
      options.isNotEmpty &&
      options.length <= 32 &&
      options.toSet().length == options.length &&
      options.every((option) => _nonblank(option, 256));

  static bool _validApproveLabel(DeepSeekQuestionDto question) => switch (question) {
    DeepSeekPlanReviewQuestionDto(approveLabel: final label, :final options) =>
      _nonblank(label, 256) && options.contains(label),
    DeepSeekOrdinaryQuestionDto() => true,
  };

  static bool _validStatus(DeepSeekSessionStatusNotificationDto status) => switch (status) {
    DeepSeekRetryStatusDto(:final attempt, :final limit) =>
      attempt >= 1 && attempt <= 100 && (limit == null || limit >= 1 && limit <= 100),
    DeepSeekWarningStatusDto(:final message) => _nonblank(message, 512),
    DeepSeekCompactionStartedStatusDto() || DeepSeekCompactionCompletedStatusDto() => true,
  };

  static void _validateCatalog(DeepSeekCatalogResponseDto response) {
    if (response.defaultSelectionId case final id?
        when !RegExp(
              r"^v1(?:[A-Za-z0-9_-]{2,3}|(?:[A-Za-z0-9_-]{4})+(?:[A-Za-z0-9_-]{2,3})?)$",
            ).hasMatch(id) ||
            id.length > 512) {
      throw const FormatException("Invalid DeepSeek catalog selection");
    }
    if (response.agent.id != "deepseek" || !response.agent.primary || !_nonblank(response.agent.name, 256)) {
      throw const FormatException("Invalid DeepSeek catalog agent");
    }
    for (final provider in response.providers) {
      if (!_nonblank(provider.id, 256) || !_nonblank(provider.name, 256)) {
        throw const FormatException("Invalid DeepSeek catalog provider");
      }
      for (final model in provider.models) {
        if (!RegExp(r"^v1[A-Za-z0-9._~-]*$").hasMatch(model.id) ||
            !_nonblank(model.upstreamModelId, 256) ||
            !_nonblank(model.name, 256)) {
          throw const FormatException("Invalid DeepSeek catalog model");
        }
      }
    }
  }

  static bool _nonblank(String value, int maxLength) =>
      value.isNotEmpty && value.length <= maxLength && value.contains(RegExp(r"\S"));

  static bool _absolutePath(String value) =>
      value.isNotEmpty &&
      value.length <= 4096 &&
      (value.startsWith("/") || RegExp(r"^[A-Za-z]:[\\/]").hasMatch(value) || value.startsWith(r"\\"));
}
