import "dart:async";
import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show CommandResult, HostProcessCommandExecutor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../cursor_binary.dart";
import "../cursor_plugin_impl.dart";

const int _setupProbeOutputLimit = 64 * 1024;

/// Builds the [CursorPlugin] (the live [BridgePluginApi]) for a resolved
/// binary. The production default constructs the real plugin wired to the
/// host-backed process factory; tests inject a fake to avoid spawning the
/// Cursor CLI.
typedef CursorPluginFactory =
    CursorPlugin Function({
      required String binaryPath,
      required String launchDirectory,
      required String? apiEndpoint,
      required AcpProcessFactory processFactory,
    });

CursorPlugin _defaultBuildPlugin({
  required String binaryPath,
  required String launchDirectory,
  required String? apiEndpoint,
  required AcpProcessFactory processFactory,
}) {
  return CursorPlugin(
    binaryPath: binaryPath,
    launchDirectory: launchDirectory,
    apiEndpoint: apiEndpoint,
    processFactory: processFactory,
  );
}

/// The const Cursor plugin descriptor.
///
/// Cursor drives a `cursor-agent acp` stdio subprocess over the generic ACP
/// machinery, so it needs no managed-runtime supervisor (no listening port to
/// reclaim, no ownership file). It declares its CLI surface, probes the
/// Cursor CLI binary for availability, and on [start] spawns the agent
/// through the [PluginHost] process seam and returns an [AcpBridgePlugin].
///
/// The optional constructor parameters are test seams; the registered instance
/// is `const CursorPluginDescriptor()`.
class CursorPluginDescriptor extends BridgePluginDescriptor {
  const CursorPluginDescriptor({
    CursorPluginFactory? buildPlugin,
    Duration connectBudget = const Duration(seconds: 15),
    Duration versionProbeTimeout = const Duration(seconds: 10),
  }) : _buildPlugin = buildPlugin,
       _connectBudget = connectBudget,
       _versionProbeTimeout = versionProbeTimeout;

  final CursorPluginFactory? _buildPlugin;
  final Duration _connectBudget;
  final Duration _versionProbeTimeout;

  /// Minimum Cursor CLI build the bridge supports. Earlier builds (e.g.
  /// `2026.05.28`) advertise the `acp` model picker and `session/load` but
  /// silently no-op model switching and history replay, so the experience is
  /// broken in ways the user can't see. Keep this target aligned with the
  /// latest verified Cursor CLI build.
  static const String minVersion = "2026.07.16";

  /// CLI option naming the Cursor CLI binary (path or PATH name). Declared
  /// as the bare local name — the bridge's [PluginCliOptionsMapper] namespaces
  /// it to the public `--cursor-bin` flag.
  static const String binOption = "bin";

