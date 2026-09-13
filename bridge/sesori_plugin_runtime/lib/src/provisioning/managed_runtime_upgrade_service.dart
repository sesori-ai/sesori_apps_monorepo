import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show StartAbortSignal;

import "managed_runtime_inventory.dart";
import "managed_runtime_path_authority.dart";

/// Decides whether Sesori may refresh an existing managed runtime at startup.
///
/// A PATH command is authoritative whenever it answers or fails ambiguously.
/// Managed-runtime mutation is allowed only when the PATH command is genuinely
/// absent and an obsolete Sesori-managed version already exists.
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
