import "dart:async";
import "dart:io" as io;
import "dart:math";

import "package:http/http.dart" as http;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../codex_plugin_impl.dart";
import "codex_bridge_plugin.dart";
import "codex_managed_api.dart";
import "codex_ownership_record.dart";
import "codex_record_mapper.dart";
import "codex_runtime_manifest.dart";
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

/// The Codex plugin descriptor: it owns the full `codex app-server` runtime
/// lifecycle (runtime provisioning, stale cleanup, start, health, ownership
/// persistence, exit monitoring) over the [PluginHost] and the
/// `sesori_plugin_runtime` supervisor — mirroring the OpenCode descriptor,
/// adapted for codex's loopback-WebSocket transport.
///
/// Registered in `bin/bridge.dart` alongside the OpenCode descriptor; selected
/// at launch with `--plugin codex` (or the `enabledPlugins` bridge setting).
/// Unlike OpenCode there is no attach (`--no-auto-start`) mode and no crash
/// restart: the codex WebSocket client does not auto-reconnect, so an
/// unexpected child exit surfaces as `PluginFailed`, and a runtime that cannot
/// be provisioned fails the start rather than degrading.
///
/// The optional constructor parameters are test seams; the registered
/// descriptor is `const CodexPluginDescriptor()`.
class CodexPluginDescriptor extends BridgePluginDescriptor {
  const CodexPluginDescriptor({
    CodexManagedApiFactory? buildApi,
    Iterable<int>? candidatePorts,
    Random? random,
    Duration degradedDebounce = const Duration(seconds: 5),
    Duration coldStartBudget = codexColdStartBudget,
    Duration versionProbeTimeout = codexVersionProbeTimeout,
    ManagedRuntimeProvisionService? provisionService,
    http.Client Function()? probeClientFactory,
  }) : _buildApi = buildApi,
       _candidatePorts = candidatePorts,
       _random = random,
       _degradedDebounce = degradedDebounce,
       _coldStartBudget = coldStartBudget,
       _versionProbeTimeout = versionProbeTimeout,
       _provisionService = provisionService,
       _probeClientFactory = probeClientFactory;

  final CodexManagedApiFactory? _buildApi;
  final Iterable<int>? _candidatePorts;
  final Random? _random;
  final Duration _degradedDebounce;
  final Duration _coldStartBudget;
  final Duration _versionProbeTimeout;

  /// Test seam for the runtime provisioner. Production builds a default in
  /// [ensureRuntime] from the host's process service and an HTTP client.
  final ManagedRuntimeProvisionService? _provisionService;
  final http.Client Function()? _probeClientFactory;

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
      // plugin's id.
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

  /// The explicit `--codex-bin` override path, or `null` when unset, empty, or
  /// left at the bare default `codex` (which means "resolve via [ensureRuntime]":
  /// a recent-enough PATH codex or the pinned managed download).
  String? _explicitBin(PluginConfig config) {
    final value = config.value("bin")?.trim();
    if (value == null || value.isEmpty || value == "codex") {
      return null;
    }
    return value;
  }

  /// Confirms an explicitly-configured codex binary is runnable before the
  /// bridge commits to startup.
  ///
  /// When `--codex-bin` is an explicit path, probe it: an explicit override is a
  /// user promise, so a broken one is a fatal config error. When no binary is
  /// configured, runtime resolution (a recent-enough PATH install or a managed
  /// download) is deferred to [ensureRuntime], so report available here. This is
  /// a READ-ONLY probe — it never mutates disk or hits the network.
  @override
  Future<PluginAvailability> checkAvailability({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    final explicitBin = _explicitBin(config);
    if (explicitBin == null) {
      return const PluginAvailable();
    }
    const manifest = CodexRuntimeManifest();
    return RuntimeAvailabilityProber(
      displayName: manifest.displayName,
      installDocsUrl: manifest.installDocsUrl,
      runtimeId: manifest.runtimeId,
    ).probe(
      executablePath: explicitBin,
      processes: processes,
      environment: environment,
      versionProbeTimeout: _versionProbeTimeout,
      runInShell: io.Platform.isWindows,
    );
  }

  /// Resolves the codex runtime (a recent-enough PATH install, otherwise a
  /// managed download) and reports progress. Skipped when an explicit
  /// `--codex-bin` path is set (it already names the binary). The resolved
  /// launch path is surfaced via [ProvisionReady]; a failure is non-fatal here
  /// and `start()` fails with guidance.
  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (_explicitBin(host.config) != null) {
      return;
    }

    final injected = _provisionService;
    if (injected != null) {
      yield* injected.provision(host: host);
      return;
    }

    final http.Client client = (_probeClientFactory ?? http.Client.new)();
    try {
      yield* _buildDefaultProvisionService(host: host, httpClient: client).provision(host: host);
    } finally {
      client.close();
    }
  }

  /// Assembles the production provisioner from the host's process service (so
  /// helper commands go through the host, never a raw spawn) and [httpClient].
  ManagedRuntimeProvisionService _buildDefaultProvisionService({
    required PluginHost host,
    required http.Client httpClient,
  }) {
    const manifest = CodexRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      processes: host.processes,
      runInShell: io.Platform.isWindows,
    );
    return ManagedRuntimeProvisionService(
      manifest: manifest,
      versionValidator: RuntimeVersionValidator(
        commandExecutor: commandExecutor,
        runtimeId: manifest.runtimeId,
        probeTimeout: _versionProbeTimeout,
      ),
      installService: RuntimeInstallService(
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        checksumValidator: ChecksumValidator(),
        archiveExtractor: ArchiveExtractor(commandExecutor: commandExecutor),
        commandExecutor: commandExecutor,
        runtimeId: manifest.runtimeId,
      ),
      cleaner: ManagedRuntimeCleaner(runtimeId: manifest.runtimeId),
    );
  }

  @override
  Future<CodexBridgePlugin> start(PluginHost host) async {
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final config = host.config;
    final requestedPort = config.intValue("port");
    // Precedence: an explicit --codex-bin override wins (trusted, no version
    // gate); otherwise the path ensureRuntime resolved (a recent PATH codex or
    // the managed download), exposed via the host.
    final executablePath = _explicitBin(config) ?? host.provisionedRuntimePath;
    if (executablePath == null) {
      // Runtime provisioning failed and no explicit binary was given. codex has
      // no attach/degraded mode (its WebSocket client cannot reconnect), so it
      // needs a real binary to run — fail the start with actionable guidance
      // rather than spawning an empty command.
      throw const PluginStartException(
        "No runnable codex binary is available. Install codex "
        "(https://github.com/openai/codex) or pass --codex-bin, then restart.",
        cause: null,
      );
    }
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
