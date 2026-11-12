import "dart:async";
import "dart:io" as io;

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
import "../api/parsers/codex_sub_agent_item_parser.dart";
import "../codex_app_server_client.dart";
import "../codex_config_reader.dart";
import "../codex_event_mapper.dart";
import "../codex_metadata_repository.dart";
import "../codex_plugin_impl.dart";
import "../codex_stdio_app_server_client.dart";
import "../repositories/codex_authentication_repository.dart";
import "../repositories/codex_catalog_repository.dart";
import "../repositories/codex_message_repository.dart";
import "../repositories/codex_sub_agent_tracker.dart";
import "../repositories/codex_tool_lifecycle_tracker.dart";
import "../repositories/codex_tool_outcome_repository.dart";
import "../repositories/mappers/codex_image_attachment_mapper.dart";
import "../repositories/mappers/codex_rollout_tool_mapper.dart";
import "../repositories/mappers/codex_session_mapper.dart";
import "../repositories/mappers/codex_user_content_mapper.dart";
import "../services/codex_authentication_service.dart";
import "../services/codex_rollout_tailer.dart";
import "../services/codex_session_service.dart";
import "codex_desktop_app_locator.dart";
import "codex_ownership_record.dart";
import "codex_record_mapper.dart";
import "codex_runtime_manifest.dart";
import "codex_runtime_policy.dart";

const int _setupProbeOutputLimit = 64 * 1024;

/// Composes the [CodexPlugin] for one `codex app-server` URL. The descriptor
/// and the plugin tests share it, so tests exercise the production wiring.
CodexPlugin buildCodexPlugin({
  required String serverUrl,
  required Map<String, String> environment,
  required ServerClock clock,
  required CodexToolOutcomeRepository toolOutcomeRepository,
  required String launchDirectory,
  required CodexAppServerClient Function()? clientFactory,
  required void Function()? onConnected,
  required void Function()? onDisconnected,
  required Future<void> runtimeExit,
  required Duration keepaliveInterval,
  required Duration rolloutPollInterval,
}) {
  final configReader = CodexConfigReader(environment: environment);
  final rolloutApi = CodexRolloutApi(environment: environment);
  const imageAttachmentMapper = CodexImageAttachmentMapper();
  const rolloutToolMapper = CodexRolloutToolMapper(
    imageAttachmentMapper: imageAttachmentMapper,
  );
  const imageBearingItemParser = CodexImageBearingItemParser();
  const userContentMapper = CodexUserContentMapper();
  final catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);
  final messageRepository = CodexMessageRepository(
    rolloutApi: rolloutApi,
    rolloutToolMapper: rolloutToolMapper,
    userContentMapper: userContentMapper,
  );
  return CodexPlugin.composed(
    serverUrl: serverUrl,
    clientFactory: clientFactory,
    sessionService: CodexSessionService(
      catalogRepository: catalogRepository,
      messageRepository: messageRepository,
      metadataRepository: CodexMetadataRepository(
        configReader: configReader,
      ),
      toolOutcomeRepository: toolOutcomeRepository,
      subAgentTracker: CodexSubAgentTracker(),
      sessionMapper: const CodexSessionMapper(),
      launchDirectory: launchDirectory,
    ),
    messageRepository: messageRepository,
    eventMapper: CodexEventMapper(
      pluginId: CodexPlugin.pluginId,
      projectCwd: launchDirectory,
      imageAttachmentMapper: imageAttachmentMapper,
      imageBearingItemParser: imageBearingItemParser,
      rolloutToolMapper: rolloutToolMapper,
      userContentMapper: userContentMapper,
      clock: clock,
      config: configReader.readDefaults(),
    ),
    rolloutTailer: CodexRolloutTailer(
      rolloutApi: rolloutApi,
      catalogRepository: catalogRepository,
      pollInterval: rolloutPollInterval,
    ),
    toolLifecycleTracker: CodexToolLifecycleTracker(
      rolloutToolMapper: rolloutToolMapper,
    ),
    toolOutcomeRepository: toolOutcomeRepository,
    commandExecutionParser: const CodexCommandExecutionParser(),
    fileChangeParser: const CodexFileChangeParser(),
    imageBearingItemParser: imageBearingItemParser,
    subAgentItemParser: const CodexSubAgentItemParser(),
    projectCwd: launchDirectory,
    onConnected: onConnected,
    onDisconnected: onDisconnected,
    runtimeExit: runtimeExit,
    keepaliveInterval: keepaliveInterval,
  );
}

