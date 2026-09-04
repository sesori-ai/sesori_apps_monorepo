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

  var _extensionProtocolVersion = 1;
  final Map<String, Map<String, _DeferredDeepSeekDelegation>> _deferredDelegations = {};

  void setExtensionProtocolVersion({required int extensionProtocolVersion}) {
    _extensionProtocolVersion = extensionProtocolVersion;
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
  String? sessionIdForToolCallId({required String? toolCallId}) {
    if (toolCallId == null || toolCallId.isEmpty) {
      return super.sessionIdForToolCallId(toolCallId: toolCallId);
    }
    final sessionIds = <String>{
      for (final entry in _deferredDelegations.entries)
        if (entry.value.containsKey(toolCallId)) entry.key,
    };
    switch (delegationTracker.lookupToolCallId(toolCallId: toolCallId)) {
      case DeepSeekDelegationFound(:final sessionId):
        sessionIds.add(sessionId);
      case DeepSeekDelegationAmbiguous():
        return null;
      case DeepSeekDelegationNotFound():
        break;
    }
    return switch (sessionIds.toList(growable: false)) {
      [final sessionId] => sessionId,
      [] => super.sessionIdForToolCallId(toolCallId: toolCallId),
      _ => null,
    };
  }

  /// Protocol v2 delays only the two exact delegation calls until either their
  /// correlated lifecycle start arrives (the child tile replaces the call) or
  /// a standard terminal update proves startup failed (the generic error card
  /// remains visible). This avoids both duplicate cards and invisible failures.
  @override
  List<BridgeSseEvent> map(AcpNotification notification) {
    if (_extensionProtocolVersion != DeepSeekAcpApi.extensionProtocolVersion ||
        notification.method != AcpMethods.sessionUpdate) {
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
    switch (update["sessionUpdate"]) {
      case "tool_call" when title != null && _isDelegationTitle(title):
        if (delegationStarted) {
          if (status != null && _isTerminalToolStatus(status)) {
            delegationTracker.markToolTerminal(parentSessionId: sessionId, toolCallId: toolCallId);
          }
          return const [];
        }
        if (status != null && _isTerminalToolStatus(status)) return super.map(notification);
        (_deferredDelegations[sessionId] ??= {}).putIfAbsent(
          toolCallId,
          () => _DeferredDeepSeekDelegation(call: notification),
        );
        return const [];
      case "tool_call_update":
        if (delegationStarted) {
          if (status != null && _isTerminalToolStatus(status)) {
            delegationTracker.markToolTerminal(parentSessionId: sessionId, toolCallId: toolCallId);
          }
          return const [];
        }
        final deferred = _deferredDelegations[sessionId]?[toolCallId];
        if (deferred == null) return super.map(notification);
        deferred.merge(notification: notification, update: update);
        if (status != null && _isTerminalToolStatus(status)) {
          return _flushDeferredDelegation(sessionId: sessionId, toolCallId: toolCallId);
        }
        return const [];
    }
    return super.map(notification);
  }

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    if (_extensionProtocolVersion == DeepSeekAcpApi.extensionProtocolVersion &&
        notification.method == DeepSeekAcpApi.subagentMethod) {
      return _mapSubagent(notification);
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

  List<BridgeSseEvent> _mapSubagent(AcpNotification notification) {
    try {
      final subagent = api.parseSubagentNotification(notification.params);
      return switch (subagent) {
        DeepSeekSubagentStartedDto() => _mapSubagentStarted(subagent),
        DeepSeekSubagentEndedDto() => _mapSubagentEnded(subagent),
      };
    } on Object catch (error, stackTrace) {
      final recoveryEvents = _recoverMalformedSubagent(notification: notification);
      Log.w("[deepseek] ignored malformed sub-agent notification", error, stackTrace);
      return recoveryEvents;
    }
  }

  List<BridgeSseEvent> _mapSubagentStarted(DeepSeekSubagentStartedDto notification) {
    _removeDeferredDelegation(sessionId: notification.sessionId, toolCallId: notification.toolCallId);
    delegationTracker.start(
      parentSessionId: notification.sessionId,
      toolCallId: notification.toolCallId,
      childSessionId: notification.childSessionId,
    );
    final events = mapChildSpawned(
      sessionId: notification.sessionId,
      spawn: subagentMapper.mapStarted(notification: notification),
    );
    setChildModel(
      childSessionId: notification.childSessionId,
      modelId: modelForSession(sessionId: notification.sessionId),
    );
    return events;
  }

  List<BridgeSseEvent> _recoverMalformedSubagent({required AcpNotification notification}) {
    final params = notification.params;
    if (params["kind"] == "started") {
      final sessionId = params["sessionId"];
      final toolCallId = params["toolCallId"];
      if (sessionId is String && toolCallId is String) {
        return _flushDeferredDelegation(sessionId: sessionId, toolCallId: toolCallId);
      }
      return const [];
    }
    if (params["kind"] == "ended") {
      final childSessionId = params["childSessionId"];
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
    if (deferred == null) return const [];
    return [
      ...super.map(deferred.call),
      if (deferred.mergedUpdate case final update?) ...super.map(update),
    ];
  }

  _DeferredDeepSeekDelegation? _removeDeferredDelegation({required String sessionId, required String toolCallId}) {
    final byToolCall = _deferredDelegations[sessionId];
    final deferred = byToolCall?.remove(toolCallId);
    if (byToolCall?.isEmpty ?? false) _deferredDelegations.remove(sessionId);
    return deferred;
  }

  static bool _isDelegationTitle(String title) => title == "subagent" || title == "subagent_fork";

  static bool _isTerminalToolStatus(String status) => status == "completed" || status == "failed";

  List<BridgeSseEvent> _mapSubagentEnded(DeepSeekSubagentEndedDto notification) {
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

final class _DeferredDeepSeekDelegation({required final AcpNotification call}) {
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
    for (final entry in update.entries) {
      if (_retainedUpdateKeys.contains(entry.key)) _mergedUpdate[entry.key] = entry.value;
    }
    _latestParams = notification.params;
  }

  AcpNotification? get mergedUpdate {
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
