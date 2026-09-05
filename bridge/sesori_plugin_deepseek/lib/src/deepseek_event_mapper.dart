import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/deepseek_acp_api.dart";
import "api/models/deepseek_protocol_dto.dart";
import "deepseek_message_time_parser.dart";
import "repositories/mappers/deepseek_subagent_mapper.dart";
import "repositories/trackers/deepseek_delegation_tracker.dart";

class DeepSeekEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
  required final DeepSeekAcpApi api,
  required final DeepSeekMessageTimeParser messageTimeParser,
  required final DeepSeekSubagentMapper subagentMapper,
  required final DeepSeekDelegationTracker delegationTracker,
}) extends AcpEventMapper {
  @override
  PluginMessageTime? messageTimeForNotification({required AcpNotification notification}) =>
      messageTimeParser.parse(notification.params);

  @override
  PluginMessageTime localUserMessageTime({required int createdAtMs}) =>
      PluginMessageTime(created: createdAtMs, completed: null);

  final Map<String, Map<String, _DeferredDeepSeekDelegation>> _deferredDelegations = {};

  void resetLiveState() {
    _deferredDelegations.clear();
    delegationTracker.clear();
  }

  @override
  void beginTurn({required String sessionId, required String? messageId}) {
    _deferredDelegations.remove(sessionId);
    super.beginTurn(sessionId: sessionId, messageId: messageId);
  }

  @override
  void forgetSession(String sessionId) {
    _deferredDelegations.remove(sessionId);
    delegationTracker.forgetSession(sessionId: sessionId);
    super.forgetSession(sessionId);
  }

  @override
  AcpToolCallSessionLookup lookupSessionForToolCallId({required String? toolCallId}) {
    if (toolCallId == null || toolCallId.isEmpty) {
      return super.lookupSessionForToolCallId(toolCallId: toolCallId);
    }
    final sessionIds = <String>{
      for (final entry in _deferredDelegations.entries)
        if (entry.value.containsKey(toolCallId)) entry.key,
    };
    switch (delegationTracker.lookupToolCallId(toolCallId: toolCallId)) {
      case DeepSeekDelegationFound(:final sessionId):
        sessionIds.add(sessionId);
      case DeepSeekDelegationAmbiguous():
        return const AcpToolCallSessionAmbiguous();
      case DeepSeekDelegationNotFound():
        break;
    }
    switch (super.lookupSessionForToolCallId(toolCallId: toolCallId)) {
      case AcpToolCallSessionFound(:final sessionId):
        sessionIds.add(sessionId);
      case AcpToolCallSessionAmbiguous():
        return const AcpToolCallSessionAmbiguous();
      case AcpToolCallSessionNotFound():
        break;
    }
    return switch (sessionIds.toList(growable: false)) {
      [final sessionId] => AcpToolCallSessionFound(sessionId: sessionId),
      [] => const AcpToolCallSessionNotFound(),
      _ => const AcpToolCallSessionAmbiguous(),
    };
  }

  /// Protocol v2 delays exact delegation calls and identifiable reordered
  /// updates until either their correlated lifecycle start arrives (the child
  /// tile replaces them) or a standard terminal frame proves startup failed
  /// (one generic error card remains visible). This avoids both duplicate cards
  /// and invisible failures.
  @override
  List<BridgeSseEvent> map(AcpNotification notification) {
    if (notification.method != AcpMethods.sessionUpdate) {
      return super.map(notification);
    }
    final sessionId = notification.params["sessionId"];
    final update = notification.params["update"];
    if (sessionId is! String || sessionId.isEmpty || update is! Map<String, dynamic>) {
      return super.map(notification);
    }
    final toolCallId = update["toolCallId"];
    if (toolCallId is! String || toolCallId.isEmpty) return super.map(notification);
    final delegationStarted = delegationTracker.isStarted(
      parentSessionId: sessionId,
      toolCallId: toolCallId,
    );
    final title = switch (update["title"]) {
      final String value => value,
      _ => null,
    };
    final status = switch (update["status"]) {
      final String value => value,
      _ => null,
    };
    final hasDelegationTitle = title != null && _isDelegationTitle(title: title);
    switch (update["sessionUpdate"]) {
      case "tool_call" when hasDelegationTitle:
      case "tool_call_update"
          when delegationStarted ||
              hasDelegationTitle ||
              (_deferredDelegations[sessionId]?.containsKey(toolCallId) ?? false):
        if (delegationStarted) {
          if (status != null && _isTerminalToolStatus(status: status)) {
            delegationTracker.markToolTerminal(parentSessionId: sessionId, toolCallId: toolCallId);
          }
          return const [];
        }
        (_deferredDelegations[sessionId] ??= {})
            .putIfAbsent(toolCallId, _DeferredDeepSeekDelegation.new)
            .merge(notification: notification, update: update);
        if (status != null && _isTerminalToolStatus(status: status)) {
          return _flushDeferredDelegation(sessionId: sessionId, toolCallId: toolCallId);
        }
        return const [];
    }
    return super.map(notification);
  }

  @override
  bool shouldBufferDuringPromptWrite({required AcpNotification notification}) =>
      notification.method == DeepSeekAcpApi.subagentMethod ||
      super.shouldBufferDuringPromptWrite(notification: notification);

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    if (notification.method == DeepSeekAcpApi.subagentMethod) {
      return _mapSubagent(notification: notification);
    }
    if (notification.method != DeepSeekAcpApi.sessionStatusMethod) {
      return super.mapExtension(notification);
    }
    try {
      final status = api.parseSessionStatus(notification.params);
      return switch (status) {
        DeepSeekCompactionCompletedStatusDto() => [BridgeSseSessionCompacted(sessionID: status.sessionId)],
        DeepSeekWarningStatusDto() => _mapWarning(status),
        DeepSeekRetryStatusDto() || DeepSeekCompactionStartedStatusDto() => const [],
      };
    } on Object catch (error, stackTrace) {
      Log.w("[deepseek] ignored malformed session status notification", error, stackTrace);
      return const [];
    }
  }

  List<BridgeSseEvent> _mapSubagent({required AcpNotification notification}) {
    try {
      final subagent = api.parseSubagentNotification(notification.params);
      if (childSessions.isDeleted(sessionId: subagent.sessionId) ||
          childSessions.isDeleted(sessionId: subagent.childSessionId)) {
        return const [];
      }
      return switch (subagent) {
        DeepSeekSubagentStartedDto() => _mapSubagentStarted(notification: subagent),
        DeepSeekSubagentEndedDto() => _mapSubagentEnded(notification: subagent),
      };
    } on Object catch (error, stackTrace) {
      final recoveryEvents = _recoverMalformedSubagent(notification: notification);
      Log.w("[deepseek] ignored malformed sub-agent notification", error, stackTrace);
      return recoveryEvents;
    }
  }

  List<BridgeSseEvent> _mapSubagentStarted({required DeepSeekSubagentStartedDto notification}) {
    _removeDeferredDelegation(sessionId: notification.sessionId, toolCallId: notification.toolCallId);
    final events = mapChildSpawned(
      sessionId: notification.sessionId,
      spawn: subagentMapper.mapStarted(notification: notification),
    );
    if (!childSessions.isChild(sessionId: notification.childSessionId)) return events;
    delegationTracker.start(
      parentSessionId: notification.sessionId,
      toolCallId: notification.toolCallId,
      childSessionId: notification.childSessionId,
    );
    setChildModel(
      childSessionId: notification.childSessionId,
      modelId: modelForSession(sessionId: notification.sessionId),
    );
    return events;
  }

  List<BridgeSseEvent> _recoverMalformedSubagent({required AcpNotification notification}) {
    final params = notification.params;
    final sessionId = params["sessionId"];
    final childSessionId = params["childSessionId"];
    if (sessionId is String && childSessions.isDeleted(sessionId: sessionId) ||
        childSessionId is String && childSessions.isDeleted(sessionId: childSessionId)) {
      return const [];
    }
    if (params["kind"] == "started") {
      final toolCallId = params["toolCallId"];
      if (sessionId is String && toolCallId is String) {
        return _flushDeferredDelegation(sessionId: sessionId, toolCallId: toolCallId);
      }
      return const [];
    }
    if (params["kind"] == "ended") {
      if (childSessionId is String && childSessions.isChild(sessionId: childSessionId)) {
        delegationTracker.markChildEnded(childSessionId: childSessionId);
        return mapChildFinished(
          childSessionId: childSessionId,
          status: PluginToolStatus.error,
          output: null,
          error: "DeepSeek sub-agent returned an invalid completion",
        );
      }
    }
    return const [];
  }

  List<BridgeSseEvent> _flushDeferredDelegation({required String sessionId, required String toolCallId}) {
    final deferred = _removeDeferredDelegation(sessionId: sessionId, toolCallId: toolCallId);
    final snapshot = deferred?.snapshot;
    return snapshot == null ? const [] : super.map(snapshot);
  }

  _DeferredDeepSeekDelegation? _removeDeferredDelegation({required String sessionId, required String toolCallId}) {
    final byToolCall = _deferredDelegations[sessionId];
    final deferred = byToolCall?.remove(toolCallId);
    if (byToolCall?.isEmpty ?? false) _deferredDelegations.remove(sessionId);
    return deferred;
  }

  static bool _isDelegationTitle({required String title}) => title == "subagent" || title == "subagent_fork";

  static bool _isTerminalToolStatus({required String status}) => status == "completed" || status == "failed";

  List<BridgeSseEvent> _mapSubagentEnded({required DeepSeekSubagentEndedDto notification}) {
    delegationTracker.markChildEnded(childSessionId: notification.childSessionId);
    final state = subagentMapper.mapState(
      stopReason: notification.stopReason,
      summary: notification.summary,
    );
    return mapChildFinished(
      childSessionId: notification.childSessionId,
      status: state.status,
      output: state.output,
      error: state.error,
    );
  }

  List<BridgeSseEvent> _mapWarning(DeepSeekWarningStatusDto status) {
    Log.w("[deepseek] session warning for ${status.sessionId}: ${status.message}");
    return [BridgeSseSessionError(sessionID: status.sessionId)];
  }
}

