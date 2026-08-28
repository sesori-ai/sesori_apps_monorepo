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

sealed class const ManagedRuntimeSelected() extends ManagedRuntimeSelection {
  String get binaryPath;
  ManagedRuntimeSource get source;
  RuntimeVersion get version;
}

final class const ManagedRuntimeExplicitSelected({
  @override required final String binaryPath,
  @override required final RuntimeVersion version,
}) extends ManagedRuntimeSelected {
  @override
  ManagedRuntimeSource get source => ManagedRuntimeSource.explicit;
}

final class const ManagedRuntimePathSelected({
  @override required final String binaryPath,
  @override required final RuntimeVersion version,
}) extends ManagedRuntimeSelected {
  @override
  ManagedRuntimeSource get source => ManagedRuntimeSource.path;
}

final class const ManagedRuntimeFallbackSelected({
  @override required final String binaryPath,
  @override required final RuntimeVersion version,
  required final RuntimeVersion? rejectedPathVersion,
}) extends ManagedRuntimeSelected {
  @override
  ManagedRuntimeSource get source => ManagedRuntimeSource.fallback;
}

final class const ManagedRuntimeManagedSelected({
  @override required final String binaryPath,
  @override required final RuntimeVersion version,
  required final RuntimeVersion? rejectedPathVersion,
}) extends ManagedRuntimeSelected {
  @override
  ManagedRuntimeSource get source => ManagedRuntimeSource.managed;
}

sealed class const ManagedRuntimeNotSelected() extends ManagedRuntimeSelection {
  ManagedRuntimeRejection get primaryRejection;
}

final class const ManagedRuntimeExplicitNotSelected({
  @override required final ManagedRuntimeRejection primaryRejection,
}) extends ManagedRuntimeNotSelected;

final class const ManagedRuntimeAutomaticNotSelected({
  @override required final ManagedRuntimeRejection primaryRejection,
  required final ManagedRuntimeRejection managedRejection,
}) extends ManagedRuntimeNotSelected;

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
          ManagedRuntimeExplicitSelected(
            binaryPath: explicitExecutablePath,
            version: version,
          ),
        RuntimeProbeReady(:final version) => ManagedRuntimeExplicitNotSelected(
          primaryRejection: ManagedRuntimeVersionRejected(version: version),
        ),
        RuntimeProbeFailure() => ManagedRuntimeExplicitNotSelected(
          primaryRejection: ManagedRuntimeProbeRejected(outcome: probe),
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
      return ManagedRuntimePathSelected(
        binaryPath: _manifest.pathExecutableName,
        version: pathVersion,
      );
    }
    final pathRejection = _rejectionFor(probe: pathProbe);

    ManagedRuntimeRejection? fallbackRejection;
    for (final candidate in fallbackExecutableCandidates) {
      final probe = await _probe(
        executable: candidate,
        environment: environment,
        abortSignal: abortSignal,
      );
      if (probe case RuntimeProbeReady(:final version) when version.compareTo(_manifest.minPathVersion) >= 0) {
        return ManagedRuntimeFallbackSelected(
          binaryPath: candidate,
          version: version,
          rejectedPathVersion: pathVersion,
        );
      }
      final rejection = _rejectionFor(probe: probe);
      if (fallbackRejection == null && !_isMissingRejection(rejection: rejection)) {
        fallbackRejection = rejection;
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
      return ManagedRuntimeManagedSelected(
        binaryPath: managedPath,
        version: version,
        rejectedPathVersion: pathVersion,
      );
    }

    return ManagedRuntimeAutomaticNotSelected(
      primaryRejection: _isMissingRejection(rejection: pathRejection)
          ? fallbackRejection ?? pathRejection
          : pathRejection,
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

  bool _isMissingRejection({required ManagedRuntimeRejection rejection}) =>
      rejection is ManagedRuntimeProbeRejected && rejection.outcome is RuntimeProbeMissing;

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
