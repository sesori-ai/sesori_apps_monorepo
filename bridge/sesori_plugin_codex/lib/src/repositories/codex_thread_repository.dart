import "dart:convert";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show decodedBase64Length, isInlineMessageAttachmentWithinSizeLimit, maxInlineMessageAttachmentBytes;

import "../api/codex_app_server_api.dart";
import "../api/models/codex_thread_dto.dart";
import "../api/models/codex_turn_input_dto.dart";
import "../codex_app_server_client.dart";
import "../models/codex_collaboration_mode.dart";
import "models/codex_thread_record.dart";

sealed class CodexThreadOperationException implements Exception {
  const CodexThreadOperationException({
    required this.operation,
    required this.message,
  });

  final String operation;
  final String message;

  @override
  String toString() => "CodexThreadOperationException($operation: $message)";
}

final class CodexThreadNotFoundException extends CodexThreadOperationException {
  const CodexThreadNotFoundException({
    required super.operation,
    required super.message,
  });
}

final class CodexThreadRequestException extends CodexThreadOperationException {
  const CodexThreadRequestException({
    required super.operation,
    required super.message,
  });
}

final class _CodexPromptAttachmentException implements Exception {
  const _CodexPromptAttachmentException({required this.message, required this.innerError});

  final String message;
  final Object? innerError;

  @override
  String toString() => "CodexPromptAttachmentException($message)";
}

/// Layer-2 normalization and domain mapping for Codex app-server threads.
class CodexThreadRepository {
  static const _supportedImageMimes = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };

  CodexThreadRepository({required CodexAppServerApi appServerApi}) : _appServerApi = appServerApi;

  final CodexAppServerApi _appServerApi;

  Future<CodexThreadRecord> startThread({
    required String cwd,
    required String? model,
    required String? modelProvider,
  }) async {
    final dto = await _request(
      operation: "thread/start",
      request: () => _appServerApi.startThread(
        cwd: cwd,
        model: model,
        modelProvider: modelProvider,
      ),
    );
    return _mapRequired(dto: dto, operation: "thread/start");
  }

  Future<CodexThreadRecord> resumeThread({required String threadId}) async {
    final dto = await _request(
      operation: "thread/resume",
      request: () => _appServerApi.resumeThread(threadId: threadId),
    );
    return _mapRequired(dto: dto, operation: "thread/resume");
  }

  Future<String?> startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    final input = <CodexTurnInputDto>[];
    var remainingInlineBytes = maxInlineMessageAttachmentBytes;
    for (final part in parts) {
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
        model: model,
        effort: effort,
        collaborationMode: collaborationMode,
      ),
    );
    final turnId = _usefulText(response.turn?.id);
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

  PluginSession toPluginSession({
    required CodexThreadRecord record,
    required String fallbackDirectory,
    required String? parentSessionId,
  }) {
    final directory = record.directory ?? normalizeProjectDirectory(directory: fallbackDirectory);
    final created = record.createdAt;
    final updated = record.updatedAt;
    return PluginSession(
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: parentSessionId,
      title: record.name,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
    );
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
    final id = _usefulText(thread?.id);
    if (thread == null || id == null) return null;
    final cwd = _usefulText(thread.cwd) ?? _usefulText(dto.cwd);
    return CodexThreadRecord(
      id: id,
      name: thread.name,
      directory: cwd == null ? null : normalizeProjectDirectory(directory: cwd),
      createdAt: _milliseconds(thread.createdAt),
      updatedAt: _milliseconds(thread.updatedAt),
      model: _usefulText(dto.model),
      modelProvider: _usefulText(thread.modelProvider) ?? _usefulText(dto.modelProvider),
    );
  }

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
      final exception = _isThreadNotFound(error)
          ? CodexThreadNotFoundException(
              operation: operation,
              message: error.message,
            )
          : CodexThreadRequestException(
              operation: operation,
              message: error.message,
            );
      Error.throwWithStackTrace(exception, stackTrace);
    }
  }

  bool _isThreadNotFound(CodexRpcException error) {
    final message = error.message.toLowerCase();
    return message.contains("thread not found") ||
        message.contains("no such thread") ||
        (error.code == -32600 && message.contains("not found"));
  }

  int? _milliseconds(num? seconds) => seconds == null ? null : (seconds * 1000).round();

  String? _usefulText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
