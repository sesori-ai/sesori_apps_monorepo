import "dart:async";
import "dart:convert";
import "dart:io" as io;
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../codex_binary_resolver.dart";
import "../codex_plugin_impl.dart";
import "codex_bridge_plugin.dart";
import "codex_managed_api.dart";
import "codex_ownership_record.dart";
import "codex_record_mapper.dart";
import "codex_runtime_policy.dart";
import "codex_status_reporter.dart";

/// Builds the [CodexManagedApi] for a resolved server. The production default
/// constructs a [CodexPlugin] wired to the descriptor's status reporter; tests
/// inject a fake.
typedef CodexManagedApiFactory =
    CodexManagedApi Function({
      required String serverUrl,
      required void Function() onConnected,
      required void Function() onDisconnected,
    });

CodexManagedApi _defaultBuildApi({
  required String serverUrl,
  required void Function() onConnected,
  required void Function() onDisconnected,
}) {
  return CodexPlugin(
    serverUrl: serverUrl,
    onConnected: onConnected,
    onDisconnected: onDisconnected,
  );
}

/// Resolves the codex binary path. Production builds the real
/// [CodexBinaryResolver]; tests inject a stub.
typedef CodexBinaryResolverFactory =
    CodexBinaryResolver Function({
      required String codexBinFlag,
      required Map<String, String> environment,
    });

CodexBinaryResolver _defaultBuildBinaryResolver({
  required String codexBinFlag,
  required Map<String, String> environment,
}) {
  return CodexBinaryResolver(codexBinFlag: codexBinFlag, environment: environment);
}

/// The Codex plugin descriptor: it owns the full `codex app-server` runtime
/// lifecycle (binary resolution, stale cleanup, start, health, ownership
/// persistence, exit monitoring) over the [PluginHost] and the
/// `sesori_plugin_runtime` supervisor — mirroring the OpenCode descriptor,
/// adapted for codex's loopback-WebSocket transport.
///
/// Registered in `bin/bridge.dart` alongside the OpenCode descriptor; selected
/// at launch with `--plugin codex` (or the `enabledPlugins` bridge setting).
/// Unlike OpenCode there is no attach (`--no-auto-start`) mode and no crash
/// restart: the codex WebSocket client does not auto-reconnect, so an
/// unexpected child exit surfaces as `PluginFailed`.
///
/// The optional constructor parameters are test seams; the registered
/// descriptor is `const CodexPluginDescriptor()`.
class CodexPluginDescriptor extends BridgePluginDescriptor {
  const CodexPluginDescriptor({
    CodexManagedApiFactory? buildApi,
    CodexBinaryResolverFactory? buildBinaryResolver,
    Iterable<int>? candidatePorts,
    Random? random,
    Duration degradedDebounce = const Duration(seconds: 5),
    Duration coldStartBudget = codexColdStartBudget,
    Duration versionProbeTimeout = codexVersionProbeTimeout,
  }) : _buildApi = buildApi,
       _buildBinaryResolver = buildBinaryResolver,
       _candidatePorts = candidatePorts,
       _random = random,
       _degradedDebounce = degradedDebounce,
       _coldStartBudget = coldStartBudget,
       _versionProbeTimeout = versionProbeTimeout;

  final CodexManagedApiFactory? _buildApi;
  final CodexBinaryResolverFactory? _buildBinaryResolver;
  final Iterable<int>? _candidatePorts;
  final Random? _random;
  final Duration _degradedDebounce;
  final Duration _coldStartBudget;
  final Duration _versionProbeTimeout;

  /// The codex CLI options the bridge registers when this plugin is selected.
  static const List<PluginOption> cliOptions = [
    PluginValueOption.integer(
      name: "port",
      help: "Port for codex app-server to listen on (default: an ephemeral port)",
      defaultsTo: null,
      valueHelp: null,
    ),
    PluginValueOption(
      // Bare local name; the bridge namespaces it to `--codex-bin` under this
      // plugin's id. (Pre-namespacing this was declared as "codex-bin", which
      // would now double-prefix to `--codex-codex-bin`.)
      name: "bin",
      help: "Path to codex binary",
      defaultsTo: "codex",
      allowedValues: null,
      valueHelp: null,
      validate: null,
    ),
  ];

  @override
  String get id => "codex";

  @override
  String get displayName => "Codex";

  @override
  List<PluginOption> get options => cliOptions;

