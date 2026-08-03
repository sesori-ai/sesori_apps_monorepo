import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/codex_rollout_dto.dart";
import "../codex_app_server_client.dart";
import "mappers/codex_rollout_tool_mapper.dart";
import "models/codex_tool_projection.dart";

/// Correlates Codex's two live identities for one logical shell command.
///
/// Codex persists a `call_*` rollout id but emits a separate `exec-*`
/// app-server id. Commands execute sequentially within a turn, making the
/// pending same-turn FIFO the narrow common identity between those streams.
class CodexToolCorrelationTracker {
  CodexToolCorrelationTracker({
    required CodexRolloutToolMapper rolloutToolMapper,
  }) : _rolloutToolMapper = rolloutToolMapper;

  final CodexRolloutToolMapper _rolloutToolMapper;
  final Map<String, List<String>> _pendingShellCallsByTurn = {};
  final Map<String, CodexRolloutToolCall> _visibleCalls = {};
  final Map<String, String> _visibleCallByCell = {};
  final Map<String, String> _visibleCallByThreadCell = {};
  final Map<String, String> _waitTargetByCall = {};
  final Map<String, String> _waitCellByCall = {};
  final Map<String, Set<String>> _outstandingCellsByCall = {};
  final Set<String> _internalCalls = {};
  final Map<String, String> _appServerItemAliases = {};

  CodexRolloutToolProjection observeRolloutLine({
    required String threadId,
    required CodexRolloutLineDto line,
  }) {
    final payload = switch (line) {
      CodexRolloutResponseItemLineDto(payload: final payload) => payload,
      CodexRolloutSessionMetadataLineDto() ||
      CodexRolloutTurnContextLineDto() ||
      CodexRolloutEventMessageLineDto() ||
      CodexRolloutCompactedLineDto() ||
      CodexRolloutUnknownLineDto() => null,
    };
    if (payload == null) return const CodexRolloutToolPassthrough();

    final wait = _rolloutToolMapper.mapWaitCall(payload: payload);
    if (wait != null) {
      final waitKey = _callKey(threadId: threadId, callId: wait.callId);
      _internalCalls.add(waitKey);
      final turnId = wait.turnId;
      final target =
          (turnId == null
              ? null
              : _visibleCallByCell[_cellKey(
                  threadId: threadId,
                  turnId: turnId,
                  cellId: wait.cellId,
                )]) ??
          _visibleCallByThreadCell[_threadCellKey(threadId: threadId, cellId: wait.cellId)];
      if (target != null) _waitTargetByCall[waitKey] = target;
      _waitCellByCall[waitKey] = wait.cellId;
      return const CodexRolloutToolSuppressed();
    }

    final internalCallId = _rolloutToolMapper.internalCallId(
      payload: payload,
    );
    if (internalCallId != null) {
      _internalCalls.add(
        _callKey(threadId: threadId, callId: internalCallId),
      );
      return const CodexRolloutToolSuppressed();
    }

    final call = _rolloutToolMapper.mapCall(payload);
    if (call != null) {
      final callKey = _callKey(threadId: threadId, callId: call.id);
      _visibleCalls[callKey] = call;
      final turnId = call.turnId;
      if (turnId != null && _rolloutToolMapper.isCommandExecutionCall(payload: payload)) {
        _pendingShellCallsByTurn
            .putIfAbsent(
              _turnKey(threadId: threadId, turnId: turnId),
              () => [],
            )
            .add(call.id);
      }
      return const CodexRolloutToolPassthrough();
    }

    final result = _rolloutToolMapper.mapResult(payload);
    if (result == null) return const CodexRolloutToolPassthrough();
    final resultKey = _callKey(
      threadId: threadId,
      callId: result.callId,
    );
    final waitTarget = _waitTargetByCall[resultKey];
    if (_internalCalls.contains(resultKey) && waitTarget == null) {
      return const CodexRolloutToolSuppressed();
    }
    final canonicalCallId = waitTarget ?? result.callId;
    final canonicalKey = _callKey(
      threadId: threadId,
      callId: canonicalCallId,
    );
    final visibleCall = _visibleCalls[canonicalKey];
    final cellIds = switch (result) {
      CodexRolloutToolRunningResult(:final cellIds) => cellIds,
      CodexRolloutToolErrorWithRunningCellsResult(:final cellIds) => cellIds,
      CodexRolloutToolCompletedResult() || CodexRolloutToolErrorResult() => const <String>[],
    };
    if (cellIds.isNotEmpty) {
      _outstandingCellsByCall.putIfAbsent(canonicalKey, () => {}).addAll(cellIds);
    }
    final turnId = visibleCall?.turnId;
    for (final cellId in cellIds) {
      _visibleCallByThreadCell[_threadCellKey(threadId: threadId, cellId: cellId)] = canonicalCallId;
      if (turnId != null) {
        _visibleCallByCell[_cellKey(threadId: threadId, turnId: turnId, cellId: cellId)] = canonicalCallId;
      }
    }
    final waitedCell = _waitCellByCall[resultKey];
    final outstandingCells = _outstandingCellsByCall[canonicalKey];
    if (waitTarget != null &&
        waitedCell != null &&
        (result.status != PluginToolStatus.running || !cellIds.contains(waitedCell))) {
      outstandingCells?.remove(waitedCell);
      if (outstandingCells?.isEmpty ?? false) {
        _outstandingCellsByCall.remove(canonicalKey);
      }
    }
    if (result.status != PluginToolStatus.running && waitTarget == null) {
      _outstandingCellsByCall.remove(canonicalKey);
    } else if (result.status == PluginToolStatus.completed && outstandingCells?.isNotEmpty == true) {
      return CodexRolloutToolCanonicalRunning(
        callId: canonicalCallId,
        remainingCellIds: outstandingCells!.toList(growable: false),
      );
    }
    return waitTarget == null
        ? const CodexRolloutToolPassthrough()
        : CodexRolloutToolCanonical(callId: canonicalCallId);
  }

