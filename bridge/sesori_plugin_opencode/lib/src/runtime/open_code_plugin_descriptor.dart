import "dart:async";
import "dart:convert";
import "dart:io" as io;
import "dart:math";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:sesori_shared/sesori_shared.dart" show StringExtensions;

import "../opencode_db_api.dart";
import "../opencode_db_maintenance_service.dart";
import "../opencode_db_repository.dart";
import "../opencode_plugin_impl.dart";
import "open_code_bridge_plugin.dart";
import "open_code_managed_api.dart";
import "open_code_ownership_record.dart";
import "open_code_record_mapper.dart";
import "open_code_runtime_cleaner.dart";
import "open_code_runtime_install_service.dart";
import "open_code_runtime_manifest.dart";
import "open_code_runtime_policy.dart";
import "open_code_runtime_provision_service.dart";
import "open_code_version_validator.dart";

/// Builds the [OpenCodeManagedApi] for a resolved server. The production default
/// constructs an [OpenCodePlugin] with auto-initialization disabled (the
/// descriptor awaits [OpenCodeManagedApi.initialize] explicitly); tests inject a
/// fake.
typedef OpenCodeManagedApiFactory =
    OpenCodeManagedApi Function({
      required String serverUrl,
      required String? password,
      required void Function() onConnected,
      required void Function() onDisconnected,
    });

OpenCodeManagedApi _defaultBuildApi({
  required String serverUrl,
  required String? password,
  required void Function() onConnected,
  required void Function() onDisconnected,
}) {
  return OpenCodePlugin(
    serverUrl: serverUrl,
    password: password,
    autoInitialize: false,
    onConnected: onConnected,
    onDisconnected: onDisconnected,
  );
}

/// Runs the opportunistic OpenCode database maintenance for [environment].
/// The production default locates `opencode.db` under `XDG_DATA_HOME` (or
/// `~/.local/share`) and delegates to [OpenCodeDbMaintenanceService]; tests
/// inject a recorder.
typedef OpenCodeDbOptimizer = Future<void> Function({required Map<String, String> environment});

Future<void> _defaultOptimizeDb({required Map<String, String> environment}) async {
  final homeDir = environment["HOME"] ?? environment["USERPROFILE"];
  if (homeDir == null) {
    return;
  }

  await OpenCodeDbMaintenanceService(
    repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
  ).optimizeIfNeeded(
    dbPath: '${environment["XDG_DATA_HOME"] ?? "$homeDir/.local/share"}/opencode/opencode.db',
  );
}

/// The real, const OpenCode plugin descriptor: it owns the full OpenCode runtime
/// lifecycle (stale cleanup, start-or-attach, health, ownership persistence,
/// exit monitoring, bounded crash-restart) over the [PluginHost] and the
/// `sesori_plugin_runtime` supervisor.
///
/// Registered in `bin/bridge.dart` since the flip (PR 12 of the
/// plugin-lifecycle migration), with the hardened policy knobs active:
/// deadline-paced health confirmation, the start intent recorded to a
/// bridge-private side file, pre-probed explicit ports, early child exits
/// treated as authoritative failure, and bounded restart pinned to the
/// original port. OpenCode database maintenance also runs here, at the top of
/// [start].
///
/// The optional constructor parameters are test seams (and the random/candidate
/// sources the supervisor needs); the registered descriptor is `const
/// OpenCodePluginDescriptor()`.
class OpenCodePluginDescriptor extends BridgePluginDescriptor {
  const OpenCodePluginDescriptor({
    OpenCodeManagedApiFactory? buildApi,
    http.Client Function()? probeClientFactory,
    Iterable<int>? candidatePorts,
    Random? random,
    Duration degradedDebounce = const Duration(seconds: 5),
    Duration coldStartBudget = openCodeColdStartBudget,
    Duration versionProbeTimeout = openCodeVersionProbeTimeout,
    OpenCodeDbOptimizer? optimizeDb,
    OpenCodeRuntimeProvisionService? provisionService,
  }) : _buildApi = buildApi,
       _probeClientFactory = probeClientFactory,
       _candidatePorts = candidatePorts,
       _random = random,
       _degradedDebounce = degradedDebounce,
       _coldStartBudget = coldStartBudget,
       _versionProbeTimeout = versionProbeTimeout,
       _optimizeDb = optimizeDb,
       _provisionService = provisionService;