  /// Confirms the codex CLI is available before the bridge commits to startup.
  /// This is a READ-ONLY probe — it never mutates disk or hits the network:
  ///
  ///   1. Resolve the binary with no side effects ([CodexBinaryResolver.probe]:
  ///      override / usable cached binary / PATH) and run `<codex-bin>
  ///      --version`; exit 0 within [_versionProbeTimeout] means available.
  ///   2. If that finds no runnable codex but [start]'s download-capable
  ///      resolution *would* fetch the pinned managed binary for this platform
  ///      ([CodexBinaryResolver.willDownloadManagedBinary]), report available
  ///      anyway — a fresh install where codex is absent on PATH but
  ///      downloadable must not be blocked here; the fetch happens in [start].
  ///   3. Otherwise unavailable (failed launch, non-zero exit, or timeout with
  ///      nothing downloadable).
  @override
  Future<PluginAvailability> checkAvailability({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    final binFlag = config.value("bin") ?? "codex";
    final resolver = _resolver(binFlag: binFlag, environment: environment);
    final executablePath = await resolver.probe();
    final availability = await _probeCodexBinary(
      executablePath: executablePath,
      processes: processes,
      environment: environment,
    );
    if (availability is PluginAvailable) return availability;
    // No runnable codex right now, but if start()'s resolve() would
    // auto-download the pinned managed binary, the install is fine — defer the
    // fetch to start() rather than blocking startup. Stays side-effect free.
    if (await resolver.willDownloadManagedBinary()) {
      Log.d("[codex] available: managed binary will be downloaded at startup");
      return const PluginAvailable();
    }
    return availability;
  }

  CodexBinaryResolver _resolver({
    required String binFlag,
    required Map<String, String> environment,
  }) {
    return (_buildBinaryResolver ?? _defaultBuildBinaryResolver)(
      codexBinFlag: binFlag,
      environment: environment,
    );
  }

  /// Download-capable resolution for actual startup (override / cached /
  /// auto-download / PATH).
  Future<String> _resolveBinary({
    required String binFlag,
    required Map<String, String> environment,
  }) async {
    return _resolver(binFlag: binFlag, environment: environment).resolve();
  }

  /// Runs `<executablePath> --version` and classifies the outcome. Never
  /// throws: every failure mode maps to a [PluginUnavailable] with user-facing
  /// guidance.
  Future<PluginAvailability> _probeCodexBinary({
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
      Log.d("[codex] availability probe could not launch '$executablePath --version': $error");
      return PluginUnavailable(message: _notInstalledMessage(executablePath: executablePath));
    }

    final stdoutBuffer = StringBuffer();
    final stdoutSubscription = process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write, onError: (Object _) {});
    final stderrSubscription = process.stderr.listen((_) {}, onError: (Object _) {});
    try {
      final exitCode = await process.exitCode.timeout(_versionProbeTimeout);
      if (exitCode == 0) {
        final version = stdoutBuffer.toString().trim();
        Log.d("[codex] available: '$executablePath --version' -> ${version.isEmpty ? "exit 0 (no output)" : version}");
        return const PluginAvailable();
      }
      Log.d("[codex] availability probe '$executablePath --version' exited with code $exitCode");
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } on TimeoutException {
      Log.d(
        "[codex] availability probe '$executablePath --version' did not exit within "
        "${_versionProbeTimeout.inSeconds}s",
      );
      try {
        await processes.signalForce(pid: process.pid);
      } on Object {
        // Best-effort: reap the hung probe so it does not linger.
      }
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } on Object catch (error) {
      Log.d("[codex] availability probe '$executablePath --version' failed with error: $error");
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } finally {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
    }
  }

  String _notInstalledMessage({required String executablePath}) {
    return [
      "Codex was not found — the Sesori bridge needs the Codex CLI to run the codex backend.",
      "",
      "Verify it is installed:  $executablePath --version",
      "Install Codex:           https://github.com/openai/codex",
    ].join("\n");
  }

  String _notWorkingMessage({required String executablePath}) {
    return [
      'Codex is installed but did not respond to "$executablePath --version".',
      "",
      "Re-check your install:  $executablePath --version",
      "Reinstall Codex:        https://github.com/openai/codex",
    ].join("\n");
  }

  @override
  Future<CodexBridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final config = host.config;
    final requestedPort = config.intValue("port");
    final binFlag = config.value("bin") ?? "codex";
    final executablePath = await _resolveBinary(binFlag: binFlag, environment: host.environment);
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    const mapper = CodexRecordMapper();

    final service = ManagedProcessService<CodexOwnershipRecord>(
      ownershipRepository: HostJsonRuntimeOwnershipRepository<CodexOwnershipRecord>(
        store: host.store,
        mapper: mapper,
        fileName: "codex-processes.json",
        clock: host.clock,
      ),
      mapper: mapper,
      processes: host.processes,
      bridge: host.bridge,
      clock: host.clock,
      runtimeId: "codex",
      gracefulShutdownWait: codexGracefulShutdownWait,
      intentStore: RuntimeStartIntentStore(store: host.store, fileName: "codex-start-intent.json"),
    );

