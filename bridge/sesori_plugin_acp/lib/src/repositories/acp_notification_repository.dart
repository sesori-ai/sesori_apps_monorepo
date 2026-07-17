import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/acp_api_notification.dart";
import "models/acp_notification_record.dart";

class AcpNotificationRepository {
  const AcpNotificationRepository({
    required Stream<AcpApiNotification> apiNotifications,
  }) : _apiNotifications = apiNotifications;

  final Stream<AcpApiNotification> _apiNotifications;

  Stream<AcpNotificationRecord> get notifications => _apiNotifications.map(map);

  AcpNotificationRecord map(AcpApiNotification notification) {
    return switch (notification) {
      AcpApiExtensionNotification(:final method, :final sessionId) => AcpExtensionNotificationRecord(
        method: method,
        sessionId: sessionId,
      ),
      AcpApiSessionNotification(:final sessionId, :final update) => _mapUpdate(
        sessionId: sessionId,
        update: update,
      ),
    };
  }

  AcpSessionNotificationRecord _mapUpdate({
    required String sessionId,
    required AcpApiSessionUpdate update,
  }) {
    return switch (update) {
      AcpApiMessageChunkUpdate(:final role, :final messageId, :final text) => AcpMessageChunkRecord(
        sessionId: sessionId,
        role: switch (role) {
          AcpApiMessageChunkRole.user => AcpMessageChunkRole.user,
          AcpApiMessageChunkRole.assistant => AcpMessageChunkRole.assistant,
          AcpApiMessageChunkRole.thought => AcpMessageChunkRole.thought,
        },
        messageId: messageId,
        text: text,
      ),
      AcpApiToolUpdate(
        :final isInitial,
        :final toolCallId,
        :final kind,
        :final title,
        :final hasTitle,
        :final status,
        :final hasStatus,
        :final output,
        :final isFileMutation,
        :final hasDiff,
      ) =>
        AcpToolUpdateRecord(
          sessionId: sessionId,
          isInitial: isInitial,
          toolCallId: toolCallId,
          toolName: _toolName(kind: kind, title: title),
          hasKind: kind != null && kind.isNotEmpty,
          title: title,
          hasTitle: hasTitle,
          status: switch (status) {
            AcpApiToolStatus.pending => PluginToolStatus.pending,
            AcpApiToolStatus.inProgress => PluginToolStatus.running,
            AcpApiToolStatus.completed => PluginToolStatus.completed,
            AcpApiToolStatus.failed => PluginToolStatus.error,
            AcpApiToolStatus.unknown => PluginToolStatus.pending,
          },
          hasStatus: hasStatus,
          output: _truncateOutput(output),
          isFileMutation: isFileMutation,
          hasDiff: hasDiff,
        ),
      AcpApiPlanUpdate() => AcpPlanChangedRecord(sessionId: sessionId),
      AcpApiAvailableCommandsUpdate(:final commands) => AcpAvailableCommandsChangedRecord(
        sessionId: sessionId,
        commands: [
          for (final command in commands)
            PluginCommand(
              name: command.name,
              description: command.description,
              hints: [if (command.hint != null) command.hint!],
              provider: null,
              source: PluginCommandSource.command,
            ),
        ],
      ),
      AcpApiSessionInfoUpdate(:final hasTitle, :final title, :final updatedAtMs) => AcpSessionInfoChangedRecord(
        sessionId: sessionId,
        hasTitle: hasTitle,
        title: title,
        updatedAtMs: updatedAtMs,
      ),
      AcpApiIgnoredSessionUpdate() => AcpIgnoredSessionNotificationRecord(sessionId: sessionId),
    };
  }

  String _toolName({required String? kind, required String? title}) {
    if (kind != null && kind.isNotEmpty) return kind;
    if (title != null && title.isNotEmpty) return title;
    return "tool";
  }

  String? _truncateOutput(String? output) {
    if (output == null || output.isEmpty) return null;
    final runes = output.runes;
    return runes.length > maxToolOutputLength ? "${String.fromCharCodes(runes.take(maxToolOutputLength))}…" : output;
  }
}