  CodexAppServerCommandProjection correlateAppServerCommand({
    required CodexServerNotification notification,
  }) {
    if (notification.method != "item/started" && notification.method != "item/completed") {
      return const CodexAppServerCommandNative();
    }
    final params = notification.params;
    final item = params["item"];
    if (item is! Map || item["type"] != "commandExecution") {
      return const CodexAppServerCommandNative();
    }
    final itemId = item["id"];
    final threadId = params["threadId"];
    if (itemId is! String || itemId.isEmpty || threadId is! String || threadId.isEmpty) {
      return const CodexAppServerCommandNative();
    }

    final aliasKey = _appServerItemKey(threadId: threadId, itemId: itemId);
    var callId = _appServerItemAliases[aliasKey];
    final turnId = params["turnId"];
    if (callId == null && turnId is String && turnId.isNotEmpty) {
      final turnKey = _turnKey(threadId: threadId, turnId: turnId);
      final pending = _pendingShellCallsByTurn[turnKey];
      if (pending != null && pending.isNotEmpty) {
        callId = pending.removeAt(0);
        _appServerItemAliases[aliasKey] = callId;
        if (pending.isEmpty) _pendingShellCallsByTurn.remove(turnKey);
      }
    }
    return callId == null ? const CodexAppServerCommandNative() : CodexAppServerCommandCanonical(callId: callId);
  }

  void clearThread({required String threadId}) {
    final prefix = "$threadId\u0000";
    _pendingShellCallsByTurn.removeWhere((key, _) => key.startsWith(prefix));
    _visibleCalls.removeWhere((key, _) => key.startsWith(prefix));
    _visibleCallByCell.removeWhere((key, _) => key.startsWith(prefix));
    _visibleCallByThreadCell.removeWhere((key, _) => key.startsWith(prefix));
    _waitTargetByCall.removeWhere((key, _) => key.startsWith(prefix));
    _waitCellByCall.removeWhere((key, _) => key.startsWith(prefix));
    _outstandingCellsByCall.removeWhere((key, _) => key.startsWith(prefix));
    _internalCalls.removeWhere((key) => key.startsWith(prefix));
    _appServerItemAliases.removeWhere((key, _) => key.startsWith(prefix));
  }

  void clear() {
    _pendingShellCallsByTurn.clear();
    _visibleCalls.clear();
    _visibleCallByCell.clear();
    _visibleCallByThreadCell.clear();
    _waitTargetByCall.clear();
    _waitCellByCall.clear();
    _outstandingCellsByCall.clear();
    _internalCalls.clear();
    _appServerItemAliases.clear();
  }

  String _turnKey({required String threadId, required String turnId}) => "$threadId\u0000turn\u0000$turnId";

  String _callKey({required String threadId, required String callId}) => "$threadId\u0000call\u0000$callId";

  String _cellKey({required String threadId, required String turnId, required String cellId}) =>
      "$threadId\u0000cell\u0000$turnId\u0000$cellId";

  String _threadCellKey({required String threadId, required String cellId}) =>
      "$threadId\u0000thread-cell\u0000$cellId";

  String _appServerItemKey({required String threadId, required String itemId}) => "$threadId\u0000item\u0000$itemId";
}