    final RuntimePortPolicy portPolicy;
    if (requestedPort != null) {
      Log.d("[codex] starting on port $requestedPort");
      // Pre-probe the explicit port so an occupied port fails with a diagnosis
      // instead of spawning a child doomed to lose the bind race.
      portPolicy = ExplicitPortPolicy(port: requestedPort, preProbeBindable: true);
    } else {
      Log.d("[codex] starting on a dynamic port");
      portPolicy = DynamicPortPolicy(
        candidates: codexDynamicCandidates(candidates: _candidatePorts, random: _random),
        maxAttempts: dynamicCodexMaxAttempts,
        reservedPort: codexNoReservedPort,
        minPort: dynamicCodexPortMin,
        maxPort: dynamicCodexPortMax,
        // A spawn that cannot even launch (e.g. ENOENT on the binary) fails the
        // same way on every candidate — fail fast instead of retrying.
        failFastOnSpawnError: true,
      );
    }

    final spec = buildCodexManagedRuntimeSpec(
      host: host,
      executablePath: executablePath,
      portPolicy: portPolicy,
    );

    // start() cleans up stale owned runtimes, selects a port, spawns, and
    // confirms the listener is accepting before returning — rolling everything
    // back (and throwing) on failure.
    final handle = await service.start(
      spec: spec,
      terminatedBridgeIdentities: host.bridge.terminatedBridgeIdentities,
      startAborted: host.startAborted,
    );
    final port = handle.port;
    final serverUrl = codexServerUrl(port: port);
    Log.d("[codex] app-server started on $serverUrl");

    // Honor a late abort: a managed start the supervisor returned just as the
    // bridge aborted must release the owned child before we surface it.
    if (host.startAborted.isAborted) {
      if (handle.isOwned) {
        await service.stopOwnedRuntime(record: handle.record!);
      }
      throw const PluginStartAbortedException();
    }

    final ownedRecord = handle.record;

    final reporter = CodexRuntimeStatusReporter(
      status: PluginStatusController(initial: const PluginStarting()),
      clock: host.clock,
      degradedDebounce: _degradedDebounce,
    );

    // Arm the exit monitor with the disabled restart policy: an unexpected child
    // exit surfaces as PluginFailed (the WebSocket client cannot reconnect).
    final monitor = ManagedRuntimeMonitor<CodexOwnershipRecord>(
      service: service,
      spec: spec,
      status: reporter.status,
      clock: host.clock,
      runtimeId: "codex",
      restartPolicy: buildCodexRestartPolicy(),
    );
    monitor.arm(handle);

    final api = (_buildApi ?? _defaultBuildApi)(
      serverUrl: serverUrl,
      onConnected: reporter.markConnected,
      onDisconnected: reporter.markDisconnected,
    );

    final plugin = CodexBridgePlugin(
      api: api,
      reporter: reporter,
      monitor: monitor,
      service: service,
      ownedRecord: ownedRecord,
      port: port,
      serverUrl: serverUrl,
    );

    // Await cold-start (the WebSocket connect + `initialize` handshake). A
    // failure leaves the plugin started but degraded rather than failing the
    // whole bridge — the listener accepted a TCP probe, so it is addressable.
    //
    // The await is bounded by [_coldStartBudget]: a server that passed the
    // readiness probe but stalls the handshake must not hang start() under the
    // bridge's cross-instance startup mutex. Past the budget the cold-start
    // keeps running in the background and the plugin starts degraded.
    final coldStart = api.initialize();
    var budgetExceeded = false;
    // The sink keeps a post-budget failure from surfacing as an unhandled async
    // error once the await below has moved on; the awaited path observes (and
    // logs) every pre-budget failure itself.
    unawaited(
      coldStart.catchError((Object error, StackTrace stackTrace) {
        if (budgetExceeded) {
          Log.w("[codex] cold-start failed after the start budget: $error");
        }
      }),
    );
    try {
      await coldStart.timeout(
        _coldStartBudget,
        onTimeout: () {
          budgetExceeded = true;
          Log.w(
            "[codex] cold-start did not finish within ${_coldStartBudget.inSeconds}s — "
            "starting degraded while it keeps running in the background",
          );
        },
      );
      if (budgetExceeded) {
        reporter.markDegradedNow();
      } else {
        reporter.markConnected();
      }
    } on Object catch (error) {
      Log.w("[codex] cold-start did not complete cleanly: $error");
      reporter.markDegradedNow();
    }

    // The cold-start is a phase boundary: an abort observed here must roll back
    // everything acquired so far (api transport, monitor, the owned child)
    // before surfacing, or an aborted start leaks a live runtime.
    if (host.startAborted.isAborted) {
      try {
        await plugin.shutdown(budget: null);
      } on Object catch (error) {
        Log.e("[codex] rollback after aborted start failed: $error");
      }
      throw const PluginStartAbortedException();
    }

    return plugin;
  }
}
