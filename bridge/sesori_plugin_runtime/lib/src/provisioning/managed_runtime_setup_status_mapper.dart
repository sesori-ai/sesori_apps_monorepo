import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        PluginSetupRuntimeMissing,
        PluginSetupRuntimeOutdated,
        PluginSetupStatus,
        PluginSetupUnavailable,
        PluginSetupUnknown;

import "managed_runtime_selection_service.dart";
import "runtime_manifest.dart";
import "runtime_version_validator.dart";

/// Maps a rejected runtime selection to the setup status a CLI harness shows,
/// with hints that differ between harnesses only by the runtime's name.
final class const ManagedRuntimeSetupStatusMapper() {
  PluginSetupStatus map({
    required RuntimeManifest manifest,
    required ManagedRuntimeNotSelected notSelected,
    required bool supportsManagedInstall,
  }) {
    final name = manifest.displayName;
    return switch (notSelected) {
      ManagedRuntimePathNotSelected(primaryRejection: ManagedRuntimeVersionRejected(:final version)) =>
        PluginSetupRuntimeOutdated(
          actionHint: "Update the global $name installation to ${manifest.minPathVersion.raw} or newer.",
          runtimeVersion: version.raw,
        ),
      ManagedRuntimePathNotSelected(primaryRejection: ManagedRuntimeProbeRejected()) => PluginSetupUnknown(
        actionHint: "The global $name installation could not be verified. Check it locally and retry setup detection.",
      ),
      ManagedRuntimeExplicitNotSelected(
        primaryRejection: ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()),
      ) =>
        PluginSetupRuntimeMissing(actionHint: "Fix the configured $name CLI path, then restart the bridge."),
      ManagedRuntimeExplicitNotSelected(primaryRejection: ManagedRuntimeVersionRejected()) => PluginSetupUnavailable(
        actionHint: "Update the configured $name CLI, then restart the bridge.",
      ),
      ManagedRuntimeExplicitNotSelected(primaryRejection: ManagedRuntimeProbeRejected()) => PluginSetupUnknown(
        actionHint: "$name setup could not be determined. Verify the configured CLI and retry.",
      ),
      ManagedRuntimeAutomaticNotSelected(:final primaryRejection, :final managedRejection)
          when _isUnknown(primaryRejection) || _isUnknown(managedRejection) =>
        PluginSetupUnknown(actionHint: "$name setup could not be determined. Verify the local CLI and retry."),
      ManagedRuntimeAutomaticNotSelected() => PluginSetupRuntimeMissing(
        actionHint: supportsManagedInstall
            ? "Install $name from Sesori, or install it locally and retry setup detection."
            : "Install $name locally, then retry setup detection.",
      ),
    };
  }

  bool _isUnknown(ManagedRuntimeRejection rejection) => switch (rejection) {
    ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) || ManagedRuntimeVersionRejected() => false,
    ManagedRuntimeProbeRejected() => true,
  };
}
