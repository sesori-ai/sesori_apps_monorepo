import "dart:async";
import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show CommandResult, HostProcessCommandExecutor, SemanticVersion;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../hermes_binary.dart";
import "../hermes_identity.dart";
import "../hermes_plugin_impl.dart";

const int _setupProbeOutputLimit = 64 * 1024;

/// The const Hermes Agent plugin descriptor.
///
/// Hermes drives a `hermes acp` stdio subprocess over the generic ACP
/// machinery, so it needs no managed-runtime supervisor and no managed
/// install (Hermes installs itself; the bridge resolves it on PATH). It
/// declares its CLI surface, probes the `hermes` CLI for availability and a
/// configured model/provider, and on [start] spawns the agent through the
/// [PluginHost] process seam and returns an [AcpBridgePlugin].
///
class const HermesPluginDescriptor() extends BridgePluginDescriptor {
  static const Duration _connectBudget = Duration(seconds: 15);
  static const Duration _versionProbeTimeout = Duration(seconds: 10);

  /// Oldest Hermes Agent release with the ACP behavior this plugin requires.
  static const String minVersion = "0.20.0";

  /// Latest stable Hermes Agent release validated against this plugin.
  static const String targetVersion = "0.20.4";

  static final SemanticVersion _minHermesVersion = SemanticVersion.parse(value: minVersion);

