import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
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
    final target = request.action.entryTarget;
    final result = switch (request.action) {
      McpServerEntryAction(:final target, :final action) => await _repository.executeServerAction(
        pluginId: request.pluginId,
        target: target,
        action: action,
      ),
      McpForgetAuthenticationEntryAction(:final target) => await _authenticationService.forgetAuthentication(
        pluginId: request.pluginId,
        target: target,
      ),
      McpConnectorSetupEntryAction(offerTarget: final target) => await _repository.resolveConnectorSetup(
        pluginId: request.pluginId,
        target: target,
      ),
    };
    switch (result) {
      case McpControlUnavailable(:final reason):
        return McpActionUnavailable(reason: reason);
      case McpControlFailed():
        return const McpActionFailed();
      case McpControlExternalSetup(:final destination):
        if (destination.scheme != "https" ||
            !destination.hasAuthority ||
            destination.host.isEmpty ||
            destination.userInfo.isNotEmpty) {
          Log.w(
            "MCP connector setup destination rejected for ${request.pluginId} on $target: "
            "scheme=${destination.scheme}, host=${destination.host}",
          );
          return const McpActionUnavailable(reason: McpActionUnavailableReason.nativeConfigurationRequired);
        }
        return McpExternalSetup(setupUrl: destination.toString());
      case McpControlCompleted(:final effectScope):
        _changes.add(
          McpInventoryRequest(
            pluginId: request.pluginId,
            scope: switch (effectScope) {
              // Session views cannot correlate another session's project locally.
              // A project effect invalidates all views for this plugin.
              McpActionEffectScope.harness || McpActionEffectScope.project => const McpHarnessScope(),
              McpActionEffectScope.session || McpActionEffectScope.unknown => target.scope,
            },
          ),
        );
        final inventory = await _repository.getInventory(pluginId: request.pluginId, scope: target.scope);
        return McpActionCompleted(inventory: inventory);
    }
  }

  Future<void> dispose() => _changes.close();
}
