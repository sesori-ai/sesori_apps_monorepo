import "dart:async";
import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show CommandResult, HostProcessCommandExecutor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../hermes_binary.dart";
import "../hermes_identity.dart";
import "../hermes_plugin_impl.dart";
import "hermes_runtime_manifest.dart";

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
    if (_explicitBin(config: host.config) != null) return;
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();

    final state = await _probeHermesRuntime(
      executablePath: HermesBinary.defaultBinary,
      processes: host.processes,
      environment: host.environment,
    );
    if (host.startAborted.isAborted) throw const PluginStartAbortedException();

    switch (state) {
      case _HermesRuntimeProbeState.ready:
        yield const ProvisionReady(binaryPath: HermesBinary.defaultBinary);
      case _HermesRuntimeProbeState.missing || _HermesRuntimeProbeState.preAcpInstall:
        yield const ProvisionFailed(
          message: "Hermes ACP is unavailable. Install or update Hermes, then retry.",
        );
      case _HermesRuntimeProbeState.outdated:
        yield const ProvisionFailed(
          message: "The Hermes ACP adapter is too old. Update Hermes, then retry.",
        );
      case _HermesRuntimeProbeState.unknown || _HermesRuntimeProbeState.unrecognized:
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

    switch (runtime) {
      case _HermesRuntimeProbeState.missing:
        return PluginSetupRuntimeMissing(
          actionHint: explicitBin != null
              ? "Fix the configured Hermes CLI path, then restart the bridge."
              : "Install Hermes Agent locally, then retry setup detection.",
        );
      case _HermesRuntimeProbeState.preAcpInstall:
        return const PluginSetupRuntimeMissing(
          actionHint:
              "The installed Hermes does not expose the `acp` subcommand. Update Hermes, then retry setup detection.",
        );
      case _HermesRuntimeProbeState.outdated:
        return const PluginSetupUnavailable(
          actionHint: "The installed Hermes ACP adapter is too old. Update Hermes and restart the bridge.",
        );
      case _HermesRuntimeProbeState.unrecognized:
      case _HermesRuntimeProbeState.unknown:
        return const PluginSetupUnknown(
          actionHint: "Hermes setup could not be determined. Verify the local install and retry.",
        );
      case _HermesRuntimeProbeState.ready:
        break;
    }

    // Auth probe: `hermes status` reports the configured model/provider.
    // Best-effort: the true gate is the ACP handshake at connect time, which
    // degrades the plugin without failing the bridge.
    final executor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    final CommandResult statusResult;
    try {
      statusResult = await executor.run(
        executablePath,
        const ["status"],
        environment: environment,
        timeout: _versionProbeTimeout,
      );
    } on TimeoutException catch (error, stackTrace) {
      Log.w(
        "[hermes] status probe '$executablePath status' did not exit within ${_versionProbeTimeout.inSeconds}s",
        error,
        stackTrace,
      );
      return const PluginSetupUnknown(
        actionHint: "Hermes authentication could not be determined. Run `hermes status` locally and retry.",
      );
    } on Object catch (error, stackTrace) {
      Log.w("[hermes] status probe could not launch '$executablePath status'", error, stackTrace);
      return const PluginSetupUnknown(
        actionHint: "Hermes authentication could not be determined. Run `hermes status` locally and retry.",
      );
    }
    if (statusResult.exitCode != 0) {
      Log.w("[hermes] status probe '$executablePath status' exited with code ${statusResult.exitCode}");
    }
    final statusOutput = _normalizedStatusOutput(result: statusResult);
    final model = _statusValue(output: statusOutput, field: "model");
    final provider = _statusValue(output: statusOutput, field: "provider");
    // Output is authoritative even on a nonzero exit: Hermes can report valid
    // configuration alongside another status failure, while the ACP handshake
    // remains the actual authentication gate at connect time.
    if (_isConfiguredStatusValue(value: model) && _isConfiguredStatusValue(value: provider)) {
      return const PluginSetupReady();
    }
    if (model != null || provider != null) {
      return const PluginSetupAuthenticationRequired(
        actionHint: "Configure a model and provider with `hermes setup` or `hermes model` on this machine, then retry setup detection.",
      );
    }
    return const PluginSetupUnknown(
      actionHint: "Hermes setup could not be determined. Run `hermes status` locally and retry.",
    );
  }

  Future<_HermesRuntimeProbeState> _probeHermesRuntime({
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
      return _HermesRuntimeProbeState.unknown;
    } on io.ProcessException catch (error, stackTrace) {
      // The host process seam reports spawn failures as ProcessException;
      // ENOENT (errorCode 2) means not installed / not on PATH.
      if (error.errorCode == 2) return _HermesRuntimeProbeState.missing;
      Log.w("[hermes] availability probe could not launch '$executablePath acp --version'", error, stackTrace);
      return _HermesRuntimeProbeState.unknown;
    } on Object catch (error, stackTrace) {
      // Any other spawn failure (host seam error, permission) is not proof of
      // a missing runtime; report unknown rather than a misleading hint.
      Log.w("[hermes] availability probe could not launch '$executablePath acp --version'", error, stackTrace);
      return _HermesRuntimeProbeState.unknown;
    }

    if (result.exitCode != 0) {
      Log.d("[hermes] availability probe '$executablePath acp --version' exited with code ${result.exitCode}");
      // A pre-ACP install answers `--version` but rejects the `acp` subcommand
      // with a nonzero exit; surface that as missing with an update hint, not
      // as an unknown failure.
      if (result.stderr.contains("acp") &&
          (result.stderr.contains("invalid choice") || result.stderr.contains("error"))) {
        return _HermesRuntimeProbeState.preAcpInstall;
      }
      return _HermesRuntimeProbeState.unknown;
    }

    final parsed = HermesRuntimeManifest.tryParseVersion(value: result.stdout.trim());
    if (parsed == null) {
      return _HermesRuntimeProbeState.unrecognized;
    }
    if (parsed.compareTo(HermesRuntimeManifest.minAcpVersion) < 0) {
      Log.w(
        "[hermes] Hermes ACP adapter ${parsed.toString()} is below the supported minimum ${HermesRuntimeManifest.minAcpVersion.toString()}",
      );
      return _HermesRuntimeProbeState.outdated;
    }
    final version = parsed.toString();
    Log.d("[hermes] available: '$executablePath acp --version' -> $version");
    return _HermesRuntimeProbeState.ready;
  }

  String _normalizedStatusOutput({required CommandResult result}) {
    final combined = "${result.stdout}\n${result.stderr}";
    return combined.replaceAll(RegExp(r"\x1B\[[0-?]*[ -/]*[@-~]"), "").trim().toLowerCase();
  }

  String? _statusValue({required String output, required String field}) {
    for (final rawLine in output.split("\n")) {
      final line = rawLine.trim();
      final prefix = "$field:";
      if (line.startsWith(prefix)) return line.substring(prefix.length).trim();
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

enum _HermesRuntimeProbeState() {
  ready,
  missing,
  preAcpInstall,
  outdated,
  unknown,
  unrecognized;
}
