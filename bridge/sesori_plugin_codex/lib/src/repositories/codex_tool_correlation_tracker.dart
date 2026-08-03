import "../api/models/codex_rollout_dto.dart";
import "../codex_app_server_client.dart";
import "mappers/codex_rollout_tool_mapper.dart";
import "models/codex_command_projection.dart";

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
  final Map<String, String> _appServerItemAliases = {};

  void observeRolloutLine({
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
    if (payload == null) return;
    if (!_rolloutToolMapper.isCommandExecutionCall(payload: payload)) return;
    final call = _rolloutToolMapper.mapCall(payload);
    final turnId = call?.turnId;
    if (call == null || turnId == null) return;
    _pendingShellCallsByTurn
        .putIfAbsent(
          _turnKey(threadId: threadId, turnId: turnId),
          () => [],
        )
        .add(call.id);
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
    _appServerItemAliases.removeWhere((key, _) => key.startsWith(prefix));
  }

  void clear() {
    _pendingShellCallsByTurn.clear();
    _appServerItemAliases.clear();
  }

  String _turnKey({required String threadId, required String turnId}) => "$threadId\u0000turn\u0000$turnId";

  String _appServerItemKey({required String threadId, required String itemId}) => "$threadId\u0000item\u0000$itemId";
}