final class _DeferredDeepSeekDelegation() {
  static const _retainedUpdateKeys = {
    "sessionUpdate",
    "toolCallId",
    "kind",
    "title",
    "status",
    "content",
    "rawOutput",
  };

  // ignore: no_slop_linter/prefer_specific_type, standard ACP update values are heterogeneous
  final Map<String, dynamic> _mergedUpdate = {};
  // ignore: no_slop_linter/prefer_specific_type, standard ACP params are heterogeneous
  Map<String, dynamic>? _latestParams;

  void merge({
    required AcpNotification notification,
    // ignore: no_slop_linter/prefer_specific_type, standard ACP update values are heterogeneous
    required Map<String, dynamic> update,
  }) {
    if (update.containsKey("content")) {
      _mergedUpdate.remove("rawOutput");
    } else if (update.containsKey("rawOutput")) {
      _mergedUpdate.remove("content");
    }
    for (final entry in update.entries) {
      if (_retainedUpdateKeys.contains(entry.key)) _mergedUpdate[entry.key] = entry.value;
    }
    _latestParams = notification.params;
  }

  AcpNotification? get snapshot {
    final params = _latestParams;
    if (params == null) return null;
    // ignore: no_slop_linter/prefer_specific_type, standard ACP update values are heterogeneous
    final mergedUpdate = Map<String, dynamic>.unmodifiable(_mergedUpdate);
    return AcpNotification(
      method: AcpMethods.sessionUpdate,
      params: {...params, "update": mergedUpdate},
    );
  }
}
