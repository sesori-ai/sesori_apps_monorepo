import "dart:convert";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show SemanticVersion, normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show decodedBase64Length, isInlineMessageAttachmentWithinSizeLimit, maxInlineMessageAttachmentBytes;

import "../api/codex_app_server_api.dart";
import "../api/models/codex_model_provider_error_dto.dart";
import "../api/models/codex_thread_dto.dart";
import "../api/models/codex_turn_dto.dart";
import "../api/models/codex_turn_input_dto.dart";
import "../codex_app_server_client.dart";
import "../models/codex_collaboration_mode.dart";
import "../models/codex_fork_refusal.dart";
import "../models/codex_rewind_refusal.dart";
import "mappers/codex_side_answer_mapper.dart";
import "models/codex_model_provider_exception.dart";
import "models/codex_resumed_thread.dart";
import "models/codex_thread_record.dart";

sealed class const CodexThreadOperationException({
  required final String operation,
  required final String message,
  required final CodexRpcException innerError,
}) implements Exception {
  @override
  String toString() => "CodexThreadOperationException($operation: $message)";
}

final class const CodexThreadNotFoundException({
  required super.operation,
  required super.message,
  required super.innerError,
}) extends CodexThreadOperationException;

final class const CodexThreadRequestException({
  required super.operation,
  required super.message,
  required super.innerError,
}) extends CodexThreadOperationException;

final class const _CodexPromptAttachmentException({required final String message, required final Object? innerError})
    implements Exception {
  @override
  String toString() => "CodexPromptAttachmentException($message)";
}

