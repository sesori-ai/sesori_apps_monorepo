import "dart:async";
import "dart:io" as io;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "codex_desktop_app_locator.dart";
import "codex_runtime_manifest.dart";

enum CodexRuntimeSource() { explicit, path, desktopApp, managed }

enum CodexRuntimeSelectionFailure() {
  executableMissing,
  probeTimedOut,
  probeFailed,
  nonZeroExit,
  unrecognizedVersion,
  unsupportedVersion,
}

sealed class const CodexRuntimeSelection();

final class const CodexRuntimeSelected({
    required this.binaryPath,
    required this.source,
    required this.version,
    required this.rejectedPathVersion,
  }) extends CodexRuntimeSelection {
  final String binaryPath;
  final CodexRuntimeSource source;
  final SemanticVersion version;
  final SemanticVersion? rejectedPathVersion;
}

final class const CodexRuntimeNotSelected({
    required this.failure,
    required this.hasExplicitBinary,
  }) extends CodexRuntimeSelection {
  final CodexRuntimeSelectionFailure failure;
  final bool hasExplicitBinary;
}

sealed class const _VersionProbe();

final class const _VersionProbeSucceeded({required this.version}) extends _VersionProbe {
  final SemanticVersion version;
}

final class const _VersionProbeFailed({required this.failure}) extends _VersionProbe {
  final CodexRuntimeSelectionFailure failure;
}

