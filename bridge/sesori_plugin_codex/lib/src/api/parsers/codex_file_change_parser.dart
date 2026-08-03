import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../codex_app_server_client.dart";
import "../models/codex_correlatable_item_event_dto.dart";
import "../models/codex_file_change_dto.dart";

class CodexFileChangeParser {
  const CodexFileChangeParser();

  CodexFileChangeEventDto? parse({
    required CodexServerNotification notification,
  }) {
    final lifecycle = switch (notification.method) {
      "item/started" => CodexCorrelatableItemLifecycle.started,
      "item/completed" => CodexCorrelatableItemLifecycle.completed,
      _ => null,
    };
    if (lifecycle == null) return null;

    try {
      final params = CodexFileChangeParamsDto.fromJson(notification.params);
      final item = params.item;
      if (item.type != CodexFileChangeItemType.fileChange) return null;
      final threadId = _usefulText(value: params.threadId);
      final itemId = _usefulText(value: item.id);
      if (threadId == null || itemId == null) return null;
      return CodexFileChangeEventDto(
        lifecycle: lifecycle,
        threadId: threadId,
        turnId: _usefulText(value: params.turnId),
        itemId: itemId,
        status: item.status,
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] skipping malformed file-change notification",
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
