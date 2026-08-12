import "dart:async";
import "dart:io" as io;
import "dart:math";

import "package:http/http.dart" as http;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "../api/codex_app_server_api.dart";
import "../api/codex_rollout_api.dart";
import "../api/codex_tool_outcome_storage.dart";
import "../api/parsers/codex_command_execution_parser.dart";
import "../api/parsers/codex_file_change_parser.dart";
import "../api/parsers/codex_image_bearing_item_parser.dart";
import "../codex_config_reader.dart";
import "../codex_event_mapper.dart";
import "../codex_metadata_repository.dart";
import "../codex_plugin_impl.dart";
import "../codex_stdio_app_server_client.dart";
import "../repositories/codex_authentication_repository.dart";
import "../repositories/codex_catalog_repository.dart";
import "../repositories/codex_message_repository.dart";
import "../repositories/codex_tool_lifecycle_tracker.dart";
import "../repositories/codex_tool_outcome_repository.dart";
import "../repositories/mappers/codex_image_attachment_mapper.dart";
import "../repositories/mappers/codex_rollout_tool_mapper.dart";
import "../services/codex_authentication_service.dart";
import "../services/codex_rollout_tailer.dart";
import "../services/codex_session_service.dart";
import "codex_bridge_plugin.dart";
import "codex_desktop_app_locator.dart";
import "codex_managed_api.dart";
import "codex_ownership_record.dart";
import "codex_record_mapper.dart";
import "codex_runtime_manifest.dart";
import "codex_runtime_policy.dart";
import "codex_runtime_selection_service.dart";
import "codex_status_reporter.dart";

const int _setupProbeOutputLimit = 64 * 1024;

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
  required PluginHost host,
  required String serverUrl,
  required void Function() onConnected,
  required void Function() onDisconnected,
}) {
  final launchDirectory = io.Directory.current.path;
  final configReader = CodexConfigReader(environment: host.environment);
  final rolloutApi = CodexRolloutApi(environment: host.environment);
  const imageAttachmentMapper = CodexImageAttachmentMapper();
  const rolloutToolMapper = CodexRolloutToolMapper(
    imageAttachmentMapper: imageAttachmentMapper,
  );
  const imageBearingItemParser = CodexImageBearingItemParser();
  final catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);
  final toolOutcomeRepository = CodexToolOutcomeRepository(
    storage: CodexToolOutcomeStorage(
      store: host.store,
      clock: host.clock,
    ),
  );
  return CodexPlugin.composed(
    serverUrl: serverUrl,
    capabilityToken: null,
    clientFactory: null,
    sessionService: CodexSessionService(
      catalogRepository: catalogRepository,
      messageRepository: CodexMessageRepository(
        rolloutApi: rolloutApi,
        rolloutToolMapper: rolloutToolMapper,
      ),
      metadataRepository: CodexMetadataRepository(
        configReader: configReader,
      ),
      toolOutcomeRepository: toolOutcomeRepository,
      launchDirectory: launchDirectory,
    ),
    eventMapper: CodexEventMapper(
      pluginId: CodexPlugin.pluginId,
      projectCwd: launchDirectory,
      imageAttachmentMapper: imageAttachmentMapper,
      imageBearingItemParser: imageBearingItemParser,
      rolloutToolMapper: rolloutToolMapper,
      config: configReader.readDefaults(),
    ),
    rolloutTailer: CodexRolloutTailer(
      rolloutApi: rolloutApi,
      catalogRepository: catalogRepository,
      pollInterval: const Duration(milliseconds: 50),
    ),
    toolLifecycleTracker: CodexToolLifecycleTracker(
      rolloutToolMapper: rolloutToolMapper,
    ),
    toolOutcomeRepository: toolOutcomeRepository,
    commandExecutionParser: const CodexCommandExecutionParser(),
    fileChangeParser: const CodexFileChangeParser(),
    imageBearingItemParser: imageBearingItemParser,
    projectCwd: launchDirectory,
    onConnected: onConnected,
    onDisconnected: onDisconnected,
    keepaliveInterval: const Duration(seconds: 30),
  );
}

/// The Codex plugin descriptor: it owns the full `codex app-server` runtime
/// lifecycle (runtime provisioning, stale cleanup, start, health, ownership
/// persistence, exit monitoring) over the [PluginHost] and the
/// `sesori_plugin_runtime` supervisor — mirroring the OpenCode descriptor,
/// adapted for codex's loopback-WebSocket transport.
///
/// Registered in `bin/bridge.dart` alongside the OpenCode descriptor; eligible
/// unless its ID appears in the bridge plugin denylist.
/// Unlike OpenCode there is no attach (`--no-auto-start`) mode and no crash
/// restart: the codex WebSocket client does not auto-reconnect, so an
/// unexpected child exit surfaces as `PluginFailed`, and a runtime that cannot
/// be provisioned fails the start rather than degrading.
///
/// The optional constructor parameters are test seams; the registered
/// descriptor is `const CodexPluginDescriptor()`.
class CodexPluginDescriptor extends BridgePluginDescriptor implements InteractivePluginAuthenticationDescriptor {
  const CodexPluginDescriptor({
    CodexManagedApiFactory? buildApi,
    Iterable<int>? candidatePorts,
    Random? random,
    Duration degradedDebounce = const Duration(seconds: 5),
    Duration coldStartBudget = codexColdStartBudget,
    Duration versionProbeTimeout = codexVersionProbeTimeout,
    ManagedRuntimeProvisionService? provisionService,
    List<String>? desktopAppCliCandidates,
  }) : _buildApi = buildApi,
       _candidatePorts = candidatePorts,
       _random = random,
       _degradedDebounce = degradedDebounce,
       _coldStartBudget = coldStartBudget,
       _versionProbeTimeout = versionProbeTimeout,
       _provisionService = provisionService,
       _desktopAppCliCandidates = desktopAppCliCandidates;

