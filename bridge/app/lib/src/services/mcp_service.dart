import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mcp_repository.dart";
import "../repositories/models/mcp_control_result.dart";
import "mcp_authentication_service.dart";

/// Coordinates explicit native controls and authoritative inventory refresh.
class McpService({
  required final McpRepository _repository,
  required final McpAuthenticationService _authenticationService,
}) {
  final StreamController<McpInventoryRequest> _changes = StreamController.broadcast();
  Stream<McpInventoryRequest> get inventoryChanges => _changes.stream;

  Future<McpEntryActionResult> execute({required McpEntryActionRequest request}) async {
    final target = request.action.target;
    final result = switch (request.action) {
      McpServerEntryAction(:final action) => await _repository.executeServerAction(
        pluginId: request.pluginId,
        target: target,
        action: action,
      ),
      McpForgetAuthenticationEntryAction() => await _authenticationService.forgetAuthentication(
        pluginId: request.pluginId,
        target: target,
      ),
    };
    switch (result) {
      case McpControlUnavailable(:final reason):
        return McpActionUnavailable(reason: reason);
      case McpControlFailed():
        return const McpActionFailed();
      case McpControlCompleted(:final effectScope):
        _changes.add(
          McpInventoryRequest(
            pluginId: request.pluginId,
            scope: switch (effectScope) {
              McpActionEffectScope.harness => const McpHarnessScope(),
              McpActionEffectScope.project ||
              McpActionEffectScope.session ||
              McpActionEffectScope.unknown => target.scope,
            },
          ),
        );
        final inventory = await _repository.getInventory(pluginId: request.pluginId, scope: target.scope);
        return McpActionCompleted(inventory: inventory);
    }
  }

  Future<void> dispose() => _changes.close();
}
