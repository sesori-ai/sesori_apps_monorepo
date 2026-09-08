import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/antigravity_profile.dart";
import "../models/antigravity_runtime_resolution.dart";
import "antigravity_profile_inspection_service.dart";
import "antigravity_runtime_service.dart";

/// Combines inert runtime-pair and isolated-profile inspection.
class AntigravitySetupService({
  required final AntigravityRuntimeService _runtime,
  required final AntigravityProfileInspectionService _profile,
}) {
  PluginSetupStatus inspect({
    required String? explicitServerPath,
    required String? managedServerPath,
    required Map<String, String> environment,
    required PlatformTarget target,
    required String geminiHome,
    required bool managedInstallAvailable,
  }) {
    final runtime = _runtime.inspect(
      explicitServerPath: explicitServerPath,
      managedServerPath: managedServerPath,
      pathEnvironment: environment,
      target: target,
    );
    switch (runtime) {
      case AntigravityRuntimeCandidateFound():
        return switch (_profile.inspect(geminiHome: geminiHome)) {
          AntigravityAuthenticationHint.tokenPresent => const PluginSetupReady(),
          AntigravityAuthenticationHint.authenticationRequired => const PluginSetupAuthenticationRequired(
            actionHint:
                "Authenticate Antigravity from a current Sesori mobile or desktop app. Older clients must update.",
          ),
        };
      case AntigravityRuntimeCandidateMissing(:final source):
        return PluginSetupRuntimeMissing(
          actionHint: source == AntigravityRuntimeSource.explicit
              ? "Fix the configured Antigravity runtime pair, then restart the bridge."
              : managedInstallAvailable
              ? "Install Google's official proprietary Antigravity runtime from Sesori after reviewing Google's "
                    "terms (https://antigravity.google/terms) and documentation (https://antigravity.google/docs/), "
                    "or provide the official pair locally."
              : "Provide the official Antigravity ACP runtime pair, then retry setup detection.",
        );
      case AntigravityRuntimeCandidateRejected(:final source):
        return PluginSetupUnavailable(
          actionHint: source == AntigravityRuntimeSource.explicit
              ? "Fix the configured Antigravity runtime pair, then restart the bridge."
              : managedInstallAvailable
              ? "The discovered Antigravity runtime pair is invalid. Install Google's official proprietary runtime "
                    "after reviewing Google's terms (https://antigravity.google/terms) and documentation "
                    "(https://antigravity.google/docs/), or replace the local pair."
              : "The discovered Antigravity runtime pair is invalid. Replace it with the official pair.",
        );
      case AntigravityRuntimeCandidateUnsupported():
        return const PluginSetupUnavailable(
          actionHint: "Google does not publish the Antigravity ACP runtime for this platform.",
        );
      case AntigravityRuntimeCandidateStorageFailed(:final cause, :final stackTrace):
        Log.w("[antigravity] setup runtime inspection failed", cause, stackTrace);
        return const PluginSetupUnknown(
          actionHint: "Antigravity setup could not be determined. Check the local runtime pair and retry.",
        );
    }
  }
}