/// Selects the Codex executable shared by setup inspection, startup, and
/// interactive authentication without installing or mutating runtime files.
class CodexRuntimeSelectionService({
    required HostProcessService processes,
    required Duration versionProbeTimeout,
    required int? maxCapturedOutputCharactersPerStream,
    required List<String>? desktopAppCliCandidates,
  }) {
  this : _versionProbeTimeout = versionProbeTimeout,
       _desktopAppCliCandidates = desktopAppCliCandidates,
       _commandExecutor = HostProcessCommandExecutor(
         processes: processes,
         runInShell: io.Platform.isWindows,
         maxCapturedOutputCharactersPerStream: maxCapturedOutputCharactersPerStream,
       ),
       _versionValidator = RuntimeVersionValidator(
         commandExecutor: HostProcessCommandExecutor(
           processes: processes,
           runInShell: io.Platform.isWindows,
           maxCapturedOutputCharactersPerStream: maxCapturedOutputCharactersPerStream,
         ),
         runtimeId: const CodexRuntimeManifest().runtimeId,
         probeTimeout: versionProbeTimeout,
       );

  final Duration _versionProbeTimeout;
  final List<String>? _desktopAppCliCandidates;
  final CommandExecutor _commandExecutor;
  final RuntimeVersionValidator _versionValidator;

  static String? explicitBinary({required PluginConfig config}) {
    final value = config.value("bin")?.trim();
    if (value == null || value.isEmpty || value == "codex") return null;
    return value;
  }

  Future<CodexRuntimeSelection> select({
    required PluginConfig config,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal aborted,
  }) async {
    const manifest = CodexRuntimeManifest();
    final explicit = explicitBinary(config: config);
    if (explicit != null) {
      final probe = await _probe(
        executable: explicit,
        environment: environment,
        aborted: aborted,
      );
      return switch (probe) {
        _VersionProbeSucceeded(:final version) when version.compareTo(manifest.minPathVersion) >= 0 =>
          CodexRuntimeSelected(
            binaryPath: explicit,
            source: CodexRuntimeSource.explicit,
            version: version,
            rejectedPathVersion: null,
          ),
        _VersionProbeSucceeded() => const CodexRuntimeNotSelected(
          failure: CodexRuntimeSelectionFailure.unsupportedVersion,
          hasExplicitBinary: true,
        ),
        _VersionProbeFailed(:final failure) => CodexRuntimeNotSelected(
          failure: failure,
          hasExplicitBinary: true,
        ),
      };
    }

    final pathProbe = await _probe(
      executable: manifest.pathExecutableName,
      environment: environment,
      aborted: aborted,
    );
    final pathVersion = switch (pathProbe) {
      _VersionProbeSucceeded(:final version) => version,
      _VersionProbeFailed() => null,
    };
    if (pathVersion != null && pathVersion.compareTo(manifest.minPathVersion) >= 0) {
      return CodexRuntimeSelected(
        binaryPath: manifest.pathExecutableName,
        source: CodexRuntimeSource.path,
        version: pathVersion,
        rejectedPathVersion: null,
      );
    }

    for (final candidate in _desktopCandidates(environment: environment)) {
      final candidateProbe = await _probe(
        executable: candidate,
        environment: environment,
        aborted: aborted,
      );
      if (candidateProbe case _VersionProbeSucceeded(
        :final version,
      ) when version.compareTo(manifest.minPathVersion) >= 0) {
        return CodexRuntimeSelected(
          binaryPath: candidate,
          source: CodexRuntimeSource.desktopApp,
          version: version,
          rejectedPathVersion: pathVersion,
        );
      }
    }

    final managedPath = manifest.managedBinaryPath(stateDirectory: stateDirectory);
    final managedProbe = await _probe(
      executable: managedPath,
      environment: environment,
      aborted: aborted,
    );
    if (managedProbe case _VersionProbeSucceeded(:final version) when version.compareTo(manifest.bundledVersion) == 0) {
      return CodexRuntimeSelected(
        binaryPath: managedPath,
        source: CodexRuntimeSource.managed,
        version: version,
        rejectedPathVersion: pathVersion,
      );
    }

    final primaryFailure = switch (pathProbe) {
      _VersionProbeSucceeded() => CodexRuntimeSelectionFailure.unsupportedVersion,
      _VersionProbeFailed(:final failure) => failure,
    };
    return CodexRuntimeNotSelected(
      failure: primaryFailure,
      hasExplicitBinary: false,
    );
  }

  Stream<RuntimeProvisionProgress> provision({required PluginHost host}) async* {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();
    yield const ProvisionResolving();
    final result = await select(
      config: host.config,
      environment: host.environment,
      stateDirectory: host.stateDirectory,
      aborted: host.startAborted,
    );
    if (result case CodexRuntimeSelected(
      :final binaryPath,
      :final source,
      :final version,
      :final rejectedPathVersion,
    )) {
      const manifest = CodexRuntimeManifest();
      if (source == CodexRuntimeSource.managed && rejectedPathVersion != null) {
        yield ProvisionNotice(
          message:
              "Installed ${manifest.displayName} $rejectedPathVersion is older than the minimum supported "
              "${manifest.minPathVersion}; using the existing managed ${manifest.displayName} "
              "${manifest.bundledVersion} instead.",
        );
      }
      Log.i("[codex] using ${source.name} ${manifest.displayName} $version");
      yield ProvisionReady(binaryPath: binaryPath);
      return;
    }
    const manifest = CodexRuntimeManifest();
    yield ProvisionFailed(
      message:
          "No usable existing ${manifest.displayName} runtime was found. Install ${manifest.displayName} locally "
          "and retry: ${manifest.installDocsUrl}",
    );
  }

  Future<_VersionProbe> _probe({
    required String executable,
    required Map<String, String> environment,
    required StartAbortSignal aborted,
  }) async {
    if (aborted.isAborted) throw const PluginStartAbortedException();
    final CommandResult result;
    try {
      result = await _commandExecutor.run(
        executable,
        const ["--version"],
        environment: environment,
        timeout: _versionProbeTimeout,
      );
    } on io.ProcessException {
      _throwIfAborted(aborted);
      return const _VersionProbeFailed(
        failure: CodexRuntimeSelectionFailure.executableMissing,
      );
    } on TimeoutException {
      _throwIfAborted(aborted);
      return const _VersionProbeFailed(
        failure: CodexRuntimeSelectionFailure.probeTimedOut,
      );
    } on Object {
      _throwIfAborted(aborted);
      return const _VersionProbeFailed(
        failure: CodexRuntimeSelectionFailure.probeFailed,
      );
    }
    _throwIfAborted(aborted);
    if (result.exitCode != 0) {
      return const _VersionProbeFailed(
        failure: CodexRuntimeSelectionFailure.nonZeroExit,
      );
    }
    final version = _versionValidator.parseVersionOutput(output: result.stdout);
    if (version == null) {
      return const _VersionProbeFailed(
        failure: CodexRuntimeSelectionFailure.unrecognizedVersion,
      );
    }
    return _VersionProbeSucceeded(version: version);
  }

  void _throwIfAborted(StartAbortSignal aborted) {
    if (aborted.isAborted) throw const PluginStartAbortedException();
  }

  List<String> _desktopCandidates({required Map<String, String> environment}) {
    return _desktopAppCliCandidates ??
        codexDesktopAppCliCandidates(
          environment: environment,
          os: PlatformOs.fromOperatingSystem(
            operatingSystem: io.Platform.operatingSystem,
          ),
        );
  }
}