  final OpenCodeManagedApiFactory? _buildApi;
  final http.Client Function()? _probeClientFactory;
  final Iterable<int>? _candidatePorts;
  final Random? _random;
  final Duration _degradedDebounce;
  final Duration _coldStartBudget;
  final Duration _versionProbeTimeout;
  final OpenCodeDbOptimizer? _optimizeDb;

  /// Test seam for the runtime provisioner. Production builds a default in
  /// [ensureRuntime] from the host's process service and an HTTP client.
  final OpenCodeRuntimeProvisionService? _provisionService;

  /// The OpenCode CLI options the bridge declares for this plugin.
  ///
  /// Names are bare; the bridge namespaces them to `--opencode-<name>`. The
  /// pre-namespacing spellings that already shipped (`--port`, `--no-auto-start`,
  /// `--password`) are kept as deprecated aliases so existing invocations keep
  /// working (with a warning). `bin` already namespaces to the historical
  /// `--opencode-bin`, and the never-released `host`/`no-password` flags are new,
  /// so none of those need an alias.
  static const List<PluginOption> cliOptions = [
    PluginValueOption.integer(
      name: "port",
      help: "Port for opencode server to listen on",
      defaultsTo: null,
      valueHelp: null,
      deprecatedAliases: ["port"],
    ),
    PluginValueOption(
      name: "host",
      help:
          "Host the opencode server binds to (auto-start) or is reached at "
          "(--opencode-no-auto-start). Defaults to 127.0.0.1. Use 0.0.0.0 to "
          "expose the server on all interfaces, e.g. inside a Docker container. "
          "Warning: 0.0.0.0 exposes the server (Basic-auth only) to your whole "
          "network.",
      defaultsTo: openCodeLoopbackHost,
      allowedValues: null,
      valueHelp: "host",
      validate: null,
    ),
    PluginFlagOption(
      name: "no-auto-start",
      help: "Skip auto-starting opencode server (use existing server)",
      defaultsTo: false,
      negatable: true,
      deprecatedAliases: ["no-auto-start"],
    ),
    PluginValueOption(
      name: "password",
      help: "Override server password (auto-generated if not set)",
      defaultsTo: "",
      allowedValues: null,
      valueHelp: null,
      validate: null,
      deprecatedAliases: ["password"],
    ),
    PluginFlagOption(
      name: "no-password",
      help: "Disable OpenCode server authentication",
      defaultsTo: false,
      negatable: false,
    ),
    PluginValueOption(
      name: "bin",
      help:
          "Path to a specific opencode binary. When set, it is used as-is "
          "(no version gate); when unset, the bridge uses a recent enough "
          "opencode on PATH or downloads a managed runtime.",
      defaultsTo: null,
      allowedValues: null,
      valueHelp: null,
      validate: null,
    ),
  ];

