import "dart:async";
import "dart:convert";
import "dart:io" as io;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../cursor_binary.dart";
import "../cursor_plugin_impl.dart";

/// Builds the [CursorPlugin] (the live [BridgePluginApi]) for a resolved
/// binary. The production default constructs the real plugin wired to the
/// host-backed process factory; tests inject a fake to avoid spawning
/// `cursor-agent`.
typedef CursorPluginFactory =
    CursorPlugin Function({
      required String binaryPath,
      required String projectCwd,
      required String? apiEndpoint,
      required AcpProcessFactory processFactory,
      required HostJsonStore? projectStore,
    });

CursorPlugin _defaultBuildPlugin({
  required String binaryPath,
  required String projectCwd,
  required String? apiEndpoint,
  required AcpProcessFactory processFactory,
  required HostJsonStore? projectStore,
}) {
  return CursorPlugin(
    binaryPath: binaryPath,
    projectCwd: projectCwd,
    apiEndpoint: apiEndpoint,
    processFactory: processFactory,
    projectStore: projectStore,
  );
}

/// The const Cursor plugin descriptor.
///
/// Cursor drives a `cursor-agent acp` stdio subprocess over the generic ACP
/// machinery, so it needs no managed-runtime supervisor (no listening port to
/// reclaim, no ownership file). It declares its CLI surface, probes the
/// `cursor-agent` binary for availability, and on [start] spawns the agent
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

  /// Minimum `cursor-agent` build the bridge supports. Earlier builds (e.g.
  /// `2026.05.28`) advertise the `acp` model picker and `session/load` but
  /// silently no-op model switching and history replay, so the experience is
  /// broken in ways the user can't see. `2026.06.15` is the verified-good
  /// build where both work end-to-end.
  static const String minVersion = "2026.06.15";

  /// CLI option naming the `cursor-agent` binary (path or PATH name).
  static const String binOption = "cursor-bin";

  /// CLI option overriding the Cursor API endpoint (passed as `-e <endpoint>`).
  static const String apiEndpointOption = "cursor-api-endpoint";

  static const List<PluginOption> cliOptions = [
    PluginValueOption(
      name: binOption,
      help: "Path to the cursor-agent binary",
      defaultsTo: CursorBinary.defaultBinary,
      allowedValues: null,
      valueHelp: "path",
      validate: null,
    ),
    PluginValueOption(
      name: apiEndpointOption,
      help: "Override the Cursor API endpoint (passed to cursor-agent as -e <endpoint>)",
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
  List<PluginOption> get options => cliOptions;

  /// Confirms the `cursor-agent` CLI is installed and runnable before the
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
    final SpawnedProcess process;
    try {
      process = await processes.spawn(
        executable: executablePath,
        arguments: const ["--version"],
        environment: environment,
        workingDirectory: null,
        runInShell: io.Platform.isWindows,
      );
    } on Object catch (error) {
      Log.d("[cursor] availability probe could not launch '$executablePath --version': $error");
      return PluginUnavailable(message: _notInstalledMessage(executablePath: executablePath));
    }

    final stdoutBuffer = StringBuffer();
    final stdoutSubscription =
        process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write, onError: (Object _) {});
    final stderrSubscription = process.stderr.listen((_) {}, onError: (Object _) {});
    try {
      final exitCode = await process.exitCode.timeout(_versionProbeTimeout);
      if (exitCode == 0) {
        final version = stdoutBuffer.toString().trim();
        final parsed = _CalVer.tryParse(version);
        final minimum = _CalVer.tryParse(minVersion);
        if (parsed != null && minimum != null && parsed.compareTo(minimum) < 0) {
          Log.w("[cursor] cursor-agent $version is below the supported minimum $minVersion");
          return PluginUnavailable(
            message: _outdatedMessage(executablePath: executablePath, version: version),
          );
        }
        Log.d("[cursor] available: '$executablePath --version' -> ${version.isEmpty ? "exit 0 (no output)" : version}");
        return const PluginAvailable();
      }
      Log.d("[cursor] availability probe '$executablePath --version' exited with code $exitCode");
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } on TimeoutException {
      Log.d(
        "[cursor] availability probe '$executablePath --version' did not exit within "
        "${_versionProbeTimeout.inSeconds}s",
      );
      try {
        await processes.signalForce(pid: process.pid);
      } on Object {
        // Best-effort: reap the hung probe.
      }
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } on Object catch (error) {
      Log.d("[cursor] availability probe '$executablePath --version' failed with error: $error");
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } finally {
      try {
        await stdoutSubscription.cancel();
      } on Object catch (e, st) {
        Log.w("[cursor] failed to cancel stdout subscription", e, st);
      }
      try {
        await stderrSubscription.cancel();
      } on Object catch (e, st) {
        Log.w("[cursor] failed to cancel stderr subscription", e, st);
      }
    }
  }

  String _notInstalledMessage({required String executablePath}) {
    return [
      "Cursor was not found — the Sesori bridge needs the cursor-agent CLI to run.",
      "",
      "Verify it is installed:  $executablePath --version",
      "Install the Cursor CLI:  curl https://cursor.com/install -fsS | bash",
    ].join("\n");
  }

  String _notWorkingMessage({required String executablePath}) {
    return [
      'cursor-agent is installed but did not respond to "$executablePath --version".',
      "",
      "Re-check your install:   $executablePath --version",
      "Update the Cursor CLI:   cursor-agent update",
    ].join("\n");
  }

  String _outdatedMessage({required String executablePath, required String version}) {
    final headline = "cursor-agent $version is too old for the Sesori bridge — "
        "model switching and chat history need $minVersion or newer.";
    return [
      headline,
      "",
      "Update the Cursor CLI:   cursor-agent update",
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
      // The implicit default Cursor project is the bridge's launch directory;
      // directories opened from the app are added to (and persisted by) the
      // plugin's project registry via host.store.
      projectCwd: io.Directory.current.path,
      apiEndpoint: apiEndpoint,
      processFactory: processFactory,
      projectStore: host.store,
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
    // (which it caches) already has the full list. Bounded so a slow probe never
    // stalls startup; the lazy path in getProviders/getAgents is the fallback.
    await cursor.warmCatalog().timeout(
      const Duration(seconds: 12),
      onTimeout: () => Log.d("[cursor] catalog warm-up timed out; will populate lazily"),
    );

    // Warm-up can run for seconds: re-check so an abort observed during it still
    // rolls back instead of returning a started plugin.
    if (host.startAborted.isAborted) {
      await rollbackAborted();
    }

    return plugin;
  }
}

/// A cursor-agent calendar version (`YYYY.MM.DD`, the leading component of a
/// build string like `2026.06.15-18-00-12-6f5a2cf`). Parsed once into a typed
/// [Comparable] rather than comparing version strings ad hoc.
class _CalVer implements Comparable<_CalVer> {
  const _CalVer(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  /// Parses the leading `YYYY.MM.DD` from a cursor-agent version/build string,
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
}
