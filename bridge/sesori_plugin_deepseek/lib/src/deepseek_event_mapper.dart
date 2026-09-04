import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/deepseek_acp_api.dart";
import "api/models/deepseek_protocol_dto.dart";
import "deepseek_message_time_parser.dart";
import "repositories/mappers/deepseek_subagent_mapper.dart";

class DeepSeekEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
  required final DeepSeekAcpApi api,
  required final DeepSeekMessageTimeParser messageTimeParser,
  required final DeepSeekSubagentMapper subagentMapper,
}) extends AcpEventMapper {
  @override
  PluginMessageTime? messageTimeForNotification({required AcpNotification notification}) =>
      messageTimeParser.parse(notification.params);

  @override
  PluginMessageTime localUserMessageTime({required int createdAtMs}) =>
      PluginMessageTime(created: createdAtMs, completed: null);

  var _extensionProtocolVersion = 1;

  void setExtensionProtocolVersion({required int extensionProtocolVersion}) {
    _extensionProtocolVersion = extensionProtocolVersion;
  }

  @override
  bool isSubagentSpawnToolCall({required Map<String, dynamic> update}) =>
      _extensionProtocolVersion == DeepSeekAcpApi.extensionProtocolVersion &&
      (update["title"] == "subagent" || update["title"] == "subagent_fork");

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    if (notification.method == DeepSeekAcpApi.subagentMethod) {
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
        DeepSeekSubagentStartedDto() => mapChildSpawned(
          sessionId: subagent.sessionId,
          spawn: subagentMapper.mapStarted(notification: subagent),
        ),
        DeepSeekSubagentEndedDto() => _mapSubagentEnded(subagent),
      };
    } on Object catch (error, stackTrace) {
      Log.w("[deepseek] ignored malformed sub-agent notification", error, stackTrace);
      return const [];
    }
  }

  List<BridgeSseEvent> _mapSubagentEnded(DeepSeekSubagentEndedDto notification) {
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
