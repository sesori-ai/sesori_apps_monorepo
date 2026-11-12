import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../codex_app_server_client.dart";
import "../models/codex_correlatable_item_event_dto.dart";
import "../models/codex_sub_agent_item_dto.dart";
import "../models/codex_sub_agent_item_event_dto.dart";

/// Parses `item/started` and `item/completed` notifications carrying a
/// `subAgentActivity` item into [CodexSubAgentActivity]. Returns `null` for
/// every other notification, item type, or an item missing its identity.
class const CodexSubAgentItemParser() {
  CodexSubAgentActivity? parse({
    required CodexServerNotification notification,
  }) {
    final lifecycle = switch (notification.method) {
      "item/started" => CodexCorrelatableItemLifecycle.started,
      "item/completed" => CodexCorrelatableItemLifecycle.completed,
      _ => null,
    };
    if (lifecycle == null) return null;

    try {
      final params = CodexSubAgentItemParamsDto.fromJson(notification.params);
      final threadId = _usefulText(value: params.threadId);
      if (threadId == null) return null;
      switch (params.item) {
        case CodexSubAgentActivityItemDto(
          :final id,
          :final kind,
          :final agentThreadId,
          :final agentPath,
          :final model,
          :final reasoningEffort,
        ):
          final itemId = _usefulText(value: id);
          final childId = _usefulText(value: agentThreadId);
          if (itemId == null || childId == null) return null;
          return CodexSubAgentActivity(
            lifecycle: lifecycle,
            threadId: threadId,
            turnId: _usefulText(value: params.turnId),
            itemId: itemId,
            kind: kind,
            agentThreadId: childId,
            agentPath: _usefulText(value: agentPath),
            model: _usefulText(value: model),
            reasoningEffort: _usefulText(value: reasoningEffort),
          );
        case CodexUnknownSubAgentItemDto():
          return null;
      }
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] skipping malformed sub-agent item notification",
        error,
        stackTrace,
      );
      return null;
    }
  }

  String? _usefulText({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
