import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "../provisioning/managed_runtime_cleaner.dart";
import "../provisioning/managed_runtime_install_service.dart";
import "../provisioning/managed_runtime_inventory.dart";
import "../provisioning/managed_runtime_provision_service.dart";
import "../provisioning/managed_runtime_selection_service.dart";
import "../provisioning/runtime_install_service.dart";
import "../provisioning/runtime_manifest.dart";
import "../provisioning/runtime_version_validator.dart";

/// Assembles the managed-runtime object graphs every managed plugin shares.
///
/// Stateless: it constructs a graph from the collaborators a descriptor already
/// owns and returns the service through its ordinary constructor. It never
/// forwards install calls and owns no resource, so descriptors keep their
/// operation-local HTTP client lifetime, executor limits, probe timeouts and
/// per-plugin asset resolution.
class const ManagedRuntimeComposition() {
  /// The checksum, extractor, installer and cleaner graph behind
  /// [ManagedRuntimeInstallService], keyed to [manifest]'s runtime id.
  ManagedRuntimeInstallService createInstaller({
    required RuntimeManifest manifest,
    required CommandExecutor commandExecutor,
    required BinaryDownloadClient downloadClient,
    required RuntimeVersionValidator versionValidator,
    required RuntimeAssetResolver assetResolver,
  }) {
    return ManagedRuntimeInstallService(
      manifest: manifest,
      versionValidator: versionValidator,
      installService: RuntimeInstallService(
        downloadClient: downloadClient,
        checksumValidator: ChecksumValidator(),
        archiveExtractor: ArchiveExtractor(commandExecutor: commandExecutor),
        commandExecutor: commandExecutor,
        runtimeId: manifest.runtimeId,
      ),
      cleaner: ManagedRuntimeCleaner(runtimeId: manifest.runtimeId),
      assetResolver: assetResolver,
    );
  }

  /// The selection graph behind [ManagedRuntimeProvisionService]: PATH and
  /// [fallbackExecutableCandidates] probed through [versionValidator], then the
  /// managed inventory for [manifest].
  ManagedRuntimeProvisionService createProvisioner({
    required RuntimeManifest manifest,
    required RuntimeVersionValidator versionValidator,
    required List<String> fallbackExecutableCandidates,
  }) {
    return ManagedRuntimeProvisionService(
      manifest: manifest,
      selectionService: ManagedRuntimeSelectionService(
        manifest: manifest,
        versionValidator: versionValidator,
        inventory: ManagedRuntimeInventory(manifest: manifest),
      ),
      fallbackExecutableCandidates: fallbackExecutableCandidates,
    );
  }
}
