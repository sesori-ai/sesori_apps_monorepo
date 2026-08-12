import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../codex_app_server_client.dart";
import "../models/codex_command_execution_dto.dart";
import "../models/codex_correlatable_item_event_dto.dart";

class const CodexCommandExecutionParser() {
  CodexCommandExecutionEventDto? parse({
    required CodexServerNotification notification,
  }) {
    final lifecycle = switch (notification.method) {
      "item/started" => CodexCorrelatableItemLifecycle.started,
      "item/completed" => CodexCorrelatableItemLifecycle.completed,
      _ => null,
    };
    if (lifecycle == null) return null;

    try {
      final params = CodexCommandExecutionParamsDto.fromJson(
        notification.params,
      );
      final item = params.item;
      if (item.type != CodexCommandExecutionItemType.commandExecution) {
        return null;
      }
      final threadId = _usefulText(value: params.threadId);
      final itemId = _usefulText(value: item.id);
      if (threadId == null || itemId == null) return null;
      return CodexCommandExecutionEventDto(
        lifecycle: lifecycle,
        threadId: threadId,
        turnId: _usefulText(value: params.turnId),
        itemId: itemId,
        command: item.command,
        aggregatedOutput: item.aggregatedOutput,
        status: item.status,
        exitCode: item.exitCode,
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] skipping malformed command-execution notification",
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
