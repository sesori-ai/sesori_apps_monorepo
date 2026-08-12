import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_tool_outcome_storage.dart";
import "../api/models/codex_command_execution_dto.dart";
import "../api/models/codex_correlatable_item_event_dto.dart";
import "../api/models/codex_tool_outcome_dto.dart";

/// Layer-2 decisions over persisted structured tool failures.
class CodexToolOutcomeRepository({
    required CodexToolOutcomeStorage storage,
  }) {
  this : _storage = storage;

  final CodexToolOutcomeStorage _storage;

  Future<Map<String, PluginToolStatus>> readStatuses({
    required String sessionId,
  }) async {
    final errors = await _storage.readErrors();
    return Map.unmodifiable({
      for (final error in errors)
        if (error.sessionId == sessionId) error.callId: PluginToolStatus.error,
    });
  }

  Future<void> recordError({
    required String sessionId,
    required String callId,
  }) {
    return _storage.updateErrors(
      transform: (errors) {
        if (errors.any(
          (error) => error.sessionId == sessionId && error.callId == callId,
        )) {
          return errors;
        }
        return [
          ...errors,
          CodexStoredToolErrorDto(
            sessionId: sessionId,
            callId: callId,
          ),
        ]..sort(
          (left, right) => _compareErrors(left: left, right: right),
        );
      },
    );
  }

  Future<void> recordCommandOutcome({
    required CodexCommandExecutionEventDto command,
    required String canonicalCallId,
  }) async {
    final completedError =
        command.lifecycle == CodexCorrelatableItemLifecycle.completed &&
        ((command.exitCode != null && command.exitCode != 0) ||
            command.status == CodexCommandExecutionStatus.failed ||
            command.status == CodexCommandExecutionStatus.declined);
    if (!completedError) return;
    await recordError(
      sessionId: command.threadId,
      callId: canonicalCallId,
    );
  }

  Future<void> deleteSession({required String sessionId}) {
    return _storage.updateErrors(
      transform: (errors) => [
        for (final error in errors)
          if (error.sessionId != sessionId) error,
      ],
    );
  }

  int _compareErrors({
    required CodexStoredToolErrorDto left,
    required CodexStoredToolErrorDto right,
  }) {
    final sessionOrder = left.sessionId.compareTo(right.sessionId);
    return sessionOrder != 0 ? sessionOrder : left.callId.compareTo(right.callId);
  }
}
