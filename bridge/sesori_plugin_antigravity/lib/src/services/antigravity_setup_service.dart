import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_release.dart";
import "../models/antigravity_profile.dart";
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
      case AntigravityRuntimeCandidateMissing(:final source):
        if (source == AntigravityRuntimeSource.path) return _pathRuntimeUnknown(runtimeVersion: null);
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
        if (source == AntigravityRuntimeSource.path) return _pathRuntimeUnknown(runtimeVersion: null);
        return _invalidPair(source: source, managedInstallAvailable: managedInstallAvailable);
      case AntigravityRuntimeCandidateStorageFailed(:final source, :final cause, :final stackTrace):
        if (source != AntigravityRuntimeSource.path) {
          Log.w("[antigravity] setup runtime inspection failed", cause, stackTrace);
        }
        return source == AntigravityRuntimeSource.path
            ? _pathRuntimeUnknown(runtimeVersion: null)
            : const PluginSetupUnknown(
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
    final probe = await _runtimeVersions.probe(
      source: source,
      serverPath: serverPath,
      environment: probeEnvironment,
      timeout: timeout,
    );
    switch (probe) {
      case AntigravityRuntimeVersionProbeSucceeded(:final version):
        final supported = AntigravityRuntimeVersion.tryParse(buildLabel: AntigravityRelease.agentVersion);
        if (supported == null) throw StateError("The pinned Antigravity build label is invalid.");
        if (version.buildLabel == supported.buildLabel) {
          return _inspectProfile(
            source: source,
            geminiHome: geminiHome,
            runtimeVersion: version.buildLabel,
          );
        }
        final comparison = version.compareTo(supported);
        if (source == AntigravityRuntimeSource.path) {
          if (comparison < 0) return _pathRuntimeOutdated(runtimeVersion: version.buildLabel);
          if (comparison > 0) return _pathRuntimeNewer(runtimeVersion: version.buildLabel);
          return _pathRuntimeUnknown(runtimeVersion: version.buildLabel);
        }
        return _invalidPair(source: source, managedInstallAvailable: managedInstallAvailable);
      case AntigravityRuntimeVersionProbeRejected():
        return source == AntigravityRuntimeSource.path
            ? _pathRuntimeUnknown(runtimeVersion: null)
            : _invalidPair(source: source, managedInstallAvailable: managedInstallAvailable);
      case AntigravityRuntimeVersionProbeFailed():
        if (source == AntigravityRuntimeSource.path) return _pathRuntimeUnknown(runtimeVersion: null);
        if (source == AntigravityRuntimeSource.managed && managedInstallAvailable) {
          return const PluginSetupManagedRuntimeRepairRequired(
            actionHint:
                "The managed Antigravity runtime could not be verified. Reinstall Google's official proprietary "
                "runtime after reviewing Google's terms (https://antigravity.google/terms) and documentation "
                "(https://antigravity.google/docs/), or replace the local pair.",
          );
        }
        return const PluginSetupUnknown(
          actionHint: "Antigravity setup could not be determined. Check the local runtime pair and retry.",
        );
    }
  }

  PluginSetupStatus _inspectProfile({
    required AntigravityRuntimeSource source,
    required String geminiHome,
    required String runtimeVersion,
  }) {
    try {
      return switch (_profile.inspect(geminiHome: geminiHome)) {
        AntigravityAuthenticationHint.tokenPresent => PluginSetupReady.versioned(runtimeVersion: runtimeVersion),
        AntigravityAuthenticationHint.authenticationRequired => PluginSetupAuthenticationRequired.versioned(
          actionHint:
              "Authenticate Antigravity from a current Sesori mobile or desktop app. Older clients must update.",
          runtimeVersion: runtimeVersion,
        ),
      };
    } on Object catch (error, stackTrace) {
      Log.w("[antigravity] setup profile inspection failed", error, stackTrace);
      const actionHint = "Antigravity setup could not be determined. Check the isolated profile and retry.";
      return source == AntigravityRuntimeSource.path
          ? PluginSetupAuthoritativeRuntimeUnknown(
              actionHint: actionHint,
              runtimeVersion: runtimeVersion,
            )
          : PluginSetupUnknown.versioned(
              actionHint: actionHint,
              runtimeVersion: runtimeVersion,
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

  PluginSetupAuthoritativeRuntimeUnknown _pathRuntimeNewer({required String runtimeVersion}) =>
      PluginSetupAuthoritativeRuntimeUnknown(
        actionHint: "The global Antigravity runtime is newer than the supported build. Update Sesori, then retry.",
        runtimeVersion: runtimeVersion,
      );

  PluginSetupAuthoritativeRuntimeUnknown _pathRuntimeUnknown({required String? runtimeVersion}) =>
      PluginSetupAuthoritativeRuntimeUnknown(
        actionHint: "The global Antigravity runtime could not be verified. Check its installation, then retry.",
        runtimeVersion: runtimeVersion,
      );
}
