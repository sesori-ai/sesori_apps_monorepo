import "dart:async";
import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show CommandResult, HostProcessCommandExecutor, SemanticVersion, stripAnsi;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../grok_binary.dart";
import "../grok_identity.dart";
import "../grok_plugin_impl.dart";

const int _setupProbeOutputLimit = 64 * 1024;

/// Direct-CLI descriptor for the user-installed Grok Build runtime.
///
/// Sesori never installs or updates Grok. Setup and provisioning only run a
/// bounded `--version` probe, while authentication remains authoritative at the
/// ACP initialize handshake.
class const GrokPluginDescriptor() extends BridgePluginDescriptor {
  static const Duration _connectBudget = Duration(seconds: 15);
  static const Duration _versionProbeTimeout = Duration(seconds: 10);

  /// Oldest and latest stable Grok Build release validated for this plugin.
  static const String minVersion = "1.0.5";
  static const String targetVersion = "1.0.5";

  static final SemanticVersion _minimumVersion = SemanticVersion.parse(value: minVersion);

  /// Namespaced by the bridge CLI mapper as `--grok-bin`.
  static const String binOption = "bin";

  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the Grok Build CLI binary (grok)",
      defaultsTo: GrokBinary.defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
  ];

  @override
  String get id => GrokPluginIdentity.id;

  @override
  String get displayName => GrokPluginIdentity.displayName;

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.plugin;

  @override
  bool get supportsPromptAttachments => false;

  @override
  List<PluginOption> get options => cliOptions;

  String? _explicitBin({required PluginConfig config}) {
    final value = config.value(binOption)?.trim();
    if (value == null || value.isEmpty || value == GrokBinary.defaultBinary) return null;
    return value;
  }

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();

    final executablePath = _explicitBin(config: host.config) ?? GrokBinary.defaultBinary;
    final runtime = await _probeRuntime(
      executablePath: executablePath,
      processes: host.processes,
      environment: host.environment,
    );
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();

    switch (runtime) {
      case _GrokRuntimeReady():
        yield ProvisionReady(binaryPath: executablePath);
      case _GrokRuntimeMissing():
        yield const ProvisionFailed(
          message: "Grok Build is unavailable. Install it with xAI's official installer, then retry.",
        );
      case _GrokRuntimeOutdated():
        yield const ProvisionFailed(
          message: "The Grok Build version is too old. Update Grok, then retry.",
        );
      case _GrokRuntimeUnknown() || _GrokRuntimeUnrecognized():
        yield const ProvisionFailed(
          message: "The Grok Build runtime could not be verified. Check the local install, then retry.",
        );
    }
  }

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    final explicitBin = _explicitBin(config: config);
    final runtime = await _probeRuntime(
      executablePath: explicitBin ?? GrokBinary.defaultBinary,
      processes: processes,
      environment: environment,
    );

    return switch (runtime) {
      _GrokRuntimeReady(:final version) => PluginSetupReady.versioned(runtimeVersion: version),
      _GrokRuntimeMissing() => PluginSetupRuntimeMissing(
        actionHint: explicitBin == null
            ? "Install Grok Build with xAI's official installer, then restart the bridge."
            : "Fix the configured Grok Build binary path, then restart the bridge.",
      ),
      _GrokRuntimeOutdated() => PluginSetupUnavailable(
        actionHint: explicitBin == null
            ? "Update Grok Build with xAI's official installer, then restart the bridge."
            : "Update the configured Grok Build binary or fix `--grok-bin`, then restart the bridge.",
      ),
      _GrokRuntimeUnknown() || _GrokRuntimeUnrecognized() => const PluginSetupUnknown(
        actionHint: "Grok Build setup could not be verified. Run `grok --version` locally, then retry.",
      ),
    };
  }

  Future<_GrokRuntimeProbe> _probeRuntime({
    required String executablePath,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    final executor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    final CommandResult result;
    try {
      result = await executor.run(
        executablePath,
        const ["--version"],
        environment: environment,
        timeout: _versionProbeTimeout,
      );
    } on TimeoutException catch (error, stackTrace) {
      Log.w(
        "[grok] version probe '$executablePath --version' did not exit within "
        "${_versionProbeTimeout.inSeconds}s",
        error,
        stackTrace,
      );
      return const _GrokRuntimeUnknown();
    } on io.ProcessException catch (error, stackTrace) {
      if (error.errorCode == 2) return const _GrokRuntimeMissing();
      Log.w("[grok] version probe could not launch '$executablePath --version'", error, stackTrace);
      return const _GrokRuntimeUnknown();
    } on Object catch (error, stackTrace) {
      Log.w("[grok] version probe could not launch '$executablePath --version'", error, stackTrace);
      return const _GrokRuntimeUnknown();
    }

    if (result.exitCode != 0) {
      final stderr = result.stderr.toLowerCase();
      if (_isShellCommandNotFound(stderr: stderr)) return const _GrokRuntimeMissing();
      Log.w("[grok] version probe '$executablePath --version' exited with code ${result.exitCode}");
      return const _GrokRuntimeUnknown();
    }

    final parsed = _tryParseVersion(output: "${result.stdout}\n${result.stderr}");
    if (parsed == null) return const _GrokRuntimeUnrecognized();
    if (parsed.compareTo(_minimumVersion) < 0) {
      Log.w(
        "[grok] Grok Build ${parsed.toString()} is below the supported minimum ${_minimumVersion.toString()}",
      );
      return const _GrokRuntimeOutdated();
    }
    return _GrokRuntimeReady(version: parsed.toString());
  }

  bool _isShellCommandNotFound({required String stderr}) =>
      stderr.contains("is not recognized as an internal or external command") ||
      stderr.contains("is not recognized as the name of a cmdlet") ||
      stderr.contains("command not found");

  SemanticVersion? _tryParseVersion({required String output}) {
    final sanitized = stripAnsi(value: output);
    for (final rawLine in sanitized.split("\n")) {
      final tokens = rawLine.trim().split(RegExp(r"\s+"));
      if (tokens.isEmpty || tokens.first.toLowerCase() != GrokBinary.defaultBinary) continue;
      var versionIndex = 1;
      if (tokens.length > versionIndex && tokens[versionIndex].toLowerCase() == "version") versionIndex++;
      if (tokens.length <= versionIndex) continue;
      final token = tokens[versionIndex];
      final candidate = (token.startsWith("v") || token.startsWith("V")) ? token.substring(1) : token;
      final version = SemanticVersion.tryParse(value: candidate);
      if (version != null) return version;
    }
    return null;
  }

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();

    final binaryPath = _explicitBin(config: host.config) ?? host.provisionedRuntimePath ?? GrokBinary.defaultBinary;
    final cwd = io.Directory.current.path;
    final grok = GrokPlugin(
      binaryPath: binaryPath,
      launchDirectory: cwd,
      environment: host.environment,
      processFactory: hostProcessAcpFactory(
        processes: host.processes,
        environment: host.environment,
      ),
    );
    return await AcpBridgePlugin.start(plugin: grok, host: host, connectBudget: _connectBudget);
  }
}

sealed class const _GrokRuntimeProbe();

final class const _GrokRuntimeReady({required final String version}) extends _GrokRuntimeProbe;

final class const _GrokRuntimeMissing() extends _GrokRuntimeProbe;

final class const _GrokRuntimeOutdated() extends _GrokRuntimeProbe;

final class const _GrokRuntimeUnknown() extends _GrokRuntimeProbe;

final class const _GrokRuntimeUnrecognized() extends _GrokRuntimeProbe;
