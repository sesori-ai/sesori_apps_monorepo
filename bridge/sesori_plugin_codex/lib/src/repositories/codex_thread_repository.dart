import "dart:convert";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
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
class CodexThreadRepository({required final CodexAppServerApi _appServerApi}) {
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

  Future<String?> startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    required String? clientUserMessageId,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
    required bool? fastMode,
  }) async {
    final input = <CodexTurnInputDto>[];
    var remainingInlineBytes = maxInlineMessageAttachmentBytes;
    for (final part in joinAdjacentPromptTextParts(parts: parts)) {
      final mapped = _mapTurnInput(part: part, remainingInlineBytes: remainingInlineBytes);
      input.add(mapped.input);
      remainingInlineBytes -= mapped.inlineBytes;
    }
    if (input.isEmpty) return null;
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
      PluginPromptPartFilePath(:final path) => (input: CodexTurnInputDto.localImage(path: path), inlineBytes: 0),
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
      final Exception exception =
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
      Error.throwWithStackTrace(exception, stackTrace);
    }
  }

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
