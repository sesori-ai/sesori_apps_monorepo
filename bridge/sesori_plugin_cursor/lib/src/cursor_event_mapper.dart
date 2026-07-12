import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Cursor's event mapper: the standard ACP `session/update` handling from
/// [AcpEventMapper] plus Cursor's `cursor/*` notification extensions.
class CursorEventMapper extends AcpEventMapper {
  CursorEventMapper({required super.launchDirectory, required super.pluginId}) : super(agentId: "cursor");

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    switch (notification.method) {
      case "cursor/update_todos":
        final sessionId = notification.params["sessionId"] as String?;
        if (sessionId == null || sessionId.isEmpty) return const [];
        return [BridgeSseTodoUpdated(sessionID: sessionId)];
    }
    // cursor/task, cursor/generate_image and other extension notifications
    // have no sesori analog — dropped.
    return const [];
  }
}
