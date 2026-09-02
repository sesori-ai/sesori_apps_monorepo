import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../codex_app_server_client.dart";
import "../models/codex_correlatable_item_event_dto.dart";
import "../models/codex_sub_agent_item_dto.dart";
import "../models/codex_sub_agent_item_event_dto.dart";

/// Parses `item/started` and `item/completed` notifications carrying
/// multi-agent items into [CodexSubAgentItemEventDto]. Returns `null` for
/// every other notification, item type, or an item missing its identity.
class const CodexSubAgentItemParser() {
  CodexSubAgentItemEventDto? parse({
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
      final item = params.item;
      final threadId = _usefulText(value: params.threadId);
      final itemId = _usefulText(value: item.id);
      if (threadId == null || itemId == null) return null;
      final turnId = _usefulText(value: params.turnId);
      switch (item.type) {
        case CodexSubAgentItemType.collabAgentToolCall:
        case CodexSubAgentItemType.collabToolCall:
          return CodexCollabItem(
            lifecycle: lifecycle,
            threadId: threadId,
            turnId: turnId,
            itemId: itemId,
            tool: item.tool,
            status: item.status,
            senderThreadId: _usefulText(value: item.senderThreadId),
            receiverThreadIds: _receiverThreadIds(item: item),
            prompt: item.prompt,
            agentsStates: item.agentsStates,
          );
        case CodexSubAgentItemType.subAgentActivity:
          final agentThreadId = _usefulText(value: item.agentThreadId);
          if (agentThreadId == null) return null;
          return CodexSubAgentActivity(
            lifecycle: lifecycle,
            threadId: threadId,
            turnId: turnId,
            itemId: itemId,
            kind: item.kind,
            agentThreadId: agentThreadId,
            agentPath: _usefulText(value: item.agentPath),
          );
        case CodexSubAgentItemType.unknown:
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

  List<String> _receiverThreadIds({required CodexSubAgentItemDto item}) {
    final ids = <String>{};
    for (final candidate in [item.newThreadId, item.receiverThreadId, ...item.receiverThreadIds]) {
      final id = _usefulText(value: candidate);
      if (id != null) ids.add(id);
    }
    return List.unmodifiable(ids);
  }

  String? _usefulText({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