  /// CLI option overriding the Cursor API endpoint (passed as `-e <endpoint>`).
  /// Bare local name; surfaces publicly as `--cursor-api-endpoint`.
  static const String apiEndpointOption = "api-endpoint";

  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the Cursor CLI binary (cursor-agent)",
      defaultsTo: CursorBinary.defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
    PluginValueOption(
      name: apiEndpointOption,
      help: "Override the Cursor API endpoint (passed to the Cursor CLI as -e <endpoint>)",
      defaultsTo: null,
      allowedValues: null,
      valueHelp: "url",
      validate: null,
    ),
  ];

  @override
  String get id => "cursor";

  @override
  String get displayName => "Cursor";

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  List<PluginOption> get options => cliOptions;

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    final executablePath = config.value(binOption) ?? CursorBinary.defaultBinary;
    final runtime = await _probeCursorRuntime(
      executablePath: executablePath,
      processes: processes,
      environment: environment,
    );
    switch (runtime.state) {
      case _CursorRuntimeProbeState.missing:
        return const PluginSetupRuntimeMissing(
          actionHint: "Install the Cursor CLI locally, then retry setup detection.",
        );
      case _CursorRuntimeProbeState.outdated:
        return const PluginSetupUnavailable(
          actionHint: "Update the Cursor CLI to a supported version, then retry setup detection.",
        );
      case _CursorRuntimeProbeState.unknown:
      case _CursorRuntimeProbeState.unrecognized:
        return const PluginSetupUnknown(
          actionHint: "Cursor setup could not be determined. Verify the local CLI and retry.",
        );
      case _CursorRuntimeProbeState.ready:
        break;
    }

    if (environment["CURSOR_API_KEY"]?.trim().isNotEmpty ?? false) {
      return const PluginSetupReady();
    }
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
    } on Object {
      return const PluginSetupUnknown(
        actionHint:
            "Cursor authentication could not be determined. Run the Cursor CLI status command locally and retry.",
      );
    }
    final statusOutput = _normalizedStatusOutput(statusResult);
    if (statusOutput.contains("not authenticated") ||
        statusOutput.contains("unauthenticated") ||
        statusOutput.contains("not logged in") ||
        statusOutput.contains("logged out")) {
      return const PluginSetupAuthenticationRequired(
        actionHint: "Log in with the Cursor CLI on this machine, then retry setup detection.",
      );
    }
    if (statusResult.exitCode == 0 && (statusOutput.contains("authenticated") || statusOutput.contains("logged in"))) {
      return const PluginSetupReady();
    }
    return const PluginSetupUnknown(
      actionHint: "Cursor authentication could not be determined. Run the Cursor CLI status command locally and retry.",
    );
  }

  /// Confirms the Cursor CLI is installed and runnable before the
  /// bridge commits to startup. Runs `<bin> --version`: exit 0 within
  /// [versionProbeTimeout] is available; a failed launch (not installed / not
  /// on PATH), a non-zero exit, or a timeout are unavailable. Never throws.
  @override
  Future<PluginAvailability> checkAvailability({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    final executablePath = config.value(binOption) ?? CursorBinary.defaultBinary;
    return _probeCursorBinary(
      executablePath: executablePath,
      processes: processes,
      environment: environment,
    );
  }

  Future<PluginAvailability> _probeCursorBinary({
    required String executablePath,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    final result = await _probeCursorRuntime(
      executablePath: executablePath,
      processes: processes,
      environment: environment,
    );
    return switch (result.state) {
      _CursorRuntimeProbeState.ready => const PluginAvailable(),
      _CursorRuntimeProbeState.missing => PluginUnavailable(
        message: _notInstalledMessage(executablePath: executablePath),
      ),
      _CursorRuntimeProbeState.outdated => PluginUnavailable(
        message: _outdatedMessage(executablePath: executablePath, version: result.version!),
      ),
      _CursorRuntimeProbeState.unknown => PluginUnavailable(
        message: _notWorkingMessage(executablePath: executablePath),
      ),
      // Explicit CLI/settings startup historically treated any exit-zero
      // version response as available. Setup inspection can stay conservative,
      // but this legacy availability gate must keep that behavior.
      _CursorRuntimeProbeState.unrecognized => const PluginAvailable(),
    };
  }

  Future<({_CursorRuntimeProbeState state, String? version})> _probeCursorRuntime({
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
    } on TimeoutException {
      // The probe launched but never exited (executor force-killed it):
      // installed but not answering.
      Log.d(
        "[cursor] availability probe '$executablePath --version' did not exit within "
        "${_versionProbeTimeout.inSeconds}s",
      );
      return (state: _CursorRuntimeProbeState.unknown, version: null);
    } on Object catch (error) {
      // Spawn could not launch — almost always ENOENT: not installed / not on PATH.
      Log.d("[cursor] availability probe could not launch '$executablePath --version': $error");
      return (state: _CursorRuntimeProbeState.missing, version: null);
    }

    if (result.exitCode != 0) {
      Log.d("[cursor] availability probe '$executablePath --version' exited with code ${result.exitCode}");
      return (state: _CursorRuntimeProbeState.unknown, version: null);
    }

    final parsed = _CalVer.tryParse(result.stdout);
    final minimum = _CalVer.tryParse(minVersion);
    if (parsed != null && minimum != null && parsed.compareTo(minimum) < 0) {
      final version = parsed.toString();
      Log.w("[cursor] Cursor CLI $version is below the supported minimum $minVersion");
      return (state: _CursorRuntimeProbeState.outdated, version: version);
    }
    if (parsed == null) {
      return (state: _CursorRuntimeProbeState.unrecognized, version: null);
    }
    final version = parsed.toString();
    Log.d("[cursor] available: '$executablePath --version' -> $version");
    return (state: _CursorRuntimeProbeState.ready, version: version);
  }

  String _normalizedStatusOutput(CommandResult result) {
    final combined = "${result.stdout}\n${result.stderr}";
    return combined.replaceAll(RegExp(r"\x1B\[[0-?]*[ -/]*[@-~]"), "").trim().toLowerCase();
  }

  String _notInstalledMessage({required String executablePath}) {
    return [
      "Cursor was not found — the Sesori bridge needs the Cursor CLI ($executablePath) to run.",
      "",
      "Verify it is installed:  $executablePath --version",
      "Install the Cursor CLI:  curl https://cursor.com/install -fsS | bash",
    ].join("\n");
  }

  String _notWorkingMessage({required String executablePath}) {
    return [
      'The Cursor CLI is installed but did not respond to "$executablePath --version".',
      "",
      "Re-check your install:   $executablePath --version",
      "Update the Cursor CLI:   $executablePath update",
    ].join("\n");
  }

  String _outdatedMessage({required String executablePath, required String version}) {
    final headline =
        "Cursor CLI $version is too old for the Sesori bridge — "
        "model switching and chat history need $minVersion or newer.";
    return [
      headline,
      "",
      "Update the Cursor CLI:   $executablePath update",
      "Then re-check:           $executablePath --version",
    ].join("\n");
  }

  @override
  Future<BridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final config = host.config;
    final binaryPath = config.value(binOption) ?? CursorBinary.defaultBinary;
    final rawEndpoint = config.value(apiEndpointOption)?.trim();
    final apiEndpoint = (rawEndpoint == null || rawEndpoint.isEmpty) ? null : rawEndpoint;

    // Route the agent subprocess through the host process seam rather than
    // io.Process.start, so the bridge owns identity capture and signalling.
    final processFactory = hostProcessAcpFactory(
      processes: host.processes,
      environment: host.environment,
    );

    final cursor = (_buildPlugin ?? _defaultBuildPlugin)(
      binaryPath: binaryPath,
      // The bridge seeds the launch directory as an always-present project;
      // the bridge itself owns all project/session persistence for this
      // derive-style plugin, so the plugin needs no store of its own.
      launchDirectory: io.Directory.current.path,
      apiEndpoint: apiEndpoint,
      processFactory: processFactory,
    );

    final plugin = AcpBridgePlugin(
      plugin: cursor,
      clock: host.clock,
      endpoint: "$binaryPath acp",
    );

    // Rolls back the spawned agent and surfaces the abort. Each eager phase
    // below (connect, catalog warm-up) is a boundary where an abort that arrived
    // meanwhile must undo the partial start rather than return a live plugin.
    Future<Never> rollbackAborted() async {
      try {
        await plugin.shutdown(budget: null);
      } on Object catch (error) {
        Log.e("[cursor] rollback after aborted start failed: $error");
      }
      throw const PluginStartAbortedException();
    }

    // Eagerly spawn the agent and run the ACP handshake (bounded), so the first
    // mobile request is fast and the status reflects reality. A timeout/failure
    // leaves the plugin degraded rather than failing the bridge.
    await plugin.connect(budget: _connectBudget, startAborted: host.startAborted);

    if (host.startAborted.isAborted) {
      await rollbackAborted();
    }

    // Eagerly warm the model/mode catalog so the mobile's first providers fetch
    // (which it caches) already has the full list. The catalog service owns the
    // total deadline; the lazy path in getProviders/getAgents is the fallback.
    await cursor.warmCatalog();

    // Warm-up can run for seconds: re-check so an abort observed during it still
    // rolls back instead of returning a started plugin.
    if (host.startAborted.isAborted) {
      await rollbackAborted();
    }

    return plugin;
  }
}

enum _CursorRuntimeProbeState { ready, missing, outdated, unknown, unrecognized }

/// A Cursor CLI calendar version (`YYYY.MM.DD`, the leading component of a
/// build string like `2026.06.15-18-00-12-6f5a2cf`). Parsed once into a typed
/// [Comparable] rather than comparing version strings ad hoc.
class _CalVer implements Comparable<_CalVer> {
  const _CalVer(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  /// Parses the leading `YYYY.MM.DD` from a Cursor CLI version/build string,
  /// or null if it does not start with that shape (caller fails open).
  static _CalVer? tryParse(String raw) {
    final match = RegExp(r"^\s*(\d{4})\.(\d{1,2})\.(\d{1,2})").firstMatch(raw);
    if (match == null) return null;
    return _CalVer(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(_CalVer other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    if (byMonth != 0) return byMonth;
    return day.compareTo(other.day);
  }

  @override
  String toString() => "$year.${month.toString().padLeft(2, "0")}.${day.toString().padLeft(2, "0")}";
}
