import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginMessageWithParts, PluginOperationException;

import "../api/models/pi_session_history_dto.dart";
import "../api/pi_launch_spec.dart";
import "../api/pi_process_factory.dart";
import "../api/pi_rpc_client.dart";
import "../api/pi_session_storage_api.dart";
import "../models/pi_rpc_command.dart";
import "mappers/pi_history_mapper.dart";

final class const PiSessionHistoryNotFoundException({required final String sessionId}) implements Exception {
  @override
  String toString() => "PiSessionHistoryNotFoundException";
}

final class const PiHistoryRpcStartupUnavailableException({required final Object cause}) implements Exception {
  @override
  String toString() => "PiHistoryRpcStartupUnavailableException";
}

final class const PiSessionHistoryLoadException({required final Object innerError}) implements Exception {
  @override
  String toString() => "PiSessionHistoryLoadException";
}

final class const PiSessionHistoryParseException({required final Object innerError}) implements Exception {
  @override
  String toString() => "PiSessionHistoryParseException";
}

final class PiSessionProcessRepository({
  required final PiSessionStorageApi _storageApi,
  required final PiSessionHistoryStorageApi _historyStorageApi,
  required final String _binaryPath,
  required Map<String, String> environment,
  required final PiProcessFactory _processFactory,
  required final PiHistoryMapper _historyMapper,
}) {
  static const Duration _historyRpcTimeout = Duration(seconds: 15);

  final Map<String, String> _environment = Map.unmodifiable(environment);

  Future<List<PluginMessageWithParts>> loadHistory({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async {
    final PiResolvedSession? resolved;
    try {
      resolved = await _storageApi.resolveSession(sessionId: sessionId, knownDirectories: knownDirectories);
    } on Object catch (error, stack) {
      _throwLoadFailure(path: "session storage", error: error, stack: stack);
    }
    if (resolved == null) {
      final cause = PiSessionHistoryNotFoundException(sessionId: sessionId);
      Error.throwWithStackTrace(
        PluginOperationException.notFound(
          "load Pi session history",
          message: "Pi session was not found.",
          cause: cause,
        ),
        StackTrace.current,
      );
    }

    try {
      final history = await _readHistory(resolved: resolved);
      return _historyMapper.map(
        sessionId: sessionId,
        entries: history.entries,
        leafId: history.leafId,
      );
    } on Object catch (error, stack) {
      _throwLoadFailure(path: resolved.path, error: error, stack: stack);
    }
  }

  Future<PiSessionEntriesDto> _readHistory({required PiResolvedSession resolved}) async {
    try {
      return await _readHistoryFromRpc(resolved: resolved);
    } on PiHistoryRpcStartupUnavailableException catch (error, stack) {
      Log.w(
        "[pi] history RPC startup unavailable at '${resolved.path}'; reading persisted session history",
        error.cause,
        stack,
      );
      final fileHistory = await _historyStorageApi.readSessionHistory(path: resolved.path);
      return _normalizeFileHistory(history: fileHistory);
    }
  }

  Future<PiSessionEntriesDto> _readHistoryFromRpc({required PiResolvedSession resolved}) async {
    final client = PiRpcClient(
      launchSpec: PiLaunchSpec(
        binaryPath: _binaryPath,
        workingDirectory: resolved.metadata.cwd,
        launch: PiResumedSession(sessionPath: resolved.path),
        environment: _environment,
      ),
      processFactory: _processFactory,
    );
    try {
      await client.start();
      try {
        final response = await client.send(
          command: PiRpcCommand.getEntries,
          arguments: const {},
          timeout: _historyRpcTimeout,
        );
        try {
          return PiSessionEntriesDto.fromJson(response.data.cast<String, dynamic>());
        } on Object catch (error, stack) {
          Error.throwWithStackTrace(PiSessionHistoryParseException(innerError: error), stack);
        }
      } on PiRpcProcessExitException catch (error) {
        if (!_isNoModelStartupFailure(client.stderrDiagnostics)) rethrow;
        throw PiHistoryRpcStartupUnavailableException(cause: error);
      }
    } finally {
      await client.dispose();
    }
  }

  PiSessionEntriesDto _normalizeFileHistory({required PiSessionFileHistoryDto history}) {
    final isV1 = (history.header.version ?? 1) < 2;
    final entries = <PiSessionEntryDto>[];
    String? previousId;
    for (var index = 0; index < history.entries.length; index++) {
      final fileEntry = history.entries[index];
      final id = isV1 ? "sesori-v1-${index + 1}" : fileEntry.id;
      if (id == null) continue;
      final parentId = isV1 ? previousId : fileEntry.parentId;
      entries.add(_normalizeFileEntry(entry: fileEntry, id: id, parentId: parentId));
      previousId = id;
    }
    return PiSessionEntriesDto(entries: List.unmodifiable(entries), leafId: entries.lastOrNull?.id);
  }

  PiSessionEntryDto _normalizeFileEntry({
    required PiSessionFileEntryDto entry,
    required String id,
    required String? parentId,
  }) => switch (entry) {
    PiSessionFileMessageEntryDto(:final timestamp, :final message) => PiSessionEntryDto.message(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
      message: _normalizeFileMessage(message),
    ),
    PiSessionFileThinkingLevelChangeEntryDto(:final timestamp) => PiSessionEntryDto.thinkingLevelChange(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileModelChangeEntryDto(:final timestamp) => PiSessionEntryDto.modelChange(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileCompactionEntryDto(:final timestamp) => PiSessionEntryDto.compaction(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileBranchSummaryEntryDto(:final timestamp) => PiSessionEntryDto.branchSummary(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileCustomEntryDto(:final timestamp) => PiSessionEntryDto.custom(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileCustomMessageEntryDto(:final timestamp, :final content, :final display) =>
      PiSessionEntryDto.customMessage(
        id: id,
        parentId: parentId,
        timestamp: timestamp,
        content: content,
        display: display,
      ),
    PiSessionFileLabelEntryDto(:final timestamp) => PiSessionEntryDto.label(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileSessionInfoEntryDto(:final timestamp) => PiSessionEntryDto.sessionInfo(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileUnknownEntryDto(:final timestamp) => PiSessionEntryDto.unknown(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
  };

  PiAgentMessageDto _normalizeFileMessage(PiSessionFileAgentMessageDto message) => switch (message) {
    PiSessionFileUserMessageDto(:final content, :final timestamp) => PiAgentMessageDto.user(
      content: content,
      timestamp: timestamp,
    ),
    PiSessionFileAssistantMessageDto(
      :final content,
      :final provider,
      :final model,
      :final stopReason,
      :final timestamp,
    ) =>
      PiAgentMessageDto.assistant(
        content: content,
        provider: provider,
        model: model,
        stopReason: stopReason,
        timestamp: timestamp,
      ),
    PiSessionFileToolResultMessageDto(
      :final toolCallId,
      :final toolName,
      :final content,
      :final isError,
      :final timestamp,
    ) =>
      PiAgentMessageDto.toolResult(
        toolCallId: toolCallId,
        toolName: toolName,
        content: content,
        isError: isError,
        timestamp: timestamp,
      ),
    PiSessionFileBashExecutionMessageDto(
      :final command,
      :final output,
      :final exitCode,
      :final cancelled,
      :final truncated,
      :final timestamp,
    ) =>
      PiAgentMessageDto.bashExecution(
        command: command,
        output: output,
        exitCode: exitCode,
        cancelled: cancelled,
        truncated: truncated,
        timestamp: timestamp,
      ),
    PiSessionFileCustomMessageDto(:final content, :final display, :final timestamp) ||
    PiSessionFileHookMessageDto(:final content, :final display, :final timestamp) => PiAgentMessageDto.custom(
      content: content,
      display: display,
      timestamp: timestamp,
    ),
    PiSessionFileBranchSummaryMessageDto(:final timestamp) => PiAgentMessageDto.branchSummary(timestamp: timestamp),
    PiSessionFileCompactionSummaryMessageDto(:final timestamp) => PiAgentMessageDto.compactionSummary(
      timestamp: timestamp,
    ),
    PiSessionFileUnknownMessageDto(:final timestamp) => PiAgentMessageDto.unknown(timestamp: timestamp),
  };

  bool _isNoModelStartupFailure(List<String> diagnostics) => diagnostics.any(
    (line) => line == PiRpcClient.noModelsDiagnosticPrefix,
  );

  Never _throwLoadFailure({required String path, required Object error, required StackTrace stack}) {
    final localError = switch (error) {
      PiInvalidSessionHistoryException(:final cause) => PiSessionHistoryParseException(innerError: cause),
      _ => error,
    };
    Log.w("[pi] failed to load session history at '$path'", localError, stack);
    Error.throwWithStackTrace(
      PluginOperationException(
        "load Pi session history",
        message: "Pi session history could not be loaded.",
        cause: PiSessionHistoryLoadException(innerError: error),
      ),
      stack,
    );
  }
}
