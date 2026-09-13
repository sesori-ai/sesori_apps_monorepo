import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show StartAbortSignal;

import "managed_runtime_inventory.dart";
import "managed_runtime_path_authority.dart";

/// Refreshes an outdated managed runtime only when the PATH command is genuinely absent.
class ManagedRuntimeUpgradeService({
  required final ManagedRuntimePathAuthority _pathAuthority,
  required final ManagedRuntimeInventory _inventory,
}) {
  Future<bool> shouldUpgrade({
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    if (!_inventory.hasOutdatedVersion(stateDirectory: stateDirectory)) {
      return false;
    }

    return await _pathAuthority.isPathAbsent(
      environment: environment,
      abortSignal: StartAbortSignal.never,
    );
  }
}
