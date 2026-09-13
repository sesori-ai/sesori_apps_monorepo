import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_release.dart";
import "../models/antigravity_profile.dart";
import "../models/antigravity_runtime_pair.dart";
import "../models/antigravity_runtime_resolution.dart";
import "../models/antigravity_runtime_version.dart";
import "../repositories/antigravity_runtime_version_repository.dart";
import "antigravity_profile_inspection_service.dart";
import "antigravity_runtime_service.dart";

/// Combines bounded runtime validation with read-only isolated-profile
/// inspection. Any PATH runtime evidence is authoritative over managed copies.
class AntigravitySetupService({
  required final AntigravityRuntimeService _runtime,
  required final AntigravityRuntimeVersionRepository _runtimeVersions,
  required final AntigravityProfileInspectionService _profile,
}) {
  Future<PluginSetupStatus> inspect({
    required String? explicitServerPath,
    required String? managedServerPath,
    required Map<String, String> pathEnvironment,
    required Map<String, String> probeEnvironment,
    required PlatformTarget target,
    required String geminiHome,
    required bool managedInstallAvailable,
    required Duration timeout,
  }) async {
    final runtime = _runtime.inspect(
      explicitServerPath: explicitServerPath,
      managedServerPath: managedServerPath,
      pathEnvironment: pathEnvironment,
      target: target,
    );
    switch (runtime) {
      case AntigravityRuntimeCandidateFound(:final source, :final pair):
        return await _inspectFoundRuntime(
          source: source,
          serverPath: pair.serverPath,
          probeEnvironment: probeEnvironment,
          geminiHome: geminiHome,
          managedInstallAvailable: managedInstallAvailable,
          timeout: timeout,
        );
      case AntigravityRuntimeCandidateMissing(:final source, :final component):
        if (source == AntigravityRuntimeSource.path && component != AntigravityRuntimeComponent.server) {
          return _pathRuntimeUnknown();
        }
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
        if (source == AntigravityRuntimeSource.path) return _pathRuntimeUnknown();
        return _invalidPair(source: source, managedInstallAvailable: managedInstallAvailable);
      case AntigravityRuntimeCandidateStorageFailed(:final source, :final cause, :final stackTrace):
        Log.w("[antigravity] setup runtime inspection failed", cause, stackTrace);
        if (source == AntigravityRuntimeSource.path) return _pathRuntimeUnknown();
        return const PluginSetupUnknown(
          actionHint: "Antigravity setup could not be determined. Check the local runtime pair and retry.",
        );
      case AntigravityRuntimeCandidateUnsupported():
        return const PluginSetupUnavailable(
          actionHint: "Google does not publish the Antigravity ACP runtime for this platform.",
        );
    }
  }

  Future<PluginSetupStatus> _inspectFoundRuntime({
    required AntigravityRuntimeSource source,
    required String serverPath,
    required Map<String, String> probeEnvironment,
    required String geminiHome,
    required bool managedInstallAvailable,
    required Duration timeout,
  }) async {
    final AntigravityRuntimeVersionProbeResult probe;
    try {
      probe = await _runtimeVersions.probe(
        source: source,
        serverPath: serverPath,
        environment: probeEnvironment,
        timeout: timeout,
      );
    } on Object catch (error, stackTrace) {
      Log.w("[antigravity] setup runtime version probe failed", error, stackTrace);
      if (source == AntigravityRuntimeSource.path) return _pathRuntimeUnknown();
      return const PluginSetupUnknown(
        actionHint: "Antigravity setup could not be determined. Check the local runtime pair and retry.",
      );
    }
    switch (probe) {
      case AntigravityRuntimeVersionProbeCompleted(:final command, :final version):
        if (command.exitCode != 0 || version == null) {
          Log.w("[antigravity] setup runtime version probe returned no usable build label", command);
          if (source == AntigravityRuntimeSource.path) return _pathRuntimeUnknown();
          return _invalidPair(source: source, managedInstallAvailable: managedInstallAvailable);
        }
        if (version != AntigravityRelease.agentVersion) {
          Log.w("[antigravity] setup runtime version probe rejected the selected pair", command);
          if (source == AntigravityRuntimeSource.path) return _pathRuntimeOutdated(runtimeVersion: version);
          return _invalidPair(source: source, managedInstallAvailable: managedInstallAvailable);
        }
      case AntigravityRuntimeVersionProbeFailed(:final cause, :final stackTrace):
        Log.w("[antigravity] setup runtime version probe failed", cause, stackTrace);
        if (source == AntigravityRuntimeSource.path) return _pathRuntimeUnknown();
        return const PluginSetupUnknown(
          actionHint: "Antigravity setup could not be determined. Check the local runtime pair and retry.",
        );
    }
    try {
      return switch (_profile.inspect(geminiHome: geminiHome)) {
        AntigravityAuthenticationHint.tokenPresent => const PluginSetupReady.versioned(
          runtimeVersion: AntigravityRelease.agentVersion,
        ),
        AntigravityAuthenticationHint.authenticationRequired => const PluginSetupAuthenticationRequired.versioned(
          actionHint:
              "Authenticate Antigravity from a current Sesori mobile or desktop app. Older clients must update.",
          runtimeVersion: AntigravityRelease.agentVersion,
        ),
      };
    } on Object catch (error, stackTrace) {
      Log.w("[antigravity] setup profile inspection failed", error, stackTrace);
      return const PluginSetupUnknown.versioned(
        actionHint: "Antigravity setup could not be determined. Check the isolated profile and retry.",
        runtimeVersion: AntigravityRelease.agentVersion,
      );
    }
  }

  PluginSetupStatus _invalidPair({
    required AntigravityRuntimeSource source,
    required bool managedInstallAvailable,
  }) => PluginSetupUnavailable(
    actionHint: source == AntigravityRuntimeSource.explicit
        ? "Fix the configured Antigravity runtime pair, then restart the bridge."
        : managedInstallAvailable
        ? "The managed Antigravity runtime pair is invalid. Reinstall Google's official proprietary runtime "
              "after reviewing Google's terms (https://antigravity.google/terms) and documentation "
              "(https://antigravity.google/docs/), or replace the local pair."
        : "The discovered Antigravity runtime pair is invalid. Replace it with the official pair.",
  );

  PluginSetupRuntimeOutdated _pathRuntimeOutdated({required String runtimeVersion}) => PluginSetupRuntimeOutdated(
    actionHint:
        "The global Antigravity runtime is incompatible. Update it using Google's installation method, then retry.",
    runtimeVersion: runtimeVersion,
  );

  PluginSetupUnknown _pathRuntimeUnknown() => const PluginSetupUnknown(
    actionHint: "The global Antigravity runtime could not be verified. Check its installation, then retry.",
  );
}
