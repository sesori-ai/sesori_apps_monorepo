import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginStartAbortedException, StartAbortSignal;

import "runtime_manifest.dart";
import "runtime_version.dart";
import "runtime_version_validator.dart";

enum ManagedRuntimeSource() { explicit, path, fallback, managed }

enum ManagedRuntimeVersionPolicy() { minimum, exact }

sealed class const ManagedRuntimeRejection();

final class const ManagedRuntimeProbeRejected({required final RuntimeProbeFailure outcome})
    extends ManagedRuntimeRejection;

final class const ManagedRuntimeVersionRejected({required final RuntimeVersion version})
    extends ManagedRuntimeRejection;

sealed class const ManagedRuntimeSelection();

final class const ManagedRuntimeSelected({
  required final String binaryPath,
  required final ManagedRuntimeSource source,
  required final RuntimeVersion version,
  required final RuntimeVersion? rejectedPathVersion,
}) extends ManagedRuntimeSelection;

final class const ManagedRuntimeNotSelected({
  required final ManagedRuntimeRejection primaryRejection,
  required final ManagedRuntimeRejection? managedRejection,
}) extends ManagedRuntimeSelection;

/// Selects an existing runtime without installing or mutating runtime files.
class ManagedRuntimeSelectionService({
  required final RuntimeManifest _manifest,
  required final RuntimeVersionValidator _versionValidator,
}) {
  Future<ManagedRuntimeSelection> select({
    required String? explicitExecutablePath,
    required List<String> fallbackExecutableCandidates,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal abortSignal,
    required ManagedRuntimeVersionPolicy managedVersionPolicy,
  }) async {
    _throwIfAborted(abortSignal);
    if (explicitExecutablePath != null) {
      final probe = await _probe(
        executable: explicitExecutablePath,
        environment: environment,
        abortSignal: abortSignal,
      );
      return switch (probe) {
        RuntimeProbeReady(:final version) when version.compareTo(_manifest.minPathVersion) >= 0 =>
          ManagedRuntimeSelected(
            binaryPath: explicitExecutablePath,
            source: ManagedRuntimeSource.explicit,
            version: version,
            rejectedPathVersion: null,
          ),
        RuntimeProbeReady(:final version) => ManagedRuntimeNotSelected(
          primaryRejection: ManagedRuntimeVersionRejected(version: version),
          managedRejection: null,
        ),
        RuntimeProbeFailure() => ManagedRuntimeNotSelected(
          primaryRejection: ManagedRuntimeProbeRejected(outcome: probe),
          managedRejection: null,
        ),
      };
    }

    final pathProbe = await _probe(
      executable: _manifest.pathExecutableName,
      environment: environment,
      abortSignal: abortSignal,
    );
    final pathVersion = switch (pathProbe) {
      RuntimeProbeReady(:final version) => version,
      RuntimeProbeFailure() => null,
    };
    if (pathVersion != null && pathVersion.compareTo(_manifest.minPathVersion) >= 0) {
      return ManagedRuntimeSelected(
        binaryPath: _manifest.pathExecutableName,
        source: ManagedRuntimeSource.path,
        version: pathVersion,
        rejectedPathVersion: null,
      );
    }

    for (final candidate in fallbackExecutableCandidates) {
      final probe = await _probe(
        executable: candidate,
        environment: environment,
        abortSignal: abortSignal,
      );
      if (probe case RuntimeProbeReady(:final version) when version.compareTo(_manifest.minPathVersion) >= 0) {
        return ManagedRuntimeSelected(
          binaryPath: candidate,
          source: ManagedRuntimeSource.fallback,
          version: version,
          rejectedPathVersion: pathVersion,
        );
      }
    }

    final managedPath = _manifest.managedBinaryPath(stateDirectory: stateDirectory);
    final managedProbe = await _probe(
      executable: managedPath,
      environment: environment,
      abortSignal: abortSignal,
    );
    if (managedProbe case RuntimeProbeReady(:final version) when _acceptsManagedVersion(
      version: version,
      policy: managedVersionPolicy,
    )) {
      return ManagedRuntimeSelected(
        binaryPath: managedPath,
        source: ManagedRuntimeSource.managed,
        version: version,
        rejectedPathVersion: pathVersion,
      );
    }

    return ManagedRuntimeNotSelected(
      primaryRejection: _rejectionFor(probe: pathProbe),
      managedRejection: _rejectionFor(probe: managedProbe),
    );
  }

  Future<RuntimeProbeOutcome> _probe({
    required String executable,
    required Map<String, String> environment,
    required StartAbortSignal abortSignal,
  }) async {
    final outcome = await _versionValidator.probe(executable: executable, environment: environment);
    _throwIfAborted(abortSignal);
    return outcome;
  }

  ManagedRuntimeRejection _rejectionFor({required RuntimeProbeOutcome probe}) {
    return switch (probe) {
      RuntimeProbeReady(:final version) => ManagedRuntimeVersionRejected(version: version),
      RuntimeProbeFailure() => ManagedRuntimeProbeRejected(outcome: probe),
    };
  }

  bool _acceptsManagedVersion({required RuntimeVersion version, required ManagedRuntimeVersionPolicy policy}) {
    return switch (policy) {
      ManagedRuntimeVersionPolicy.minimum => version.compareTo(_manifest.minPathVersion) >= 0,
      ManagedRuntimeVersionPolicy.exact => version.compareTo(_manifest.bundledVersion) == 0,
    };
  }

  void _throwIfAborted(StartAbortSignal abortSignal) {
    if (abortSignal.isAborted) throw const PluginStartAbortedException();
  }
}
