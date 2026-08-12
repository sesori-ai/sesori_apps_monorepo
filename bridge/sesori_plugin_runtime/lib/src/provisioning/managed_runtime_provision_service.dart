import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginHost,
        PluginStartAbortedException,
        ProvisionFailed,
        ProvisionNotice,
        ProvisionReady,
        ProvisionResolving,
        RuntimeProvisionProgress;

import "runtime_manifest.dart";
import "runtime_version_validator.dart";

/// Resolves an already-installed runtime without downloading or mutating it.
///
/// Precedence is a sufficiently recent PATH runtime, then the first
/// sufficiently recent fallback executable candidate (e.g. a CLI bundled by a
/// backend's desktop app, enumerated by the owning plugin), then the pinned
/// managed runtime when that exact version is already present and runnable.
class ManagedRuntimeProvisionService({
  required final RuntimeManifest _manifest,
  required final RuntimeVersionValidator _versionValidator,

  /// Absolute executable paths probed after PATH, in preference order. Each is
  /// version-gated like a PATH install; a missing path fails its probe
  /// harmlessly.
  required final List<String> _fallbackExecutableCandidates,
}) {
  Stream<RuntimeProvisionProgress> provision({required PluginHost host}) async* {
    _throwIfAborted(host);
    yield const ProvisionResolving();
    _throwIfAborted(host);

    final id = _manifest.runtimeId;
    final name = _manifest.displayName;
    final minimum = _manifest.minPathVersion;
    final bundled = _manifest.bundledVersion;
    final pathVersion = await _versionValidator.detectVersion(
      executable: _manifest.pathExecutableName,
      environment: host.environment,
    );
    _throwIfAborted(host);
    if (pathVersion != null && pathVersion.compareTo(minimum) >= 0) {
      Log.i("[$id] using PATH $name $pathVersion (>= minimum $minimum)");
      yield ProvisionReady(binaryPath: _manifest.pathExecutableName);
      return;
    }

    for (final candidate in _fallbackExecutableCandidates) {
      final candidateVersion = await _versionValidator.detectVersion(
        executable: candidate,
        environment: host.environment,
      );
      _throwIfAborted(host);
      if (candidateVersion != null && candidateVersion.compareTo(minimum) >= 0) {
        Log.i("[$id] using $name $candidateVersion at $candidate (>= minimum $minimum)");
        yield ProvisionReady(binaryPath: candidate);
        return;
      }
    }

    final managedBinaryPath = _manifest.managedBinaryPath(stateDirectory: host.stateDirectory);
    final managedVersion = await _versionValidator.detectVersion(
      executable: managedBinaryPath,
      environment: host.environment,
    );
    _throwIfAborted(host);
    if (managedVersion != null && managedVersion.compareTo(bundled) == 0) {
      if (pathVersion != null) {
        yield ProvisionNotice(
          message:
              "Installed $name $pathVersion is older than the minimum supported $minimum; "
              "using the existing managed $name $bundled instead.",
        );
      }
      Log.i("[$id] using existing managed $name $bundled");
      yield ProvisionReady(binaryPath: managedBinaryPath);
      return;
    }

    yield ProvisionFailed(
      message:
          "No usable existing $name runtime was found. Install $name locally and retry: ${_manifest.installDocsUrl}",
    );
  }

  void _throwIfAborted(PluginHost host) {
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }
  }
}