  /// Static counterpart of [validateConfig] for argument-parse-time callers.
  static void validateConfigValues(PluginConfig config) {
    if (config.flag("no-auto-start") && config.intValue("port") == null) {
      throw const PluginConfigException("The --opencode-no-auto-start flag requires --opencode-port to be set.");
    }
    if (config.flag("no-password") && (config.value("password")?.isNotEmpty ?? false)) {
      throw const PluginConfigException("The --opencode-no-password flag cannot be used with --opencode-password.");
    }
    // The host is used in both modes (bind target when managed, connect target
    // when attaching), so validate it up front — a malformed value would
    // otherwise only fail deep in start(), after the startup mutex has run and
    // the single-live-bridge replacement may have stopped a healthy resident.
    final host = (config.value("host") ?? "").trim();
    if (host.isEmpty) {
      throw const PluginConfigException("The --opencode-host option cannot be empty.");
    }
    // Reject anything that isn't a bare host or IP literal: the value is built
    // into server URLs. A scheme/path/port typo like "http://127.0.0.1" throws
    // a FormatException; a value with an escapable delimiter (e.g. internal
    // whitespace) instead percent-escapes silently, so also require the parsed
    // host to round-trip unchanged.
    if (!_isWellFormedHost(host)) {
      throw PluginConfigException("The --opencode-host option must be a bare host or IP, got '$host'.");
    }
    // A non-loopback managed bind with auth disabled would expose an
    // unauthenticated OpenCode server on the network. Block that combination;
    // a wildcard/LAN bind with the default Basic-auth password stays allowed,
    // and --opencode-no-password on a loopback host stays allowed.
    if (!config.flag("no-auto-start") && config.flag("no-password") && !_isLoopbackHost(host)) {
      throw PluginConfigException(
        "The --opencode-no-password flag cannot be combined with a non-loopback --opencode-host "
        "('$host') when auto-starting: it would expose an unauthenticated OpenCode server on the "
        "network. Use a loopback host or keep authentication enabled.",
      );
    }
  }

  /// Whether [host] is a bare host or IP literal usable in a URL authority —
  /// i.e. it parses as a URI host and round-trips unchanged (case-insensitively).
  ///
  /// The round-trip catches values that `Uri` percent-escapes instead of
  /// rejecting (e.g. internal whitespace), which would otherwise pass and fail
  /// only later when a connection is attempted.
  static bool _isWellFormedHost(String host) {
    final Uri probe;
    try {
      probe = Uri(scheme: "http", host: host, port: 1);
    } on FormatException {
      return false;
    }
    return probe.host.toLowerCase() == host.toLowerCase();
  }

  /// Whether [host] only accepts connections from the local machine, so
  /// disabling authentication does not expose the server to the network.
  ///
  /// Uses [io.InternetAddress] loopback detection (the full `127.0.0.0/8` range
  /// and `::1`) rather than a string prefix, so a DNS name like `127.evil.com`
  /// is correctly treated as non-loopback. `localhost` is matched explicitly
  /// since it is a name, not a parseable IP literal.
  static bool _isLoopbackHost(String host) {
    if (host == "localhost") {
      return true;
    }
    return io.InternetAddress.tryParse(host)?.isLoopback ?? false;
  }

  @override
  String get id => "opencode";

  @override
  String get displayName => "OpenCode";

  @override
  List<PluginOption> get options => cliOptions;

  @override
  void validateConfig(PluginConfig config) => validateConfigValues(config);

