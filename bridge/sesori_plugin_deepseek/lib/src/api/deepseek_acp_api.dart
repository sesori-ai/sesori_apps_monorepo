import "package:acp_plugin/acp_plugin.dart" show AcpStdioClient;

import "models/deepseek_protocol_dto.dart";

class const DeepSeekAcpApi({required final String pluginId}) {
  static const String catalogMethod = "deepseek/catalog";
  static const String historyMethod = "deepseek/session/history";
  static const String renameMethod = "deepseek/session/rename";
  static const String askUserQuestionMethod = "deepseek/ask_user_question";
  static const String sessionStatusMethod = "deepseek/session/status";
  static const String subagentMethod = "deepseek/subagent";
  static const String initializeMetadataKey = deepSeekExtensionMetadataKey;
  static const int extensionProtocolVersion = 2;

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
  DeepSeekInitializeMetadataDto parseInitializeMetadata(Map<String, dynamic> json) {
    final metadata = DeepSeekInitializeMetadataDto.fromJson(json);
    if (metadata.extensionProtocolVersion != extensionProtocolVersion ||
        metadata.persistenceOwner != "sesori" ||
        !_nonblank(metadata.adapterVersion, maxLength: 64) ||
        !_nonblank(metadata.harnessVersion, maxLength: 64)) {
      throw const FormatException("Invalid DeepSeek initialize metadata");
    }
    return metadata;
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
  DeepSeekPromptMetadataDto parsePromptMetadata(Map<String, dynamic> json) {
    final metadata = DeepSeekPromptMetadataDto.fromJson(json);
    if (metadata.messageId case final messageId? when !_nonblank(messageId, maxLength: 256)) {
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
    return parseCatalogResponse(_json(raw, method: catalogMethod));
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
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
    if (!_nonblank(sessionId, maxLength: 256) ||
        beforeSeq != null && beforeSeq < 1 ||
        maxMessages < 1 ||
        maxMessages > 100) {
      throw const FormatException("Invalid DeepSeek history request");
    }
    final raw = await client.request(
      method: historyMethod,
      params: {"sessionId": sessionId, "beforeSeq": ?beforeSeq, "maxMessages": maxMessages},
      timeout: timeout,
    );
    return parseHistoryResponse(_json(raw, method: historyMethod), sessionId: sessionId);
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
  DeepSeekHistoryResponseDto parseHistoryResponse(Map<String, dynamic> json, {required String? sessionId}) {
    final response = DeepSeekHistoryResponseDto.fromJson(json);
    _validateHistoryResponse(response, sessionId: sessionId);
    return response;
  }

  Future<DeepSeekRenameResponseDto> rename({
    required AcpStdioClient client,
    required String sessionId,
    required String title,
    required Duration timeout,
  }) async {
    if (!_nonblank(sessionId, maxLength: 256) || !_nonblank(title, maxLength: 256)) {
      throw const FormatException("Invalid DeepSeek rename request");
    }
    final raw = await client.request(
      method: renameMethod,
      params: {"sessionId": sessionId, "title": title},
      timeout: timeout,
    );
    final response = DeepSeekRenameResponseDto.fromJson(_json(raw, method: renameMethod));
    if (!_nonblank(response.title, maxLength: 256)) {
      throw const FormatException("Invalid DeepSeek rename response");
    }
    return response;
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
  DeepSeekAskUserQuestionRequestDto parseQuestionRequest(Map<String, dynamic> json) {
    final request = DeepSeekAskUserQuestionRequestDto.fromJson(json);
    if (!_nonblank(request.sessionId, maxLength: 256) ||
        request.questions.isEmpty ||
        request.questions.length > 32 ||
        request.questions.map((question) => question.id).toSet().length != request.questions.length) {
      throw const FormatException("Invalid DeepSeek question request");
    }
    for (final question in request.questions) {
      if (!_nonblank(question.id, maxLength: 256) ||
          !_nonblank(question.text, maxLength: 2048) ||
          !_optionalNonblank(question.header, maxLength: 128) ||
          !_optionalNonblank(question.detail, maxLength: 4096) ||
          !_validQuestionOptions(question) ||
          !_validApproveLabel(question)) {
        throw const FormatException("Invalid DeepSeek question request");
      }
    }
    return request;
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
  DeepSeekAskUserQuestionResponseDto parseQuestionResponse(Map<String, dynamic> json) {
    final response = DeepSeekAskUserQuestionResponseDto.fromJson(json);
    if (response.answers.isEmpty || response.answers.length > 32) {
      throw const FormatException("Invalid DeepSeek question response");
    }
    for (final answer in response.answers) {
      if (!_nonblank(answer.questionId, maxLength: 256) ||
          answer.selectedLabels.length > 32 ||
          answer.selectedLabels.toSet().length != answer.selectedLabels.length ||
          !answer.selectedLabels.every((label) => _nonblank(label, maxLength: 256)) ||
          !_optionalNonblank(answer.customAnswer, maxLength: 2048) ||
          answer.selectedLabels.isEmpty && answer.customAnswer == null) {
        throw const FormatException("Invalid DeepSeek question answer");
      }
    }
    return response;
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
  DeepSeekSessionStatusNotificationDto parseSessionStatus(Map<String, dynamic> json) {
    final status = DeepSeekSessionStatusNotificationDto.fromJson(json);
    if (!_nonblank(status.sessionId, maxLength: 256) || !_validStatus(status)) {
      throw const FormatException("Invalid DeepSeek session status");
    }
    return status;
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
  DeepSeekSubagentNotificationDto parseSubagentNotification(Map<String, dynamic> json) {
    final notification = DeepSeekSubagentNotificationDto.fromJson(json);
    if (!_validSubagentText(notification.sessionId, maxScalars: 256) ||
        !_validSubagentText(notification.childSessionId, maxScalars: 256)) {
      throw const FormatException("Invalid DeepSeek sub-agent notification");
    }
    switch (notification) {
      case DeepSeekSubagentStartedDto(:final toolCallId, :final prompt, :final label, :final mode):
        if (!_validSubagentText(toolCallId, maxScalars: 256) ||
            !_validSubagentText(label, maxScalars: 256) ||
            !_validSubagentPrompt(prompt) ||
            mode == DeepSeekSubagentMode.unknown) {
          throw const FormatException("Invalid DeepSeek sub-agent notification");
        }
      case DeepSeekSubagentEndedDto(:final stopReason, :final summary):
        if (stopReason == DeepSeekSubagentStopReason.unknown || !_validSubagentSummary(summary)) {
          throw const FormatException("Invalid DeepSeek sub-agent notification");
        }
    }
    return notification;
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP JSON object values are heterogeneous
  DeepSeekSubagentReplayDto parseSubagentReplay(Map<String, dynamic> json) {
    final replay = DeepSeekSubagentReplayDto.fromJson(json);
    _validateSubagentReplay(replay);
    return replay;
  }

  void _validateSubagentReplay(DeepSeekSubagentReplayDto replay) {
    if (!_validSubagentText(replay.label, maxScalars: 256) ||
        !_validSubagentPrompt(replay.prompt) ||
        replay.mode == DeepSeekSubagentMode.unknown ||
        !_validOptionalSubagentText(replay.childSessionId, maxScalars: 256) ||
        !_validSubagentReplayEnd(replay.ended)) {
      throw const FormatException("Invalid DeepSeek sub-agent replay metadata");
    }
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP response and JSON object values are heterogeneous
  static Map<String, dynamic> _json(Object? raw, {required String method}) {
    if (raw is! Map) throw FormatException("$method returned a non-object result");
    // ignore: no_slop_linter/prefer_specific_type, JSON object values are heterogeneous
    return raw.cast<String, dynamic>();
  }

  void _validateHistoryResponse(DeepSeekHistoryResponseDto response, {required String? sessionId}) {
    if (response.updates.length > 10000 ||
        response.updates.any(
          (update) =>
              !_nonblank(update.sessionId, maxLength: 256) || sessionId != null && update.sessionId != sessionId,
        )) {
      throw const FormatException("Invalid DeepSeek history response");
    }
    if (response case DeepSeekPaginatedHistoryResponseDto(nextBeforeSeq: final cursor) when cursor < 1) {
      throw const FormatException("Invalid DeepSeek history response");
    }
    for (final update in response.updates) {
      final deepSeek = update.metadata?.deepSeek;
      final createdAt = deepSeek?.messageCreatedAt;
      if (createdAt != null && (createdAt < 0 || createdAt > 9007199254740991)) {
        throw const FormatException("Invalid DeepSeek history response");
      }
      final subagent = deepSeek?.subagent;
      if (subagent != null) _validateSubagentReplay(subagent);
    }
  }

  static bool _validSubagentReplayEnd(DeepSeekSubagentReplayEndedDto? ended) =>
      ended == null || ended.stopReason != DeepSeekSubagentStopReason.unknown && _validSubagentSummary(ended.summary);

  static bool _validSubagentSummary(String? value) => _validOptionalSubagentText(value, maxScalars: 512);

  static bool _validSubagentPrompt(String value) =>
      value == value.trim() && _validSubagentText(value, maxScalars: 32768);

  static bool _validOptionalSubagentText(String? value, {required int maxScalars}) =>
      value == null || _validSubagentText(value, maxScalars: maxScalars);

  static bool _validSubagentText(String value, {required int maxScalars}) {
    if (value.isEmpty || !value.contains(RegExp(r"\S"))) return false;
    var scalars = 0;
    final units = value.codeUnits;
    for (var index = 0; index < units.length; index++) {
      final unit = units[index];
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (index + 1 >= units.length) return false;
        final next = units[++index];
        if (next < 0xDC00 || next > 0xDFFF) return false;
      } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
        return false;
      }
      scalars++;
      if (scalars > maxScalars) return false;
    }
    return true;
  }

  static bool _optionalNonblank(String? value, {required int maxLength}) =>
      value == null || _nonblank(value, maxLength: maxLength);

  static bool _validQuestionOptions(DeepSeekQuestionDto question) => switch (question) {
    DeepSeekPlanReviewQuestionDto(:final options) => _validOptions(options),
    DeepSeekOrdinaryQuestionDto(:final options) => options == null || _validOptions(options),
  };

  static bool _validOptions(List<String> options) =>
      options.isNotEmpty &&
      options.length <= 32 &&
      options.toSet().length == options.length &&
      options.every((option) => _nonblank(option, maxLength: 256));

  static bool _validApproveLabel(DeepSeekQuestionDto question) => switch (question) {
    DeepSeekPlanReviewQuestionDto(approveLabel: final label, :final options) =>
      _nonblank(label, maxLength: 256) && options.contains(label),
    DeepSeekOrdinaryQuestionDto() => true,
  };

  static bool _validStatus(DeepSeekSessionStatusNotificationDto status) => switch (status) {
    DeepSeekRetryStatusDto(:final attempt, :final limit) =>
      attempt >= 1 && attempt <= 100 && (limit == null || limit >= 1 && limit <= 100),
    DeepSeekWarningStatusDto(:final message) => _nonblank(message, maxLength: 512),
    DeepSeekCompactionStartedStatusDto() || DeepSeekCompactionCompletedStatusDto() => true,
  };

  void _validateCatalog(DeepSeekCatalogResponseDto response) {
    if (response.defaultSelectionId case final id? when !_validSelectionId(id)) {
      throw const FormatException("Invalid DeepSeek catalog selection");
    }
    if (response.agent.id != pluginId || !response.agent.primary || !_nonblank(response.agent.name, maxLength: 256)) {
      throw const FormatException("Invalid DeepSeek catalog agent");
    }
    if (response.providers.length > 64 || response.commands.length > 128 || response.failures.length > 64) {
      throw const FormatException("Invalid DeepSeek catalog collections");
    }
    for (final provider in response.providers) {
      if (!_nonblank(provider.id, maxLength: 256) ||
          !_nonblank(provider.name, maxLength: 256) ||
          provider.models.length > 256) {
        throw const FormatException("Invalid DeepSeek catalog provider");
      }
      for (final model in provider.models) {
        if (!_validSelectionId(model.id) ||
            !_nonblank(model.upstreamModelId, maxLength: 256) ||
            !_nonblank(model.name, maxLength: 256) ||
            model.reasoningEfforts.length > 16 ||
            model.reasoningEfforts.toSet().length != model.reasoningEfforts.length ||
            !model.reasoningEfforts.every((effort) => _nonblank(effort, maxLength: 64)) ||
            model.defaultReasoningEffort != null && !model.reasoningEfforts.contains(model.defaultReasoningEffort)) {
          throw const FormatException("Invalid DeepSeek catalog model");
        }
      }
    }
    for (final command in response.commands) {
      if (command.name.isEmpty ||
          command.name.length > 128 ||
          !RegExp(r"^[A-Za-z0-9_-]+$").hasMatch(command.name) ||
          !_nonblank(command.description, maxLength: 256)) {
        throw const FormatException("Invalid DeepSeek catalog command");
      }
    }
    for (final failure in response.failures) {
      if (!_nonblank(failure.providerId, maxLength: 256) ||
          !_nonblank(failure.category, maxLength: 256) ||
          !_nonblank(failure.message, maxLength: 512)) {
        throw const FormatException("Invalid DeepSeek catalog failure");
      }
    }
  }

  static bool _validSelectionId(String id) =>
      id.length <= 512 &&
      RegExp(r"^v1(?:[A-Za-z0-9_-]{2,3}|(?:[A-Za-z0-9_-]{4})+(?:[A-Za-z0-9_-]{2,3})?)$").hasMatch(id);

  static bool _nonblank(String value, {required int maxLength}) =>
      value.isNotEmpty && value.length <= maxLength && value.contains(RegExp(r"\S"));

  static bool _absolutePath(String value) =>
      value.isNotEmpty &&
      value.length <= 4096 &&
      (value.startsWith("/") || RegExp(r"^[A-Za-z]:[\\/]").hasMatch(value) || value.startsWith(r"\\"));
}