  final CodexManagedApiFactory? _buildApi;
  final Iterable<int>? _candidatePorts;
  final Random? _random;
  final Duration _degradedDebounce;
  final Duration _coldStartBudget;
  final Duration _versionProbeTimeout;

  /// Test seam for existing-runtime resolution. Production builds a default in
  /// [ensureRuntime] from the host's process service.
  final ManagedRuntimeProvisionService? _provisionService;

  /// Test seam for desktop-app CLI candidates. Production enumerates them with
  /// [codexDesktopAppCliCandidates] for the current platform.
  final List<String>? _desktopAppCliCandidates;

  @override
  bool get supportsPromptAttachments => true;

  /// Backend-namespaced ownership filename in shared runtime storage.
  static const String ownershipFileName = "codex-processes.json";

  /// Backend-namespaced start intent filename in shared runtime storage.
  static const String startIntentFileName = "codex-start-intent.json";

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
  String get id => Harness.codex.name;

  @override
  String get displayName => "Codex";

  @override
  PluginProjectOwnership get projectOwnership => PluginProjectOwnership.bridgeDerived;

  @override
  PluginSessionOptionsScope get sessionOptionsScope => PluginSessionOptionsScope.project;

  @override
  PluginStateStorage get stateStorage => PluginStateStorage.legacySharedRuntime;

  @override
  List<PluginOption> get options => cliOptions;

  @override
  Set<PluginControlCapability> managementCapabilities({required PluginConfig config}) {
    return {
      ...super.managementCapabilities(config: config),
      PluginControlCapability.authentication,
      if (_supportsManagedInstall(config: config)) PluginControlCapability.install,
    };
  }

