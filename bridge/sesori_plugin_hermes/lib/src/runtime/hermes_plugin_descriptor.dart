import "dart:async";
import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show CommandResult, HostProcessCommandExecutor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../hermes_binary.dart";
import "../hermes_identity.dart";
import "../hermes_plugin_impl.dart";
import "hermes_runtime_manifest.dart";

const int _setupProbeOutputLimit = 64 * 1024;

/// Builds the live [HermesPlugin] for a resolved binary. The production
/// default constructs the real plugin wired to the host-backed process
/// factory; tests inject a fake to avoid spawning the Hermes CLI.
typedef HermesPluginFactory = HermesPlugin Function({
  required String binaryPath,
  required String launchDirectory,
  required AcpProcessFactory processFactory,
});

HermesPlugin _defaultBuildPlugin({
  required String binaryPath,
  required String launchDirectory,
  required AcpProcessFactory processFactory,
}) {
  return HermesPlugin(
    binaryPath: binaryPath,
    launchDirectory: launchDirectory,
    processFactory: processFactory,
  );
}

/// The const Hermes Agent plugin descriptor.
///
/// Hermes drives a `hermes acp` stdio subprocess over the generic ACP
/// machinery, so it needs no managed-runtime supervisor and no managed
/// install (Hermes installs itself; the bridge resolves it on PATH). It
/// declares its CLI surface, probes the `hermes` CLI for availability and a
/// configured model/provider, and on [start] spawns the agent through the
/// [PluginHost] process seam and returns an [AcpBridgePlugin].
///
/// The optional constructor parameters are test seams; the registered instance
/// is `const HermesPluginDescriptor()`.
class const HermesPluginDescriptor({
  final HermesPluginFactory? _buildPlugin,
  final Duration _connectBudget = const Duration(seconds: 15),
  final Duration _versionProbeTimeout = const Duration(seconds: 10),
}) extends BridgePluginDescriptor {
  /// CLI option naming the Hermes CLI binary (path or PATH name). Declared
  /// as the bare local name — the bridge's [PluginCliOptionsMapper] namespaces
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
  String get id => HermesPluginIdentity.pluginId;

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
  String? _explicitBin(PluginConfig config) {
    final value = config.value(binOption)?.trim();
    if (value == null || value.isEmpty || value == HermesBinary.defaultBinary) return null;
    return value;
  }

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    final explicitBin = _explicitBin(config);
    final executablePath = explicitBin ?? HermesBinary.defaultBinary;
    final runtime = await _probeHermesRuntime(
      executablePath: executablePath,
      processes: processes,
      environment: environment,
    );

    switch (runtime.state) {
      case _HermesRuntimeProbeState.missing:
        return PluginSetupRuntimeMissing(
          actionHint: explicitBin != null
              ? "Fix the configured Hermes CLI path, then restart the bridge."
              : runtime.preAcpInstall
                  ? "The installed Hermes does not expose the `acp` subcommand. Update Hermes, then retry setup detection."
                  : "Install Hermes Agent locally, then retry setup detection.",
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
    // Best-effort — the true gate is the ACP handshake at connect time, which
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
      Log.w("[hermes] status probe '$executablePath status' did not exit within ${_versionProbeTimeout.inSeconds}s", error, stackTrace);
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
    final statusOutput = _normalizedStatusOutput(statusResult);
    // Output is the source of truth: a nonzero exit with a real `Model:` value
    // still means the model is configured (the ACP handshake is the actual
    // auth gate at connect time); the exit code only breaks ties when the
    // output is ambiguous.
    if (_statusIndicatesConfigured(statusOutput)) {
      return const PluginSetupReady();
    }
    if (_statusIndicatesUnconfigured(statusOutput)) {
      return const PluginSetupAuthenticationRequired(
        actionHint: "Configure a model and provider with `hermes setup` or `hermes model` on this machine, then retry setup detection.",
      );
    }
    return const PluginSetupUnknown(
      actionHint: "Hermes setup could not be determined. Run `hermes status` locally and retry.",
    );
  }

  Future<({_HermesRuntimeProbeState state, String? version, bool preAcpInstall})> _probeHermesRuntime({
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
      return (state: _HermesRuntimeProbeState.unknown, version: null, preAcpInstall: false);
    } on io.ProcessException catch (error) {
      // The host process seam reports spawn failures as ProcessException;
      // ENOENT (errorCode 2) means not installed / not on PATH.
      Log.d("[hermes] availability probe could not launch '$executablePath acp --version' (${error.errorCode})");
      return (state: _HermesRuntimeProbeState.missing, version: null, preAcpInstall: false);
    } on Object catch (error, stackTrace) {
      // Any other spawn failure (host seam error, permission) is not proof of
      // a missing runtime — report unknown rather than a misleading hint.
      Log.w("[hermes] availability probe could not launch '$executablePath acp --version'", error, stackTrace);
      return (state: _HermesRuntimeProbeState.unknown, version: null, preAcpInstall: false);
    }

    if (result.exitCode != 0) {
      Log.d("[hermes] availability probe '$executablePath acp --version' exited with code ${result.exitCode}");
      // A pre-ACP install answers `--version` but rejects the `acp` subcommand
      // with a nonzero exit; surface that as missing with an update hint, not
      // as an unknown failure.
      if (result.stderr.contains("acp") && (result.stderr.contains("invalid choice") || result.stderr.contains("error"))) {
        return (state: _HermesRuntimeProbeState.missing, version: null, preAcpInstall: true);
      }
      return (state: _HermesRuntimeProbeState.unknown, version: null, preAcpInstall: false);
    }

    final parsed = HermesRuntimeManifest.tryParseVersion(value: result.stdout.trim());
    if (parsed == null) {
      return (state: _HermesRuntimeProbeState.unrecognized, version: null, preAcpInstall: false);
    }
    if (parsed.compareTo(HermesRuntimeManifest.minAcpVersion) < 0) {
      Log.w("[hermes] Hermes ACP adapter ${parsed.toString()} is below the supported minimum ${HermesRuntimeManifest.minAcpVersion.toString()}");
      return (state: _HermesRuntimeProbeState.outdated, version: parsed.toString(), preAcpInstall: false);
    }
    final version = parsed.toString();
    Log.d("[hermes] available: '$executablePath acp --version' -> $version");
    return (state: _HermesRuntimeProbeState.ready, version: version, preAcpInstall: false);
  }

  String _normalizedStatusOutput(CommandResult result) {
    final combined = "${result.stdout}\n${result.stderr}";
    return combined.replaceAll(RegExp(r"\x1B\[[0-?]*[ -/]*[@-~]"), "").trim().toLowerCase();
  }

  /// True when `hermes status` reports an actual model selection (the
  /// "Environment" block's `Model:` line holds a real value).
  bool _statusIndicatesConfigured(String output) {
    for (final rawLine in output.split("\n")) {
      final line = rawLine.trim();
      if (!line.startsWith("model:")) continue;
      final value = line.substring("model:".length).trim();
      return value.isNotEmpty &&
          !RegExp(
            r"^(none|not set|unset|\(none\)|\(not set\)|✗|—|-)$",
            caseSensitive: false,
          ).hasMatch(value);
    }
    return false;
  }

  /// True when `hermes status` explicitly reports no model selection.
  bool _statusIndicatesUnconfigured(String output) {
    for (final rawLine in output.split("\n")) {
      final line = rawLine.trim();
      if (!line.startsWith("model:")) continue;
      final value = line.substring("model:".length).trim();
      return RegExp(
        r"^(none|not set|unset|\(none\)|\(not set\)|✗|—|-)$",
        caseSensitive: false,
      ).hasMatch(value);
    }
    return false;
  }

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final binaryPath = _explicitBin(host.config) ?? HermesBinary.defaultBinary;

    // Route the agent subprocess through the host process seam rather than
    // io.Process.start, so the bridge owns identity capture and signalling.
    final processFactory = hostProcessAcpFactory(
      processes: host.processes,
      environment: host.environment,
    );

    final hermes = (_buildPlugin ?? _defaultBuildPlugin)(
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

enum _HermesRuntimeProbeState() { ready, missing, outdated, unknown, unrecognized }