  /// CLI option naming the Hermes CLI binary (path or PATH name). Declared
  /// as the bare local name; the bridge's [PluginCliOptionsMapper] namespaces
  /// it to the public `--hermes-bin` flag.
  static const String binOption = "bin";

  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the Hermes CLI binary (hermes)",
      defaultsTo: HermesBinary.defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
  ];

  @override
  String get id => HermesPluginIdentity.id;

  @override
  String get displayName => HermesPluginIdentity.displayName;

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.plugin;

  /// Hermes advertises `prompt_capabilities.image` at initialize, so the
  /// phone attachment flow works against this backend as-is.
  @override
  bool get supportsPromptAttachments => true;

  @override
  List<PluginOption> get options => cliOptions;

  /// The explicit `--hermes-bin` override, or null when unset, empty, or left
  /// at the bare default (which means "resolve on PATH").
  String? _explicitBin({required PluginConfig config}) {
    final value = config.value(binOption)?.trim();
    if (value == null || value.isEmpty || value == HermesBinary.defaultBinary) return null;
    return value;
  }

  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();

    final executablePath = _explicitBin(config: host.config) ?? HermesBinary.defaultBinary;
    final runtime = await _probeHermesRuntime(
      executablePath: executablePath,
      processes: host.processes,
      environment: host.environment,
    );
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();

    switch (runtime) {
      case _HermesRuntimeReady():
        yield ProvisionReady(binaryPath: executablePath);
      case _HermesRuntimeMissing() || _HermesRuntimePreAcpInstall():
        yield const ProvisionFailed(
          message: "Hermes ACP is unavailable. Install or update Hermes, then retry.",
        );
      case _HermesRuntimeOutdated():
        yield const ProvisionFailed(
          message: "The Hermes Agent version is too old. Update Hermes, then retry.",
        );
      case _HermesRuntimeUnknown() || _HermesRuntimeUnrecognized():
        yield const ProvisionFailed(
          message: "The Hermes ACP runtime could not be verified. Check the local install, then retry.",
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
    final executablePath = explicitBin ?? HermesBinary.defaultBinary;
    final runtime = await _probeHermesRuntime(
      executablePath: executablePath,
      processes: processes,
      environment: environment,
    );

    final String runtimeVersion;
    switch (runtime) {
      case _HermesRuntimeMissing():
        return PluginSetupRuntimeMissing(
          actionHint: explicitBin != null
              ? "Fix the configured Hermes CLI path, then restart the bridge."
              : "Install Hermes Agent locally, then retry setup detection.",
        );
      case _HermesRuntimePreAcpInstall():
        return const PluginSetupRuntimeMissing(
          actionHint:
              "The installed Hermes does not expose the `acp` subcommand. Update Hermes, then retry setup detection.",
        );
      case _HermesRuntimeOutdated():
        return PluginSetupUnavailable(
          actionHint: explicitBin != null
              ? "The configured Hermes CLI path points to an unsupported version. Update that install or fix `--hermes-bin`."
              : "The installed Hermes Agent version is too old. Update Hermes and restart the bridge.",
        );
      case _HermesRuntimeUnrecognized() || _HermesRuntimeUnknown():
        return const PluginSetupUnknown(
          actionHint: "Hermes setup could not be determined. Verify the local install and retry.",
        );
      case _HermesRuntimeReady(:final version):
        runtimeVersion = version;
    }

    final statusResult = await _probeHermesStatus(
      executablePath: executablePath,
      processes: processes,
      environment: environment,
    );
    if (statusResult == null) {
      return PluginSetupUnknown.versioned(
        actionHint: "Hermes authentication could not be determined. Run `hermes status` locally and retry.",
        runtimeVersion: runtimeVersion,
      );
    }
    final (:model, :provider) = _statusValues(result: statusResult);
    if (_isConfiguredStatusValue(value: model) && _isConfiguredStatusValue(value: provider)) {
      return PluginSetupReady.versioned(runtimeVersion: runtimeVersion);
    }
    if (model != null || provider != null) {
      return PluginSetupAuthenticationRequired.versioned(
        actionHint: "Configure a model and provider with `hermes setup` or `hermes model` on this machine, then retry setup detection.",
        runtimeVersion: runtimeVersion,
      );
    }
    return PluginSetupUnknown.versioned(
      actionHint: "Hermes setup could not be determined. Run `hermes status` locally and retry.",
      runtimeVersion: runtimeVersion,
    );
  }

  /// Best-effort configuration probe. The ACP handshake remains the runtime
  /// authentication gate, while this command supplies the model picker label.
  Future<CommandResult?> _probeHermesStatus({
    required String executablePath,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    final executor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    try {
      final result = await executor.run(
        executablePath,
        const ["status"],
        environment: environment,
        timeout: _versionProbeTimeout,
      );
      if (result.exitCode != 0) {
        Log.w("[hermes] status probe '$executablePath status' exited with code ${result.exitCode}");
        return null;
      }
      return result;
    } on TimeoutException catch (error, stackTrace) {
      Log.w(
        "[hermes] status probe '$executablePath status' did not exit within ${_versionProbeTimeout.inSeconds}s",
        error,
        stackTrace,
      );
    } on Object catch (error, stackTrace) {
      Log.w("[hermes] status probe could not launch '$executablePath status'", error, stackTrace);
    }
    return null;
  }

  Future<_HermesRuntimeProbe> _probeHermesRuntime({
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
        const ["acp", "--version"],
        environment: environment,
        timeout: _versionProbeTimeout,
      );
    } on TimeoutException {
      // The probe launched but never exited (executor force-killed it):
      // installed but not answering.
      Log.d(
        "[hermes] availability probe '$executablePath acp --version' did not exit within "
        "${_versionProbeTimeout.inSeconds}s",
      );
      return const _HermesRuntimeUnknown();
    } on io.ProcessException catch (error, stackTrace) {
      // The host process seam reports spawn failures as ProcessException;
      // ENOENT (errorCode 2) means not installed / not on PATH.
      if (error.errorCode == 2) return const _HermesRuntimeMissing();
      Log.w("[hermes] availability probe could not launch '$executablePath acp --version'", error, stackTrace);
      return const _HermesRuntimeUnknown();
    } on Object catch (error, stackTrace) {
      // Any other spawn failure (host seam error, permission) is not proof of
      // a missing runtime; report unknown rather than a misleading hint.
      Log.w("[hermes] availability probe could not launch '$executablePath acp --version'", error, stackTrace);
      return const _HermesRuntimeUnknown();
    }

    if (result.exitCode != 0) {
      Log.d("[hermes] availability probe '$executablePath acp --version' exited with code ${result.exitCode}");
      // A pre-ACP install answers `--version` but rejects the `acp` subcommand
      // with a nonzero exit; surface that as missing with an update hint, not
      // as an unknown failure.
      final stderr = result.stderr.toLowerCase();
      if (_isShellCommandNotFound(stderr: stderr)) {
        return const _HermesRuntimeMissing();
      }
      if (stderr.contains("acp") && stderr.contains("invalid choice")) {
        return const _HermesRuntimePreAcpInstall();
      }
      return const _HermesRuntimeUnknown();
    }

    final parsed = _tryParseVersion(value: result.stdout.trim());
    if (parsed == null) {
      return const _HermesRuntimeUnrecognized();
    }
    if (parsed.compareTo(_minHermesVersion) < 0) {
      Log.w(
        "[hermes] Hermes Agent ${parsed.toString()} is below the supported minimum ${_minHermesVersion.toString()}",
      );
      return const _HermesRuntimeOutdated();
    }
    final version = parsed.toString();
    Log.d("[hermes] available: '$executablePath acp --version' -> $version");
    return _HermesRuntimeReady(version: version);
  }

  bool _isShellCommandNotFound({required String stderr}) =>
      stderr.contains("is not recognized as an internal or external command") ||
      stderr.contains("is not recognized as the name of a cmdlet") ||
      stderr.contains("command not found");

  SemanticVersion? _tryParseVersion({required String value}) {
    for (final rawToken in value.split(RegExp(r"\s+"))) {
      final token = rawToken.trim();
      final candidate = (token.startsWith("v") || token.startsWith("V")) ? token.substring(1) : token;
      final version = SemanticVersion.tryParse(value: candidate);
      if (version != null) return version;
    }
    return null;
  }

  ({String? model, String? provider}) _statusValues({required CommandResult result}) {
    final combined = "${result.stdout}\n${result.stderr}";
    final output = combined.replaceAll(RegExp(r"\x1B\[[0-?]*[ -/]*[@-~]"), "").trim();
    return (
      model: _statusValue(output: output, field: "model"),
      provider: _statusValue(output: output, field: "provider"),
    );
  }

  String? _statusValue({required String output, required String field}) {
    for (final rawLine in output.split("\n")) {
      final line = rawLine.trim();
      final prefix = "$field:";
      if (line.toLowerCase().startsWith(prefix)) return line.substring(prefix.length).trim();
    }
    return null;
  }

  bool _isConfiguredStatusValue({required String? value}) =>
      value != null &&
      value.isNotEmpty &&
      !RegExp(
        r"^(none|not set|unset|\(none\)|\(not set\)|✗|—|-)$",
        caseSensitive: false,
      ).hasMatch(value);

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final binaryPath = _explicitBin(config: host.config) ?? host.provisionedRuntimePath ?? HermesBinary.defaultBinary;
    final statusResult = await _probeHermesStatus(
      executablePath: binaryPath,
      processes: host.processes,
      environment: host.environment,
    );
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }
    final status = statusResult == null ? null : _statusValues(result: statusResult);
    final hasConfiguredModel =
        status != null &&
        _isConfiguredStatusValue(value: status.model) &&
        _isConfiguredStatusValue(value: status.provider);

    // Route the agent subprocess through the host process seam rather than
    // io.Process.start, so the bridge owns identity capture and signalling.
    final processFactory = hostProcessAcpFactory(
      processes: host.processes,
      environment: host.environment,
    );

    final hermes = HermesPlugin(
      binaryPath: binaryPath,
      // The bridge seeds the launch directory as an always-present project;
      // the bridge itself owns all project/session persistence for this
      // derive-style plugin, so the plugin needs no store of its own.
      launchDirectory: io.Directory.current.path,
      processFactory: processFactory,
      configuredModelId: hasConfiguredModel ? status.model : null,
      configuredProviderId: hasConfiguredModel ? status.provider : null,
    );

    final plugin = AcpBridgePlugin(
      plugin: hermes,
      clock: host.clock,
      endpoint: "$binaryPath acp",
    );

    // Rolls back the spawned agent and surfaces an abort that arrived while
    // connecting rather than returning a live plugin.
    Future<Never> rollbackAborted() async {
      try {
        await plugin.shutdown(budget: null);
      } on Object catch (error, stackTrace) {
        Log.e("[hermes] rollback after aborted start failed", error, stackTrace);
      }
      throw const PluginStartAbortedException();
    }

    // Eagerly spawn the agent and run the ACP handshake (bounded), so the
    // first mobile request is fast and the status reflects reality. A
    // timeout/failure leaves the plugin degraded rather than failing the
    // bridge.
    await plugin.connect(budget: _connectBudget, startAborted: host.startAborted);

    if (host.startAborted.isAborted) {
      await rollbackAborted();
    }

    return plugin;
  }
}

/// Outcome of the Hermes availability probe. Only [_HermesRuntimeReady]
/// carries the selected runtime version, so a version can never accompany a
/// rejected or unresolved runtime.
sealed class const _HermesRuntimeProbe();

final class const _HermesRuntimeReady({required final String version}) extends _HermesRuntimeProbe;

final class const _HermesRuntimeMissing() extends _HermesRuntimeProbe;

final class const _HermesRuntimePreAcpInstall() extends _HermesRuntimeProbe;

final class const _HermesRuntimeOutdated() extends _HermesRuntimeProbe;

final class const _HermesRuntimeUnknown() extends _HermesRuntimeProbe;

final class const _HermesRuntimeUnrecognized() extends _HermesRuntimeProbe;