/// Layer-2 normalization and domain mapping for Codex app-server threads.
/// [codexVersion] is the connected app-server's, from `initialize`.
class CodexThreadRepository({
  required final CodexAppServerApi _appServerApi,
  required SemanticVersion? codexVersion,
}) {
  static const _sideAnswerMapper = CodexSideAnswerMapper();

  /// `thread/fork {lastTurnId}` arrived in 0.143.0; older app-servers ignore
  /// the field and fork the whole thread.
  final bool _forksThroughTurn =
      codexVersion != null && codexVersion.compareTo(SemanticVersion.parse(value: "0.143.0")) >= 0;

  static const _supportedImageMimes = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };

  Future<CodexThreadRecord> startThread({
    required String cwd,
    required String? model,
    required bool fastMode,
    required String developerInstructions,
  }) async {
    final dto = await _request(
      operation: "thread/start",
      request: () => _appServerApi.startThread(
        cwd: cwd,
        model: model,
        fastMode: fastMode,
        developerInstructions: developerInstructions,
      ),
    );
    return _mapRequired(dto: dto, operation: "thread/start");
  }

  /// The user's configured `developer_instructions`, seen from [cwd] when
  /// given, or null when none are set.
  Future<String?> readDeveloperInstructions({required String? cwd}) async {
    final config = await _request(
      operation: "config/read",
      request: () => _appServerApi.readConfig(cwd: cwd),
    );
    return _usefulText(value: config.config.developerInstructions);
  }

  /// Reads a stored or loaded thread without resuming it. Sub-agent threads
  /// never announce themselves through `thread/started`, so this is how their
  /// parentage and nickname are learned once the parent names them.
  Future<CodexThreadRecord> readThread({required String threadId}) async {
    final dto = await _request(
      operation: "thread/read",
      request: () => _appServerApi.readThread(threadId: threadId),
    );
    return _mapRequired(dto: dto, operation: "thread/read");
  }

  Future<CodexResumedThread> resumeThread({
    required String threadId,
    required String developerInstructions,
  }) async {
    final dto = await _request(
      operation: "thread/resume",
      request: () => _appServerApi.resumeThread(threadId: threadId, developerInstructions: developerInstructions),
    );
    return CodexResumedThread(
      thread: _mapRequired(dto: dto, operation: "thread/resume"),
      runningTurnId: _runningTurnId(turns: dto.thread?.turns),
    );
  }

  /// Codex marks a resumed thread's in-progress turns interrupted unless the
  /// thread is still active, so an in-progress turn here is still running.
  String? _runningTurnId({required List<CodexTurnDto>? turns}) {
    for (final turn in (turns ?? const <CodexTurnDto>[]).reversed) {
      if (turn.status == CodexTurnStatus.inProgress) return _usefulText(value: turn.id);
    }
    return null;
  }

  /// [skill] names the skill a `\$name` text part invokes; Codex keeps it on
  /// the turn's `userMessage` item.
  Future<String?> startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    required ({String name, String path})? skill,
    required String? clientUserMessageId,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
    required bool? fastMode,
  }) async {
    final input = _turnInput(parts: parts);
    if (input.isEmpty) return null;
    if (skill != null) input.add(CodexTurnInputDto.skill(name: skill.name, path: skill.path));
    final response = await _request(
      operation: "turn/start",
      request: () => _appServerApi.startTurn(
        threadId: threadId,
        input: input,
        clientUserMessageId: clientUserMessageId,
        model: model,
        effort: effort,
        collaborationMode: collaborationMode,
        fastMode: fastMode,
      ),
    );
    final turnId = _usefulText(value: response.turn?.id);
    if (turnId == null) {
      throw StateError("turn/start response missing turn.id");
    }
    return turnId;
  }

  /// Throws what [startTurn] would throw for [parts]' attachments, without
  /// sending anything.
  void validateTurnInput({required List<PluginPromptPart> parts}) => _turnInput(parts: parts);

  List<CodexTurnInputDto> _turnInput({required List<PluginPromptPart> parts}) {
    final input = <CodexTurnInputDto>[];
    var remainingInlineBytes = maxInlineMessageAttachmentBytes;
    for (final part in joinAdjacentPromptTextParts(parts: parts)) {
      final mapped = _mapTurnInput(part: part, remainingInlineBytes: remainingInlineBytes);
      input.add(mapped.input);
      remainingInlineBytes -= mapped.inlineBytes;
    }
    return input;
  }

  /// Removes [beforeTurnId] and every later turn from the loaded [threadId].
  /// The refusals Codex answers before changing anything become
  /// [PluginBranchPointUnavailableException]; a thread this app-server has
  /// not loaded is [CodexThreadNotFoundException], as for `turn/start`.
  Future<void> revertThread({required String threadId, required String beforeTurnId}) async {
    const operation = "thread/revert";
    try {
      await _appServerApi.revertThread(threadId: threadId, beforeTurnId: beforeTurnId);
    } on CodexRpcException catch (error, stackTrace) {
      final refusal = _revertRefusal(error: error);
      if (refusal != null) Error.throwWithStackTrace(refusal.toException(cause: error), stackTrace);
      Error.throwWithStackTrace(_operationException(operation: operation, error: error), stackTrace);
    }
  }

  /// The answers live-checked on the 0.139.0 and 0.167.2 app-servers.
  CodexRewindRefusal? _revertRefusal({required CodexRpcException error}) {
    final message = error.message;
    // 0.139.0 answers -32600 "unknown variant `thread/revert`" rather than
    // JSON-RPC's method-not-found.
    if (error.code == -32601 || message.contains("unknown variant")) return CodexRewindRefusal.runtimeTooOld;
    if (error.code != -32600) return null;
    if (message.contains("only supports paginated threads")) return CodexRewindRefusal.legacySession;
    if (message.contains("ephemeral threads")) return CodexRewindRefusal.temporarySession;
    if (message.startsWith("turn not found")) return CodexRewindRefusal.unknownMessage;
    return null;
  }

  /// Forks [threadId] through its finished turn [lastTurnId] into a new
  /// persisted thread in the same directory, leaving the source untouched.
  /// The refusals Codex answers before creating the fork, and a runtime too
  /// old to fork at a turn, become [PluginBranchPointUnavailableException].
  Future<CodexThreadRecord> forkThread({
    required String threadId,
    required String lastTurnId,
    required String developerInstructions,
  }) async {
    if (!_forksThroughTurn) throw CodexForkRefusal.runtimeTooOld.toException(cause: null);
    const operation = "thread/fork";
    try {
      final dto = await _appServerApi.forkThread(
        threadId: threadId,
        lastTurnId: lastTurnId,
        developerInstructions: developerInstructions,
      );
      return _mapRequired(dto: dto, operation: operation);
    } on CodexRpcException catch (error, stackTrace) {
      final refusal = _forkRefusal(error: error);
      if (refusal != null) Error.throwWithStackTrace(refusal.toException(cause: error), stackTrace);
      Error.throwWithStackTrace(_operationException(operation: operation, error: error), stackTrace);
    }
  }

  /// The answers of the 0.167.2 thread store's fork preparation.
  CodexForkRefusal? _forkRefusal({required CodexRpcException error}) {
    final message = error.message;
    if (error.code != -32600) return null;
    if (message.contains("identifies an in-progress turn")) return CodexForkRefusal.turnRunning;
    if (message.startsWith("turn not found")) return CodexForkRefusal.unknownMessage;
    if (message.startsWith("no rollout found for thread id")) return CodexForkRefusal.missingSession;
    return null;
  }

  /// The id of the thread's newest turn, running or finished, or null when
  /// the thread has no turn yet.
  Future<String?> latestTurnId({required String threadId}) async {
    const operation = "thread/turns/list";
    try {
      final page = await _appServerApi.listLatestTurn(threadId: threadId);
      return _usefulText(value: page.data?.firstOrNull?.id);
    } on CodexRpcException catch (error, stackTrace) {
      // A thread started without a prompt has no rollout yet, which Codex
      // reports as "thread <id> is not materialized yet".
      if (error.message.contains("is not materialized yet")) return null;
      Error.throwWithStackTrace(_operationException(operation: operation, error: error), stackTrace);
    }
  }

  /// Asks [prompt] on a throwaway copy of the loaded thread whose latest turn
  /// is [expectedTurnId], without tools and without writing to the thread.
  Future<PluginSideAnswer> sampleThread({
    required String threadId,
    required String expectedTurnId,
    required String prompt,
  }) async {
    const operation = "thread/sample";
    try {
      final sample = await _appServerApi.sampleThread(
        threadId: threadId,
        expectedTurnId: expectedTurnId,
        prompt: prompt,
      );
      return _sideAnswerMapper.map(sample: sample);
    } on CodexRpcException catch (error, stackTrace) {
      final unsupported = _sideAnswerMapper.mapUnsupported(error: error);
      if (unsupported != null) return unsupported;
      Error.throwWithStackTrace(_operationException(operation: operation, error: error), stackTrace);
    }
  }

  Future<void> compactThread({required String threadId}) => _request(
    operation: "thread/compact/start",
    request: () => _appServerApi.compactThread(threadId: threadId),
  );

  CodexThreadRecord? mapStartedNotification({
    required CodexThreadEnvelopeDto dto,
  }) => _map(dto: dto);

  CodexThreadRecord? decodeStartedNotificationParams({
    required Map<String, dynamic> params,
  }) {
    final dto = _appServerApi.decodeThreadStartedParams(params: params);
    return dto == null ? null : mapStartedNotification(dto: dto);
  }

  CodexThreadRecord _mapRequired({
    required CodexThreadEnvelopeDto dto,
    required String operation,
  }) {
    final record = _map(dto: dto);
    if (record == null) {
      throw StateError("$operation response missing thread.id");
    }
    return record;
  }

  CodexThreadRecord? _map({required CodexThreadEnvelopeDto dto}) {
    final thread = dto.thread;
    final id = _usefulText(value: thread?.id);
    if (thread == null || id == null) return null;
    final cwd = _usefulText(value: thread.cwd) ?? _usefulText(value: dto.cwd);
    return CodexThreadRecord(
      id: id,
      name: thread.name,
      directory: cwd == null ? null : normalizeProjectDirectory(directory: cwd),
      createdAt: _milliseconds(seconds: thread.createdAt),
      updatedAt: _milliseconds(seconds: thread.updatedAt),
      model: _usefulText(value: dto.model) ?? _usefulText(value: thread.model),
      reasoningEffort: _usefulText(value: dto.reasoningEffort) ?? _usefulText(value: thread.reasoningEffort),
      modelProvider: _usefulText(value: thread.modelProvider) ?? _usefulText(value: dto.modelProvider),
      parentId: _subAgentParentId(thread: thread),
      agentNickname: _usefulText(value: thread.agentNickname),
      agentPath: null,
    );
  }

  String? _subAgentParentId({required CodexThreadDto thread}) => switch (thread.threadSource) {
    CodexThreadSource.subAgent ||
    CodexThreadSource.subAgentReview ||
    CodexThreadSource.subAgentCompact ||
    CodexThreadSource.subAgentThreadSpawn ||
    CodexThreadSource.subAgentOther => _usefulText(value: thread.parentThreadId),
    CodexThreadSource.unknown || null => null,
  };

  ({CodexTurnInputDto input, int inlineBytes}) _mapTurnInput({
    required PluginPromptPart part,
    required int remainingInlineBytes,
  }) {
    return switch (part) {
      PluginPromptPartText(:final text) => (input: CodexTurnInputDto.text(text: text), inlineBytes: 0),
      PluginPromptPartFileUrl(:final url) => (input: CodexTurnInputDto.image(url: url), inlineBytes: 0),
      PluginPromptPartFileData(:final mime, :final base64) => _mapInlineImage(
        mime: mime,
        base64Data: base64,
        remainingInlineBytes: remainingInlineBytes,
      ),
    };
  }

  ({CodexTurnInputDto input, int inlineBytes}) _mapInlineImage({
    required String mime,
    required String base64Data,
    required int remainingInlineBytes,
  }) {
    final normalizedMime = mime.trim().toLowerCase();
    if (!_supportedImageMimes.contains(normalizedMime)) {
      throw const _CodexPromptAttachmentException(
        message: "Unsupported inline image type",
        innerError: null,
      );
    }
    if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: base64Data.length)) {
      throw const _CodexPromptAttachmentException(
        message: "Inline image exceeds the attachment size limit",
        innerError: null,
      );
    }
    if (base64Data.isEmpty) {
      throw const _CodexPromptAttachmentException(
        message: "Malformed inline image data",
        innerError: null,
      );
    }

    late final String normalizedBase64;
    try {
      normalizedBase64 = base64.normalize(base64Data);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _CodexPromptAttachmentException(
          message: "Malformed inline image data",
          innerError: error,
        ),
        stackTrace,
      );
    }
    final decodedBytes = decodedBase64Length(base64Data: normalizedBase64);
    if (decodedBytes > remainingInlineBytes) {
      throw const _CodexPromptAttachmentException(
        message: "Inline images exceed the aggregate attachment size limit",
        innerError: null,
      );
    }
    return (
      input: CodexTurnInputDto.image(url: "data:$normalizedMime;base64,$normalizedBase64"),
      inlineBytes: decodedBytes,
    );
  }

  Future<T> _request<T>({
    required String operation,
    required Future<T> Function() request,
  }) async {
    try {
      return await request();
    } on CodexRpcException catch (error, stackTrace) {
      Error.throwWithStackTrace(_operationException(operation: operation, error: error), stackTrace);
    }
  }

  Exception _operationException({required String operation, required CodexRpcException error}) =>
      _modelProviderException(operation: operation, error: error) ??
      (_isThreadNotFound(error: error)
          ? CodexThreadNotFoundException(
              operation: operation,
              message: error.message,
              innerError: error,
            )
          : CodexThreadRequestException(
              operation: operation,
              message: error.message,
              innerError: error,
            ));

  /// Codex rejects a thread whose stored model provider the current config
  /// cannot serve (seen on `thread/resume`) with structured `error.data`.
  CodexModelProviderException? _modelProviderException({
    required String operation,
    required CodexRpcException error,
  }) {
    final data = error.data;
    if (data is! Map<String, dynamic>) return null;
    final CodexModelProviderErrorDto dto;
    try {
      dto = CodexModelProviderErrorDto.fromJson(data);
    } on Object catch (parseError, stackTrace) {
      // A known provider `type` with an unexpected shape; the generic request
      // failure keeps the raw data, this keeps why it was not recognised.
      Log.w("[codex] unrecognised $operation error data; reporting a generic failure", parseError, stackTrace);
      return null;
    }
    return switch (dto) {
      CodexModelProviderMismatchDto(:final modelProvider, :final currentModelProvider) =>
        CodexModelProviderMismatchException(
          operation: operation,
          threadProvider: modelProvider,
          currentProvider: currentModelProvider,
          cause: error,
        ),
      CodexModelProviderNotConfiguredDto(:final modelProvider) => CodexModelProviderNotConfiguredException(
        operation: operation,
        threadProvider: modelProvider,
        cause: error,
      ),
      CodexModelProviderPolicyConflictDto(:final modelProvider, :final requiredModelProvider) =>
        CodexModelProviderPolicyConflictException(
          operation: operation,
          threadProvider: modelProvider,
          requiredProvider: requiredModelProvider,
          cause: error,
        ),
      CodexUnknownModelProviderErrorDto() => null,
    };
  }

  bool _isThreadNotFound({required CodexRpcException error}) {
    final message = error.message.toLowerCase();
    return message.contains("thread not found") ||
        message.contains("no such thread") ||
        (error.code == -32600 && message.contains("not found"));
  }

  int? _milliseconds({required num? seconds}) => seconds == null ? null : (seconds * 1000).round();

  String? _usefulText({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
