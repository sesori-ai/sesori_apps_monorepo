import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginStartAbortedException, StartAbortSignal;

import "managed_runtime_inventory.dart";
import "runtime_manifest.dart";
import "runtime_version.dart";
import "runtime_version_validator.dart";

enum ManagedRuntimeSource() {
  explicit,
  path,
  fallback,
  managed,
}

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
  required final ManagedRuntimeInventory _inventory,
}) {
  Future<ManagedRuntimeSelection> select({
    required String? explicitExecutablePath,
    required List<String> fallbackExecutableCandidates,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal abortSignal,
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

    // The pinned version is preferred, then any older managed version that is
    // still at or above the minimum — a bridge update that raises the target
    // leaves the previous install usable until its replacement is downloaded.
    final pinnedPath = _manifest.managedBinaryPath(
      stateDirectory: stateDirectory,
      version: _manifest.bundledVersion,
    );
    final pinnedProbe = await _probe(
      executable: pinnedPath,
      environment: environment,
      abortSignal: abortSignal,
    );
    if (pinnedProbe case RuntimeProbeReady(:final version) when _isSupported(version: version)) {
      return ManagedRuntimeManagedSelected(
        binaryPath: pinnedPath,
        version: version,
        rejectedPathVersion: pathVersion,
      );
    }
    final pinnedRejection = _rejectionFor(probe: pinnedProbe);

    ManagedRuntimeRejection? supersededRejection;
    for (final candidate in _supersededCandidates(stateDirectory: stateDirectory)) {
      final candidatePath = _manifest.managedBinaryPath(stateDirectory: stateDirectory, version: candidate);
      final probe = await _probe(
        executable: candidatePath,
        environment: environment,
        abortSignal: abortSignal,
      );
      if (probe case RuntimeProbeReady(:final version) when _isSupported(version: version)) {
        return ManagedRuntimeManagedSelected(
          binaryPath: candidatePath,
          version: version,
          rejectedPathVersion: pathVersion,
        );
      }
      final rejection = _rejectionFor(probe: probe);
      if (supersededRejection == null && !_isMissingRejection(rejection: rejection)) {
        supersededRejection = rejection;
      }
    }

    return ManagedRuntimeAutomaticNotSelected(
      primaryRejection: _isMissingRejection(rejection: pathRejection)
          ? fallbackRejection ?? pathRejection
          : pathRejection,
      managedRejection: _isMissingRejection(rejection: pinnedRejection)
          ? supersededRejection ?? pinnedRejection
          : pinnedRejection,
    );
  }

  /// Installed managed versions other than the pinned one that are still
  /// supported, newest first.
  Iterable<RuntimeVersion> _supersededCandidates({required String stateDirectory}) {
    final pinned = _manifest.bundledVersion.raw;
    return _inventory
        .installedVersions(stateDirectory: stateDirectory)
        .where((version) => version.raw != pinned && _isSupported(version: version));
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

  bool _isSupported({required RuntimeVersion version}) => version.compareTo(_manifest.minPathVersion) >= 0;

  void _throwIfAborted(StartAbortSignal abortSignal) {
    if (abortSignal.isAborted) throw const PluginStartAbortedException();
  }
}
