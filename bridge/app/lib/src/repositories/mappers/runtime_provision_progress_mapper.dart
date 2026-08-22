import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension RuntimeProvisionProgressMapping on RuntimeProvisionProgress {
  /// Maps a plugin's runtime-provisioning progress to the shared
  /// [ControlProvisionProgress] wire DTO the GUI renders in supervised mode.
  ///
  /// The source type's derived `fraction` getter is intentionally dropped — the
  /// wire DTO is pure data, and the GUI recomputes it from
  /// [ControlProvisionDownloading.totalBytes].
  ControlProvisionProgress toControlProvisionProgress() {
    return switch (this) {
      ProvisionResolving() => const ControlProvisionProgress.resolving(),
      ProvisionDownloading(:final receivedBytes, :final totalBytes) =>
        ControlProvisionProgress.downloading(receivedBytes: receivedBytes, totalBytes: totalBytes),
      ProvisionExtracting() => const ControlProvisionProgress.extracting(),
      ProvisionVerifying() => const ControlProvisionProgress.verifying(),
      ProvisionNotice(:final message) => ControlProvisionProgress.notice(message: message),
      ProvisionReady(:final binaryPath) => ControlProvisionProgress.ready(binaryPath: binaryPath),
      ProvisionFailed(:final message) => ControlProvisionProgress.failed(message: message),
    };
  }
}