/// The Codex plugin descriptor: it owns the full `codex app-server` runtime
/// lifecycle (runtime provisioning, stale cleanup, start, health, ownership
/// persistence, exit monitoring) over the [PluginHost] and the
/// `sesori_plugin_runtime` supervisor — mirroring the OpenCode descriptor,
/// adapted for codex's loopback-WebSocket transport.
///
/// Registered in the bridge plugin registry; eligible unless its ID appears in
/// the bridge plugin denylist.
/// Unlike OpenCode there is no attach (`--no-auto-start`) mode and no crash
/// restart: the codex WebSocket client does not auto-reconnect, so an
/// unexpected child exit surfaces as `PluginFailed`, and a runtime that cannot
/// be provisioned fails the start rather than degrading.
class const CodexPluginDescriptor({
  /// Test seam for desktop-app CLI candidates. Production passes null and
  /// enumerates them with [codexDesktopAppCliCandidates] for the current
  /// platform.
  required final List<String>? _desktopAppCliCandidates,
}) extends BridgePluginDescriptor implements InteractivePluginAuthenticationDescriptor {
  static CodexPluginDescriptor production() {
    return const CodexPluginDescriptor(desktopAppCliCandidates: null);
  }

  @override
  bool get supportsPromptAttachments => true;

  @override
  Set<PluginMcpCapability> get mcpCapabilities => const {
    PluginMcpCapability.management,
    PluginMcpCapability.authentication,
    PluginMcpCapability.connectorSetup,
  };

  /// MCP is read harness-wide or for an existing thread; project scope answers
  /// unsupported scope.
  @override
  Set<PluginMcpScopeKind> get mcpScopes => const {PluginMcpScopeKind.harness, PluginMcpScopeKind.session};

  /// Backend-namespaced ownership filename in shared runtime storage.
  static const String ownershipFileName = "codex-processes.json";

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

  String? _explicitBin({required PluginConfig config}) {
    final value = config.value("bin")?.trim();
    if (value == null || value.isEmpty || value == "codex") return null;
    return value;
  }

  List<String> _desktopCandidates({required Map<String, String> environment}) {
    return _desktopAppCliCandidates ??
        codexDesktopAppCliCandidates(
          environment: environment,
          os: PlatformOs.fromOperatingSystem(operatingSystem: io.Platform.operatingSystem),
        );
  }

  Future<ManagedRuntimeSelection> _selectRuntime({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal abortSignal,
    required int? maxCapturedOutputCharactersPerStream,
  }) {
    const manifest = CodexRuntimeManifest();
    return ManagedRuntimeSelectionService(
      manifest: manifest,
      versionValidator: RuntimeVersionValidator(
        commandExecutor: HostProcessCommandExecutor(
          includeParentEnvironment: true,
          processes: processes,
          runInShell: io.Platform.isWindows,
          maxCapturedOutputCharactersPerStream: maxCapturedOutputCharactersPerStream,
        ),
        manifest: manifest,
        probeTimeout: codexVersionProbeTimeout,
        executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
      ),
      inventory: const ManagedRuntimeInventory(manifest: manifest),
    ).select(
      explicitExecutablePath: _explicitBin(config: config),
      fallbackExecutableCandidates: _desktopCandidates(environment: environment),
      environment: environment,
      stateDirectory: stateDirectory,
      abortSignal: abortSignal,
    );
  }

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
    if (_explicitBin(config: config) != null) return false;
    final PlatformTarget target;
    try {
      target = PlatformTarget.current();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] platform detection failed; managed install unavailable", error, stackTrace);
      return false;
    }
    return const CodexRuntimeManifest().supportsManagedInstallOn(target: target);
  }

  @override
  Future<bool> needsManagedRuntimeUpgrade({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
  }) async {
    if (!managementCapabilities(config: config).contains(PluginControlCapability.install)) return false;
    const manifest = CodexRuntimeManifest();
    final executor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    return await const ManagedRuntimeComposition()
        .createUpgradeService(
          manifest: manifest,
          versionValidator: RuntimeVersionValidator(
            commandExecutor: executor,
            manifest: manifest,
            probeTimeout: codexVersionProbeTimeout,
            executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
          ),
        )
        .shouldUpgrade(environment: environment, stateDirectory: stateDirectory);
  }

  @override
  Stream<RuntimeProvisionProgress> installRuntime({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal startAborted,
    required RuntimeInUseSignal runtimeInUse,
  }) async* {
    const manifest = CodexRuntimeManifest();
    final commandExecutor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: null,
    );
    final pathVersionValidator = RuntimeVersionValidator(
      commandExecutor: HostProcessCommandExecutor(
        includeParentEnvironment: true,
        processes: processes,
        runInShell: io.Platform.isWindows,
        maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
      ),
      manifest: manifest,
      probeTimeout: codexVersionProbeTimeout,
      executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
    );
    final httpClient = http.Client();
    try {
      final installService = const ManagedRuntimeComposition().createInstaller(
        manifest: manifest,
        commandExecutor: commandExecutor,
        downloadClient: BinaryDownloadClient(httpClient: httpClient),
        candidateValidator: RuntimeVersionValidator(
          commandExecutor: commandExecutor,
          manifest: manifest,
          probeTimeout: codexVersionProbeTimeout,
          executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
        ),
        pathAuthority: RuntimeVersionManagedRuntimePathAuthority(
          manifest: manifest,
          versionValidator: pathVersionValidator,
        ),
        assetResolver: ({required target}) async => manifest.assetFor(target: target),
      );
      yield* installService.install(
        environment: environment,
        stateDirectory: stateDirectory,
        startAborted: startAborted,
        runtimeInUse: runtimeInUse,
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
      return inventory.hasOutdatedVersion(stateDirectory: stateDirectory)
          ? "This bridge needs a newer Codex. Install it from Sesori to update the managed runtime."
          : "Install Codex from Sesori, or install it locally and retry setup detection.";
    }

    final selection = await _selectRuntime(
      config: config,
      processes: processes,
      environment: environment,
      stateDirectory: stateDirectory,
      abortSignal: StartAbortSignal.never,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    final ManagedRuntimeSelected selectedRuntime;
    switch (selection) {
      case ManagedRuntimeSelected():
        selectedRuntime = selection;
      case ManagedRuntimeNotSelected(:final primaryRejection):
        final hasExplicitBinary = _explicitBin(config: config) != null;
        if (selection is ManagedRuntimePathNotSelected) {
          return switch (primaryRejection) {
            ManagedRuntimeVersionRejected(:final version) => PluginSetupRuntimeOutdated(
              actionHint: "Update the global Codex installation to ${manifest.minPathVersion.raw} or newer.",
              runtimeVersion: version.raw,
            ),
            ManagedRuntimeProbeRejected() => const PluginSetupUnknown(
              actionHint:
                  "The global Codex installation could not be verified. Check it locally and retry setup detection.",
            ),
          };
        }
        return switch (primaryRejection) {
          ManagedRuntimeProbeRejected(outcome: RuntimeProbeMissing()) => PluginSetupRuntimeMissing(
            actionHint: hasExplicitBinary
                ? "Fix the configured Codex binary path, then restart the bridge."
                : missingRuntimeHint(),
          ),
          ManagedRuntimeProbeRejected(outcome: RuntimeProbeTimedOut()) => const PluginSetupUnknown(
            actionHint: "Codex did not answer its setup check. Verify the local installation and retry.",
          ),
          ManagedRuntimeProbeRejected(outcome: RuntimeProbeFailed()) => const PluginSetupUnknown(
            actionHint: "Codex setup could not be determined. Verify the local installation and retry.",
          ),
          ManagedRuntimeProbeRejected(outcome: RuntimeProbeNonZeroExit()) => const PluginSetupUnknown(
            actionHint: "Codex did not answer its setup check. Verify the local installation and retry.",
          ),
          ManagedRuntimeProbeRejected(outcome: RuntimeProbeUnrecognized()) => const PluginSetupUnknown(
            actionHint: "Codex returned an unrecognized version. Update Codex and retry.",
          ),
          ManagedRuntimeVersionRejected() =>
            hasExplicitBinary
                ? const PluginSetupUnavailable(
                    actionHint: "The configured Codex binary is too old. Update it and restart the bridge.",
                  )
                : PluginSetupRuntimeMissing(
                    actionHint: missingRuntimeHint(),
                  ),
        };
    }
    final executable = selectedRuntime.binaryPath;
    final runtimeVersion = selectedRuntime.version.raw;
    final executor = HostProcessCommandExecutor(
      includeParentEnvironment: true,
      processes: processes,
      runInShell: io.Platform.isWindows,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );

    final CommandResult loginResult;
    try {
      loginResult = await executor.run(
        executable: executable,
        arguments: const ["login", "status"],
        workingDirectory: null,
        environment: environment,
        timeout: codexVersionProbeTimeout,
      );
    } on Object catch (error, stackTrace) {
      Log.w("[codex] `codex login status` failed during setup inspection", error, stackTrace);
      return PluginSetupUnknown.versioned(
        actionHint: "Codex authentication could not be determined. Run `codex login status` locally and retry.",
        runtimeVersion: runtimeVersion,
      );
    }
    final statusOutput = _normalizedStatusOutput(result: loginResult);
    if (statusOutput.contains("not logged in") || statusOutput.contains("logged out")) {
      return PluginSetupAuthenticationRequired.versioned(
        actionHint: "Sign in to Codex, then retry setup detection.",
        runtimeVersion: runtimeVersion,
      );
    }
    if (loginResult.exitCode == 0 && statusOutput.contains("logged in")) {
      return PluginSetupReady.versioned(runtimeVersion: runtimeVersion);
    }
    return PluginSetupUnknown.versioned(
      actionHint: "Codex authentication could not be determined. Run `codex login status` locally and retry.",
      runtimeVersion: runtimeVersion,
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
    if (_explicitBin(config: host.config) != null) {
      return;
    }

    const manifest = CodexRuntimeManifest();
    yield* const ManagedRuntimeComposition()
        .createProvisioner(
          manifest: manifest,
          versionValidator: RuntimeVersionValidator(
            commandExecutor: HostProcessCommandExecutor(
              includeParentEnvironment: true,
              processes: host.processes,
              runInShell: io.Platform.isWindows,
              maxCapturedOutputCharactersPerStream: null,
            ),
            manifest: manifest,
            probeTimeout: codexVersionProbeTimeout,
            executableLocator: const IoHostExecutableLocator(platformIsWindows: null),
          ),
          fallbackExecutableCandidates: _desktopCandidates(environment: host.environment),
        )
        .provision(host: host, explicitExecutablePath: null);
  }

  @override
  PluginAuthenticationOperation authenticate({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required HostJsonStore store,
    required StartAbortSignal aborted,
  }) => PluginAuthenticationOperation.deviceCode(
    events: _authenticate(
      config: config,
      processes: processes,
      environment: environment,
      stateDirectory: stateDirectory,
      aborted: aborted,
    ),
  );

  Stream<PluginAuthenticationDeviceCodeEvent> _authenticate({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
    required String stateDirectory,
    required StartAbortSignal aborted,
  }) async* {
    final selection = await _selectRuntime(
      config: config,
      processes: processes,
      environment: environment,
      stateDirectory: stateDirectory,
      abortSignal: aborted,
      maxCapturedOutputCharactersPerStream: _setupProbeOutputLimit,
    );
    if (aborted.isAborted) {
      throw const PluginStartAbortedException();
    }
    final String executable;
    switch (selection) {
      case ManagedRuntimeSelected(:final binaryPath):
        executable = binaryPath;
      case ManagedRuntimeNotSelected():
        yield const PluginAuthenticationFailed(
          message: "No supported Codex runtime is available for login.",
        );
        return;
    }

    final client = CodexStdioAppServerClient(
      processes: processes,
      executable: executable,
      environment: environment,
      shutdownTimeout: codexGracefulShutdownWait,
    );
    final api = CodexAppServerApi(client: client);
    yield* CodexAuthenticationService(
      client: client,
      repository: CodexAuthenticationRepository(
        appServerApi: api,
        requestTimeout: codexVersionProbeTimeout,
      ),
      aborted: aborted,
      requestTimeout: codexVersionProbeTimeout,
    ).authenticate();
  }

  String _normalizedStatusOutput({required CommandResult result}) {
    final combined = "${result.stdout}\n${result.stderr}";
    return stripAnsi(value: combined).trim().toLowerCase();
  }

  @override
  Future<ManagedRuntimeBridgePlugin<CodexOwnershipRecord, CodexPlugin>> start(PluginHost host) async {
    if (host.startAborted.isAborted) {
      throw const PluginStartAbortedException();
    }

    final config = host.config;
    final requestedPort = config.intValue("port");
    // Precedence: an explicit --codex-bin override wins (trusted, no version
    // gate); otherwise the path ensureRuntime resolved (a recent PATH codex or
    // the managed download), exposed via the host.
    final executablePath = _explicitBin(config: config) ?? host.provisionedRuntimePath;
    if (executablePath == null) {
      // Runtime provisioning failed and no explicit binary was given. codex has
      // no attach/degraded mode (its WebSocket client cannot reconnect), so it
      // needs a real binary to run — fail the start with actionable guidance
      // rather than spawning an empty command.
      throw const PluginStartException.userFacing(
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
      isWindows: io.Platform.isWindows,
      runtimeId: "codex",
      gracefulShutdownWait: codexGracefulShutdownWait,
    );

    final RuntimePortPolicy portPolicy;
    if (requestedPort != null) {
      Log.d("[codex] starting on port $requestedPort");
      portPolicy = ExplicitPortPolicy(port: requestedPort);
    } else {
      Log.d("[codex] starting on a dynamic port");
      portPolicy = DynamicPortPolicy(
        candidates: codexDynamicCandidates(candidates: null, random: null),
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
      await service.stopOwnedRuntime(record: handle.record);
      throw const PluginStartAbortedException();
    }

    final reporter = ManagedRuntimeStatusReporter(
      status: PluginStatusController(initial: const PluginStarting()),
      clock: host.clock,
      degradedDebounce: const Duration(seconds: 5),
      disconnectOutcome: ManagedRuntimeDisconnectOutcome.degrade,
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

    final api = buildCodexPlugin(
      serverUrl: serverUrl,
      environment: host.environment,
      clock: host.clock,
      toolOutcomeRepository: CodexToolOutcomeRepository(
        storage: CodexToolOutcomeStorage(store: host.store, clock: host.clock),
      ),
      launchDirectory: io.Directory.current.path,
      clientFactory: null,
      onConnected: reporter.markConnected,
      onDisconnected: reporter.markDisconnected,
      runtimeExit: handle.process.exitCode,
      keepaliveInterval: const Duration(seconds: 30),
      rolloutPollInterval: const Duration(milliseconds: 50),
    );

    final plugin = ManagedRuntimeBridgePlugin<CodexOwnershipRecord, CodexPlugin>(
      api: api,
      managedApi: api,
      reporter: reporter,
      monitor: monitor,
      service: service,
      diagnostics: PluginDiagnostics(
        pluginId: Harness.codex.name,
        endpoint: serverUrl,
        details: <String, String>{"port": "$port", "mode": "managed"},
      ),
      displayName: "Codex",
      logContext: "codex",
      interruptOwnedOnly: false,
      // Codex has no first-call latency worth paying down before it is asked.
      onStartWarmUp: null,
    );

    // Await cold-start (the WebSocket connect + `initialize` handshake). A
    // failure leaves the plugin started but degraded rather than failing the
    // whole bridge — the listener accepted a TCP probe, so it is addressable.
    //
    // The await is bounded by [codexColdStartBudget]: a server that passed the
    // readiness probe but stalls the handshake must not hang start() under the
    // bridge's cross-instance startup mutex. Past the budget the cold-start
    // keeps running in the background and the plugin starts degraded.
    await const ManagedRuntimeColdStartService(
      budget: codexColdStartBudget,
      logTag: "codex",
    ).run(coldStart: api.initialize(), reporter: reporter);

    // The cold-start is a phase boundary: an abort observed here must roll back
    // everything acquired so far (api transport, monitor, the owned child)
    // before surfacing, or an aborted start leaks a live runtime.
    if (host.startAborted.isAborted) {
      try {
        await plugin.shutdown(budget: null);
      } on Object catch (error, stackTrace) {
        Log.e("[codex] rollback after aborted start failed", error, stackTrace);
      }
      throw const PluginStartAbortedException();
    }

    return plugin;
  }
}
