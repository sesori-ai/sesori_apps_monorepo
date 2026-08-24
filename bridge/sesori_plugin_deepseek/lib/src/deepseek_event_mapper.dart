import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/deepseek_acp_api.dart";
import "api/models/deepseek_protocol_dto.dart";

class DeepSeekEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required final DeepSeekAcpApi api,
}) extends AcpEventMapper {
  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    if (notification.method != DeepSeekAcpApi.sessionStatusMethod) {
      return super.mapExtension(notification);
    }
    try {
      final status = api.parseSessionStatus(notification.params);
      return switch (status) {
        DeepSeekCompactionCompletedStatusDto() => [BridgeSseSessionCompacted(sessionID: status.sessionId)],
        DeepSeekRetryStatusDto() || DeepSeekCompactionStartedStatusDto() || DeepSeekWarningStatusDto() => const [],
      };
    } on Object catch (error, stackTrace) {
      Log.w("[deepseek] ignored malformed session status notification", error, stackTrace);
      return const [];
    }
  }
}
