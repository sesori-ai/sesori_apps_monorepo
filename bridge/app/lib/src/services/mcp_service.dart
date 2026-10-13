import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mcp_repository.dart";
import "../repositories/models/mcp_control_result.dart";

/// Coordinates explicit native controls and authoritative inventory refresh.
class McpService({required final McpRepository _repository}) {
  final StreamController<McpInventoryRequest> _changes = StreamController.broadcast();
  Stream<McpInventoryRequest> get inventoryChanges => _changes.stream;

  Future<McpEntryActionResult> execute({required McpEntryActionRequest request}) async {
    final serverAction = switch (request.action) {
      final McpServerEntryAction action => action,
    };
    final target = serverAction.target;
    final action = serverAction.action;
    final result = await _repository.executeServerAction(pluginId: request.pluginId, target: target, action: action);
    switch (result) {
      case McpControlUnavailable(:final reason):
        return McpActionUnavailable(reason: reason);
      case McpControlFailed():
        return const McpActionFailed();
      case McpControlCompleted():
        _changes.add(McpInventoryRequest(pluginId: request.pluginId, scope: target.scope));
        final inventory = await _repository.getInventory(pluginId: request.pluginId, scope: target.scope);
        return McpActionCompleted(inventory: inventory);
    }
  }

  Future<void> dispose() => _changes.close();
}