  /// Confirms an explicitly-configured OpenCode binary is runnable before the
  /// bridge commits to startup.
  ///
  /// In attach mode (`--no-auto-start`) the user runs their own server, so no
  /// binary is needed — report available. When `--opencode-bin` is set, probe
  /// it: an explicit override is a user promise, so a broken one is a fatal
  /// config error (run `<bin> --version`; exit 0 within
  /// [openCodeVersionProbeTimeout] is available). When no binary is configured,
  /// runtime resolution (a recent-enough PATH install or a managed download) is
  /// deferred to [ensureRuntime], so report available here.
  @override
  Future<PluginAvailability> checkAvailability({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async {
    if (config.flag("no-auto-start")) {
      return const PluginAvailable();
    }
    final explicitBin = config.value("bin")?.trim();
    if (explicitBin != null && explicitBin.isNotEmpty) {
      return _probeOpenCodeBinary(
        executablePath: explicitBin,
        processes: processes,
        environment: environment,
      );
    }
    return const PluginAvailable();
  }

  /// Resolves the OpenCode runtime (a recent-enough PATH install, otherwise a
  /// managed download) and reports progress. Skipped in attach mode and when an
  /// explicit `--opencode-bin` is set (both already have their binary). The
  /// resolved launch path is surfaced via [ProvisionReady]; a failure is
  /// non-fatal and `start()` degrades.
  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    final config = host.config;
    if (config.flag("no-auto-start")) {
      return;
    }
    final explicitBin = config.value("bin")?.trim();
    if (explicitBin != null && explicitBin.isNotEmpty) {
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
  OpenCodeRuntimeProvisionService _buildDefaultProvisionService({
    required PluginHost host,
    required http.Client httpClient,
  }) {
    final commandExecutor = HostProcessCommandExecutor(
      processes: host.processes,
      runInShell: io.Platform.isWindows,
    );
    return OpenCodeRuntimeProvisionService(
      manifest: const OpenCodeRuntimeManifest(),
      versionValidator: OpenCodeVersionValidator(
        commandExecutor: commandExecutor,
        probeTimeout: _versionProbeTimeout,
      ),
      installService: OpenCodeRuntimeInstallService(
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        checksumValidator: ChecksumValidator(),
        archiveExtractor: ArchiveExtractor(commandExecutor: commandExecutor),
        commandExecutor: commandExecutor,
      ),
      cleaner: OpenCodeRuntimeCleaner(),
    );
  }

  /// Runs `<executablePath> --version` and classifies the outcome. Never
  /// throws: every failure mode maps to a [PluginUnavailable] with user-facing
  /// guidance.
  Future<PluginAvailability> _probeOpenCodeBinary({
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
        // On Windows the binary is typically an `opencode.cmd`/`.ps1` shim that
        // only resolves through a shell — matching how the managed runtime
        // spawns `opencode serve`.
        runInShell: io.Platform.isWindows,
      );
    } on Object catch (error) {
      // Spawn could not launch at all — almost always ENOENT: the binary is not
      // installed or not on PATH.
      Log.d("[opencode] availability probe could not launch '$executablePath --version': $error");
      return PluginUnavailable(message: _notInstalledMessage(executablePath: executablePath));
    }

    // Accumulate stdout (the version string, for diagnostics) and drain stderr
    // so the child can never block on a full pipe. Subscriptions, not joined
    // futures, so a hung binary that never closes its streams cannot keep us
    // waiting past the timeout below.
    final stdoutBuffer = StringBuffer();
    final stdoutSubscription = process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write, onError: (Object _) {});
    final stderrSubscription = process.stderr.listen((_) {}, onError: (Object _) {});
    try {
      final exitCode = await process.exitCode.timeout(_versionProbeTimeout);
      if (exitCode == 0) {
        final version = stdoutBuffer.toString().trim();
        Log.d("[opencode] available: '$executablePath --version' -> ${version.isEmpty ? "exit 0 (no output)" : version}");
        return const PluginAvailable();
      }
      Log.d("[opencode] availability probe '$executablePath --version' exited with code $exitCode");
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } on TimeoutException {
      Log.d(
        "[opencode] availability probe '$executablePath --version' did not exit within "
        "${_versionProbeTimeout.inSeconds}s",
      );
      try {
        await processes.signalForce(pid: process.pid);
      } on Object {
        // Best-effort: reap the hung probe so it does not linger.
      }
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } on Object catch (error) {
      Log.d("[opencode] availability probe '$executablePath --version' failed with error: $error");
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } finally {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
    }
  }

  /// Message for "the OpenCode binary could not be found / launched".
  String _notInstalledMessage({required String executablePath}) {
    return [
      "OpenCode was not found — the Sesori bridge needs the OpenCode CLI to run.",
      "",
      "Verify it is installed:  $executablePath --version",
      "Install OpenCode:        https://opencode.ai/docs#install",
    ].join("\n");
  }

  /// Message for "the OpenCode binary was found but `--version` failed/hung".
  String _notWorkingMessage({required String executablePath}) {
    return [
      'OpenCode is installed but did not respond to "$executablePath --version".',
      "",
      "Re-check your install:  $executablePath --version",
      "Reinstall OpenCode:     https://opencode.ai/docs#install",
    ].join("\n");
  }

  @override
  Future<OpenCodeBridgePlugin> start(PluginHost host) async {
    // Opportunistic database maintenance runs first, before any runtime state
    // is acquired (it moved here from the runner at the flip). The service is
    // documented never-throwing and the sqlite3 work runs in a worker isolate,
    // so awaiting it under the startup mutex keeps the event loop — and the
    // cooperative abort below — responsive. The catch is belt-and-suspenders:
    // best-effort maintenance must never be able to fail the bridge start.
    try {
      await (_optimizeDb ?? _defaultOptimizeDb)(environment: host.environment);
    } on Object catch (error, stackTrace) {
      Log.w("[opencode] database maintenance failed; continuing startup", error, stackTrace);
    }
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final config = host.config;
    final requestedPort = config.intValue("port");
    final noPassword = config.flag("no-password");
    // Mirror the legacy flow's `password.normalize()`: trim, and map a blank
    // value to "no password supplied" — otherwise the same CLI input would
    // select a different password (or demand auth the user never set) after
    // the flip.
    final providedPassword = config.value("password")?.normalize();

    // The host OpenCode binds to (managed mode) or is reached at (attach mode);
    // defaults to 127.0.0.1. The connect host is what the bridge dials for
    // HTTP/SSE/health — loopback when the bind host is a non-connectable
    // wildcard (0.0.0.0 / ::), otherwise the bind host itself.
    final bindHost = config.value("host")!.trim();
    final connectHost = resolveOpenCodeConnectHost(bindHost: bindHost);

    final probeClientFactory = _probeClientFactory ?? http.Client.new;
    const mapper = OpenCodeRecordMapper();

    final service = ManagedProcessService<OpenCodeOwnershipRecord>(
      ownershipRepository: HostJsonRuntimeOwnershipRepository<OpenCodeOwnershipRecord>(
        store: host.store,
        mapper: mapper,
        fileName: "opencode-processes.json",
        clock: host.clock,
      ),
      mapper: mapper,
      processes: host.processes,
      bridge: host.bridge,
      clock: host.clock,
      runtimeId: "opencode",
      gracefulShutdownWait: openCodeGracefulShutdownWait,
      // Backs the intentSideFile record timing: the start intent is written
      // here before spawn and resolved after. The bridge-private side file
      // never touches the frozen ownership file, and a leftover intent from a
      // crashed start is simply overwritten (then cleared) by the next one.
      intentStore: RuntimeStartIntentStore(store: host.store, fileName: "opencode-start-intent.json"),
    );

    late final ManagedRuntimeSpec<OpenCodeOwnershipRecord> spec;
    ManagedRuntimeHandle<OpenCodeOwnershipRecord>? handle;
    final int port;
    final String serverUrl;
    final String? apiPassword;

    if (config.flag("no-auto-start")) {
      // Attach mode: probe an existing server, never own or kill it.
      final attachPort = requestedPort!;
      port = attachPort;
      // Structured Uri so an IPv6 literal connect host is bracketed correctly.
      serverUrl = Uri(scheme: "http", host: connectHost, port: attachPort).toString();
      apiPassword = noPassword ? null : providedPassword;
      spec = buildOpenCodeManagedRuntimeSpec(
        host: host,
        executablePath: "",
        password: noPassword ? null : providedPassword,
        portPolicy: ExplicitPortPolicy(port: attachPort),
        probeClientFactory: probeClientFactory,
        bindHost: bindHost,
        connectHost: connectHost,
      );
      try {
        handle = await service.attach(spec: spec, port: attachPort, startAborted: host.startAborted);
        Log.i("[opencode] using existing server at $serverUrl (auto-start disabled)");
      } on PluginStartAbortedException {
        rethrow;
      } on PluginStartException catch (error) {
        Log.w(
          "[opencode] cannot reach OpenCode at port $attachPort (auto-start disabled): ${error.message}. "
          "Bridge will start anyway; start OpenCode manually to enable proxying.",
        );
        handle = null;
      }
    } else {
      // Managed mode: spawn and own a new server.
      final serverPassword = noPassword ? null : (providedPassword ?? generateOpenCodePassword(random: _random));
      apiPassword = serverPassword;
      // Precedence: an explicit --opencode-bin wins (trusted, no version gate),
      // else the path ensureRuntime resolved (a recent PATH install or the
      // managed download), exposed via the host.
      final explicitBin = config.value("bin")?.trim();
      final resolvedExecutable = (explicitBin != null && explicitBin.isNotEmpty)
          ? explicitBin
          : host.provisionedRuntimePath;

      if (resolvedExecutable == null) {
        // Runtime provisioning failed and no explicit binary was given. Stay
        // alive in a degraded state instead of failing the whole bridge: bind a
        // placeholder server URL the background cold-start keeps retrying,
        // exactly as the attach-unreachable path below does. A bridge restart
        // re-attempts provisioning.
        Log.w(
          "[opencode] no runnable OpenCode binary available; starting degraded. "
          "Install OpenCode or pass --opencode-bin, then restart.",
        );
        port = openCodeDefaultPort;
        // Structured Uri so an IPv6 literal connect host is bracketed correctly.
        serverUrl = Uri(scheme: "http", host: connectHost, port: port).toString();
        spec = buildOpenCodeManagedRuntimeSpec(
          host: host,
          executablePath: "",
          password: serverPassword,
          portPolicy: const ExplicitPortPolicy(port: openCodeDefaultPort),
          probeClientFactory: probeClientFactory,
          bindHost: bindHost,
          connectHost: connectHost,
        );
        handle = null;
      } else {
        final executablePath = resolvedExecutable;

        final RuntimePortPolicy portPolicy;
        if (requestedPort != null) {
          Log.d("[opencode] starting on port $requestedPort");
          // Pre-probe the explicit port so an occupied port fails with a
          // diagnosis instead of spawning a child doomed to lose the bind race.
          portPolicy = ExplicitPortPolicy(port: requestedPort, preProbeBindable: true);
        } else {
          Log.d("[opencode] starting on a dynamic port");
          portPolicy = DynamicPortPolicy(
            candidates: openCodeDynamicCandidates(candidates: _candidatePorts, random: _random),
            maxAttempts: dynamicOpenCodeMaxAttempts,
            reservedPort: openCodeDefaultPort,
            minPort: dynamicOpenCodePortMin,
            maxPort: dynamicOpenCodePortMax,
            // A spawn that cannot even launch (e.g. ENOENT on the binary) fails
            // the same way on every candidate — fail fast instead of retrying.
            failFastOnSpawnError: true,
          );
        }

        spec = buildOpenCodeManagedRuntimeSpec(
          host: host,
          executablePath: executablePath,
          password: serverPassword,
          portPolicy: portPolicy,
          probeClientFactory: probeClientFactory,
          bindHost: bindHost,
          connectHost: connectHost,
        );

        // start() cleans up stale owned runtimes, selects a port, spawns, and
        // confirms health before returning — rolling everything back (and throwing
        // PluginStartException / PluginStartAbortedException) on failure. The
        // replaced-bridge identities authorize cleanup to reclaim records owned
        // by a bridge this one just replaced, even when its pid still looks live.
        handle = await service.start(
          spec: spec,
          terminatedBridgeIdentities: host.bridge.terminatedBridgeIdentities,
          startAborted: host.startAborted,
        );
        port = handle.port;
        // Structured Uri so an IPv6 literal connect host is bracketed correctly.
        serverUrl = Uri(scheme: "http", host: connectHost, port: handle.port).toString();
        Log.d("[opencode] started on port ${handle.port}");
      }
    }

    // Honor a late abort: a managed start the supervisor returned just as the
    // bridge aborted must release the owned child before we surface it.
    if (host.startAborted.isAborted) {
      final ownedHandle = handle;
      if (ownedHandle != null && ownedHandle.isOwned) {
        await service.stopOwnedRuntime(record: ownedHandle.record!);
      }
      throw const PluginStartAbortedException();
    }

    final ownedRecord = handle?.record;

    final reporter = OpenCodeRuntimeStatusReporter(
      status: PluginStatusController(initial: const PluginStarting()),
      clock: host.clock,
      degradedDebounce: _degradedDebounce,
    );

    // Construct and arm the exit monitor with bounded restart: an unexpected
    // child exit restarts on the address-frozen port with backoff, surfacing
    // PluginFailed only when the attempts are exhausted or the port never
    // frees. An attached (un-owned) handle has no child, so arm() is a no-op.
    final monitor = ManagedRuntimeMonitor<OpenCodeOwnershipRecord>(
      service: service,
      spec: spec,
      status: reporter.status,
      clock: host.clock,
      runtimeId: "opencode",
      restartPolicy: buildOpenCodeRestartPolicy(),
    );
    if (handle != null) {
      monitor.arm(handle);
    }

    final api = (_buildApi ?? _defaultBuildApi)(
      serverUrl: serverUrl,
      password: apiPassword,
      onConnected: reporter.markConnected,
      onDisconnected: reporter.markDisconnected,
    );

    final plugin = OpenCodeBridgePlugin(
      api: api,
      reporter: reporter,
      monitor: monitor,
      service: service,
      ownedRecord: ownedRecord,
      port: port,
      serverUrl: serverUrl,
    );

    if (handle == null) {
      // Attach probe failed: the server is already known to be unreachable, and
      // the cold-start has no bound of its own — a wrong localhost process that
      // accepts but never answers would hang start() under the bridge's startup
      // mutex. Keep the legacy fail-soft shape instead: report degraded now and
      // run the cold-start in the background; the SSE stream keeps retrying and
      // recovers the tracker when the server appears.
      reporter.markDegradedNow();
      unawaited(
        api.initialize().catchError((Object error, StackTrace stackTrace) {
          Log.w("[opencode] background cold-start did not complete cleanly: $error");
        }),
      );
    } else {
      // Await cold-start (previously fire-and-forget). A failure leaves the
      // plugin started but degraded rather than failing the whole bridge — the
      // server answered a health probe, so it is addressable; the SSE stream
      // keeps retrying and recovers the tracker.
      //
      // The await is bounded by [_coldStartBudget]: a service that passed the
      // health probe but stalls a REST call must not hang start() under the
      // bridge's cross-instance startup mutex. Past the budget the cold-start
      // keeps running in the background and the plugin starts degraded.
      final coldStart = api.initialize();
      var budgetExceeded = false;
      // The sink keeps a post-budget failure from surfacing as an unhandled
      // async error once the await below has moved on; the awaited path
      // observes (and logs) every pre-budget failure itself.
      unawaited(
        coldStart.catchError((Object error, StackTrace stackTrace) {
          if (budgetExceeded) {
            Log.w("[opencode] cold-start failed after the start budget: $error");
          }
        }),
      );
      try {
        await coldStart.timeout(
          _coldStartBudget,
          onTimeout: () {
            budgetExceeded = true;
            Log.w(
              "[opencode] cold-start did not finish within ${_coldStartBudget.inSeconds}s — "
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
        Log.w("[opencode] cold-start did not complete cleanly: $error");
        reporter.markDegradedNow();
      }
    }

    // The cold-start is a phase boundary like any other: an abort observed here
    // must roll back everything acquired so far (api/SSE transport, monitor,
    // the owned child) before surfacing, or an aborted start leaks a live
    // runtime. The wrapper's shutdown owns exactly that ordered teardown.
    if (host.startAborted.isAborted) {
      try {
        await plugin.shutdown(budget: null);
      } on Object catch (error) {
        Log.e("[opencode] rollback after aborted start failed: $error");
      }
      throw const PluginStartAbortedException();
    }

    return plugin;
  }
}