  /// Whether the pinned managed codex runtime can be installed on request: no
  /// explicit `--codex-bin` override (that binary is authoritative) and a
  /// published release asset for this platform.
  bool _supportsManagedInstall({required PluginConfig config}) {
    if (CodexRuntimeSelectionService.explicitBinary(config: config) != null) return false;
    final PlatformTarget target;
    try {
      target = PlatformTarget.current();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] platform detection failed; managed install unavailable", error, stackTrace);
      return false;
    }
    return const CodexRuntimeManifest().assetFor(target: target) != null;
  }

  @override
  Stream<RuntimeProvisionProgress> installRuntime({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal startAborted,
  }) async* {
    const manifest = CodexRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: null,
    );
    final httpClient = http.Client();
    try {
      final installService = ManagedRuntimeInstallService(
        manifest: manifest,
        versionValidator: RuntimeVersionValidator(
          commandExecutor: commandExecutor,
          manifest: manifest,
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
      yield* installService.install(
        environment: environment,
        stateDirectory: stateDirectory,
        startAborted: startAborted,
      );
    } finally {
      httpClient.close();
    }
  }

  @override
  Future<PluginSetupStatus> inspectSetup({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    const manifest = CodexRuntimeManifest();
    const inventory = ManagedRuntimeInventory(manifest: manifest);

    String missingRuntimeHint() {
      return inventory.hasSupersededVersion(stateDirectory: stateDirectory)
          ? "This bridge needs a newer Codex. Install it from Sesori to update the managed runtime."
          : "Install Codex from Sesori, or install it locally and retry setup detection.";
    }

    final selection =
        await CodexRuntimeSelectionService(
          processes: processes,
          versionProbeTimeout: _versionProbeTimeout,
          maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
          desktopAppCliCandidates: _desktopAppCliCandidates,
        ).select(
          config: config,
          environment: environment,
          stateDirectory: stateDirectory,
          aborted: StartAbortSignal.never,
        );
    if (selection case CodexRuntimeNotSelected(:final failure, :final hasExplicitBinary)) {
      return switch (failure) {
        CodexRuntimeSelectionFailure.executableMissing => PluginSetupRuntimeMissing(
          actionHint: hasExplicitBinary
              ? "Fix the configured Codex binary path, then restart the bridge."
              : missingRuntimeHint(),
        ),
        CodexRuntimeSelectionFailure.probeTimedOut => const PluginSetupUnknown(
          actionHint: "Codex did not answer its setup check. Verify the local installation and retry.",
        ),
        CodexRuntimeSelectionFailure.probeFailed => const PluginSetupUnknown(
          actionHint: "Codex setup could not be determined. Verify the local installation and retry.",
        ),
        CodexRuntimeSelectionFailure.nonZeroExit => const PluginSetupUnknown(
          actionHint: "Codex did not answer its setup check. Verify the local installation and retry.",
        ),
        CodexRuntimeSelectionFailure.unrecognizedVersion => const PluginSetupUnknown(
          actionHint: "Codex returned an unrecognized version. Update Codex and retry.",
        ),
        CodexRuntimeSelectionFailure.unsupportedVersion =>
          hasExplicitBinary
              ? const PluginSetupUnavailable(
                  actionHint: "The configured Codex binary is too old. Update it and restart the bridge.",
                )
              : PluginSetupRuntimeMissing(
                  actionHint: missingRuntimeHint(),
                ),
      };
    }
    final executable = (selection as CodexRuntimeSelected).binaryPath;
    final executor = HostProcessCommandExecutor(
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );

    final CommandResult loginResult;
    try {
      loginResult = await executor.run(
        executable,
        const ["login", "status"],
        environment: environment,
        timeout: _versionProbeTimeout,
      );
    } on Object {
      return const PluginSetupUnknown(
        actionHint: "Codex authentication could not be determined. Run `codex login status` locally and retry.",
      );
    }
    final statusOutput = _normalizedStatusOutput(loginResult);
    if (statusOutput.contains("not logged in") || statusOutput.contains("logged out")) {
      return const PluginSetupAuthenticationRequired(
        actionHint: "Sign in to Codex, then retry setup detection.",
      );
    }
    if (loginResult.exitCode == 0 && statusOutput.contains("logged in")) {
      return const PluginSetupReady();
    }
    return const PluginSetupUnknown(
      actionHint: "Codex authentication could not be determined. Run `codex login status` locally and retry.",
    );
  }

  /// Resolves an existing codex runtime (a recent-enough PATH install, a
  /// recent-enough CLI bundled by the Codex desktop app, or the pinned managed
  /// runtime when already installed). Skipped when an explicit
  /// `--codex-bin` path is set (it already names the binary). The resolved
  /// launch path is surfaced via [ProvisionReady]; a failure is non-fatal here
  /// and `start()` fails with guidance.
  @override
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) async* {
    if (CodexRuntimeSelectionService.explicitBinary(config: host.config) != null) {
      return;
    }

    final injected = _provisionService;
    if (injected != null) {
      yield* injected.provision(host: host);
      return;
    }

    yield* CodexRuntimeSelectionService(
      processes: host.processes,
      versionProbeTimeout: _versionProbeTimeout,
      maxCapturedOutputCharactersPerStream: null,
      desktopAppCliCandidates: _desktopAppCliCandidates,
    ).provision(host: host);
  }

  @override
  Stream<PluginAuthenticationEvent> authenticate({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal aborted,
  }) async* {
    final selection =
        await CodexRuntimeSelectionService(
          processes: processes,
          versionProbeTimeout: _versionProbeTimeout,
          maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
          desktopAppCliCandidates: _desktopAppCliCandidates,
        ).select(
          config: config,
          environment: environment,
          stateDirectory: stateDirectory,
          aborted: aborted,
        );
    if (aborted.isAborted) {
      throw const PluginStartAbortedException();
    }
    if (selection case CodexRuntimeNotSelected()) {
      yield const PluginAuthenticationFailed(
        message: "No supported Codex runtime is available for login.",
      );
      return;
    }

    final client = CodexStdioAppServerClient(
      processes: processes,
      executable: (selection as CodexRuntimeSelected).binaryPath,
      environment: environment,
      shutdownTimeout: codexGracefulShutdownWait,
    );
    final api = CodexAppServerApi(client: client);
    yield* CodexAuthenticationService(
      client: client,
      repository: CodexAuthenticationRepository(
        appServerApi: api,
        requestTimeout: _versionProbeTimeout,
      ),
      aborted: aborted,
      requestTimeout: _versionProbeTimeout,
    ).authenticate();
  }

  String _normalizedStatusOutput(CommandResult result) {
    final combined = "${result.stdout}\n${result.stderr}";
    return combined.replaceAll(RegExp(r"\x1B\[[0-?]*[ -/]*[@-~]"), "").trim().toLowerCase();
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
    final executablePath = CodexRuntimeSelectionService.explicitBinary(config: config) ?? host.provisionedRuntimePath;
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
        fileName: ownershipFileName,
        clock: host.clock,
      ),
      mapper: mapper,
      processes: host.processes,
      bridge: host.bridge,
      clock: host.clock,
      runtimeId: "codex",
      gracefulShutdownWait: codexGracefulShutdownWait,
      intentStore: RuntimeStartIntentStore(store: host.store, fileName: startIntentFileName),
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

    final api = _buildApi == null
        ? _defaultBuildApi(
            host: host,
            serverUrl: serverUrl,
            onConnected: reporter.markConnected,
            onDisconnected: reporter.markDisconnected,
          )
        : _buildApi(
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
