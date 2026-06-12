import "dart:async";
import "dart:io" as io;

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as path;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        Log,
        PluginConfig,
        PluginFailed,
        PluginStartAbortedException,
        ProcessIdentity,
        ProcessUser,
        ServerClock,
        StartAbortController,
        StartAbortSignal;

import "../../auth/bridge_registration_api.dart";
import "../../auth/bridge_registration_repository.dart";
import "../../auth/bridge_registration_service.dart";
import "../../auth/login_email_api.dart";
import "../../auth/login_email_repository.dart";
import "../../auth/login_oauth_api.dart";
import "../../auth/login_oauth_service.dart";
import "../../auth/token.dart";
import "../../auth/token_manager.dart";
import "../../server/api/loopback_port_api.dart";
import "../../server/api/open_code_process_api.dart";
import "../../server/api/runtime_file_api.dart";
import "../../server/api/system_process_api.dart";
import "../../server/api/terminal_prompt_api.dart";
import "../../server/host/bridge_host_info_impl.dart";
import "../../server/host/bridge_host_json_store.dart";
import "../../server/host/bridge_host_port_service.dart";
import "../../server/host/bridge_host_process_service.dart";
import "../../server/host/bridge_plugin_host_impl.dart";
import "../../server/host/plugin_state_directory.dart" show openCodePluginId;
import "../../server/models/open_code_ownership_record.dart";
import "../../server/repositories/bridge_instance_repository.dart";
import "../../server/repositories/open_code_ownership_repository.dart";
import "../../server/repositories/open_code_process_repository.dart";
import "../../server/repositories/port_repository.dart";
import "../../server/repositories/process_repository.dart";
import "../../server/repositories/startup_mutex_repository.dart";
import "../../server/repositories/terminal_prompt_repository.dart";
import "../../server/services/bridge_instance_service.dart";
import "../../server/services/open_code_server_service.dart";
import "../../updater/api/archive_extractor_api.dart";
import "../../updater/api/checksum_manifest_api.dart";
import "../../updater/api/checksum_verifier_api.dart";
import "../../updater/api/file_replacement_api.dart";
import "../../updater/api/github_releases_api.dart";
import "../../updater/api/update_cache_api.dart";
import "../../updater/api/update_download_api.dart";
import "../../updater/foundation/update_lock.dart";
import "../../updater/foundation/update_policy.dart";
import "../../updater/foundation/update_relaunch_client.dart";
import "../../updater/models/distribution_target.dart";
import "../../updater/models/managed_runtime_paths.dart";
import "../../updater/repositories/installed_file_repository.dart";
import "../../updater/repositories/release_repository.dart";
import "../../updater/repositories/update_artifact_repository.dart";
import "../../updater/services/managed_runtime_path_service.dart";
import "../../updater/services/update_install_service.dart";
import "../../updater/services/update_service.dart";
import "../../version.dart";
import "../api/opencode_db_api.dart";
import "../foundation/process_runner.dart";
import "../log_failure_reporter.dart";
import "../models/bridge_config.dart";
import "../persistence/bridge_diagnostics.dart";
import "../persistence/database.dart";
import "../repositories/opencode_db_repository.dart";
import "../services/opencode_db_maintenance_service.dart";
import "../sse/sse_manager.dart";
import "bridge_cli_options.dart";
import "bridge_runtime.dart";
import "bridge_runtime_auth.dart";
import "bridge_runtime_server.dart";
import "bridge_shutdown_coordinator.dart";
import "legacy_opencode_descriptor.dart";
import "plugin_failure_latch.dart";
import "plugin_manager.dart";

Future<int> runBridgeApp({
  required BridgeCliOptions options,
  required PluginConfig pluginConfig,
  required String pluginId,
}) {
  return BridgeRuntimeRunner.run(
    options: options,
    pluginConfig: pluginConfig,
    pluginId: pluginId,
  );
}

class BridgeRuntimeRunner {
  const BridgeRuntimeRunner._();

  /// Soft deadline granted to the plugin's ordered `shutdown()` step. The
  /// shutdown coordinator's backstop is sized from it (budget + slack).
  static const Duration _pluginShutdownBudget = Duration(seconds: 10);

  static Future<int> run({
    required BridgeCliOptions options,
    required PluginConfig pluginConfig,
    required String pluginId,
  }) async {
    final failureLatch = PluginFailureLatch();
    final shutdownCoordinator = BridgeShutdownCoordinator(
      backstopExitCode: () => failureLatch.failure == null ? 0 : 1,
    );
    final subscriptions = CompositeSubscription();
    shutdownCoordinator.add(disposable: subscriptions.cancel);
    final httpClient = http.Client();
    final processRunner = ProcessRunner();
    const serverClock = ServerClock();
    final environment = io.Platform.environment;
    final currentUser = _resolveCurrentUser(environment: environment);
    if (currentUser == null) {
      Log.w("Failed to determine current user from environment");
    }

    final managedRuntimePaths = const ManagedRuntimePathService().currentPaths(
      environment: environment,
    );
    // Also the OpenCode plugin's state directory: its ownership file lives
    // here under a frozen cross-version contract (see pluginStateDirectoryPath).
    final runtimeDirectory = path.join(managedRuntimePaths.cacheDirectory, "runtime");
    final runtimeFileApi = RuntimeFileApi(runtimeDirectory: runtimeDirectory);
    final systemProcessApi = SystemProcessApi(
      processRunner: processRunner,
      clock: serverClock,
      isWindows: io.Platform.isWindows,
      platform: io.Platform.operatingSystem,
    );
    final processRepository = ProcessRepository(
      api: systemProcessApi,
      currentUser: currentUser,
    );
    final ownershipRepository = OpenCodeOwnershipRepository(
      runtimeFileApi: runtimeFileApi,
      clock: const Clock(),
    );
    final startupMutexRepository = StartupMutexRepository(
      runtimeFileApi: runtimeFileApi,
      processRepository: processRepository,
    );
    final terminalPromptApi = TerminalPromptApi(
      stdin: io.stdin,
      stdout: io.stdout,
      environment: environment,
    );
    final terminalPromptRepository = TerminalPromptRepository(
      api: terminalPromptApi,
    );
    final bridgeInstanceService = BridgeInstanceService(
      bridgeInstanceRepository: BridgeInstanceRepository(
        api: systemProcessApi,
        currentUser: currentUser,
      ),
      terminalPromptRepository: terminalPromptRepository,
      processRepository: processRepository,
      clock: serverClock,
    );
    shutdownCoordinator.add(disposable: httpClient.close);

    final runtimeAuthService = BridgeRuntimeAuthService(
      loginEmailRepository: LoginEmailRepository(
        emailAuthApi: LoginEmailApi(authBackendUrl: options.authBackendUrl),
        promptForCredentials: terminalPromptRepository.promptForEmailCredentials,
      ),
      loginOAuthService: LoginOAuthService(
        api: LoginOAuthApi(
          authBackendUrl: options.authBackendUrl,
          client: httpClient,
        ),
        browserLauncher: openOAuthBrowser,
      ),
      environment: environment,
    );

    try {
      final runtimeOwnershipError = unsupportedPackageRuntimeMessage(
        executablePath: io.Platform.resolvedExecutable,
        managedExecutablePath: managedRuntimePaths.binaryPath,
      );
      if (runtimeOwnershipError != null) {
        Log.e(runtimeOwnershipError);
        return 1;
      }

      final updateService = _createUpdateService(
        httpClient: httpClient,
        processRunner: processRunner,
        managedRuntimePaths: managedRuntimePaths,
      );
      await updateService.checkAndApplyUpdate(cliArgs: options.cliArgs);

      final authTokens = await runtimeAuthService.ensureAuthenticated(options: options);
      await runtimeAuthService.logAuthenticatedUser(
        authBackendUrl: options.authBackendUrl,
        accessToken: authTokens.accessToken,
      );
      _optimizeOpenCodeDbIfNeeded(environment: environment);

      final currentBridgeIdentity =
          await processRepository.inspectProcess(pid: io.pid) ??
          _fallbackCurrentBridgeIdentity(
            currentUser: currentUser,
            serverClock: serverClock,
            cliArgs: options.cliArgs,
          );
      final ownerSessionId = _buildOwnerSessionId(currentBridgeIdentity: currentBridgeIdentity);
      final openCodeServerService = OpenCodeServerService(
        openCodeProcessRepository: OpenCodeProcessRepository(
          api: OpenCodeProcessApi(
            processStarter: io.Process.start,
            httpClient: httpClient,
            clock: serverClock,
            environment: environment,
            currentUser: currentUser,
            isWindows: io.Platform.isWindows,
            platform: io.Platform.operatingSystem,
            probeTimeout: const Duration(seconds: 5),
          ),
        ),
        processRepository: processRepository,
        portRepository: const PortRepository(loopbackPortApi: LoopbackPortApi()),
        ownershipRepository: ownershipRepository,
        clock: serverClock,
        currentBridgeIdentity: currentBridgeIdentity,
        ownerSessionId: ownerSessionId,
        candidatePorts: null,
        random: null,
      );

      final startAbortController = StartAbortController();
      final pluginManager = PluginManager();
      pluginManager.register(
        id: openCodePluginId,
        shutdownBudget: _pluginShutdownBudget,
        starter: () => startLegacyOpenCodePlugin(
          pluginConfig: pluginConfig,
          currentBridgeIdentity: currentBridgeIdentity,
          ownerSessionId: ownerSessionId,
          startupMutexRepository: startupMutexRepository,
          bridgeInstanceService: bridgeInstanceService,
          ownershipRepository: ownershipRepository,
          openCodeServerService: openCodeServerService,
          processRepository: processRepository,
          runtimeFileApi: runtimeFileApi,
          runtimeDirectory: runtimeDirectory,
          serverClock: serverClock,
          environment: environment,
          currentUser: currentUser,
          startAborted: startAbortController.signal,
        ),
      );
      // The registry holds only the legacy OpenCode starter until the real
      // descriptor lands (PR 12), and BridgeConfig below still needs the
      // legacy-only serverUrl/serverPassword — hence the downcast.
      final plugin = await pluginManager.startPlugin(id: pluginId) as LegacyOpenCodeBridgePlugin;
      shutdownCoordinator.addOrdered(
        action: () => pluginManager.stopPlugin(id: pluginId),
        budget: _pluginShutdownBudget,
      );
      plugin.status
          .listen((status) {
            if (status is PluginFailed) {
              failureLatch.record(status);
            }
          })
          .addTo(subscriptions);

      final tokenManager = TokenManager(
        initialToken: authTokens.accessToken,
        authBackendUrl: options.authBackendUrl,
        loadTokens: loadTokens,
        saveTokens: saveTokens,
      );
      shutdownCoordinator.add(disposable: tokenManager.dispose);

      final bridgeRegistrationService = BridgeRegistrationService(
        repository: BridgeRegistrationRepository(
          api: BridgeRegistrationApi(
            authBackendUrl: options.authBackendUrl,
            client: httpClient,
          ),
        ),
        tokenRefresher: tokenManager,
        loadTokens: loadTokens,
        saveTokens: saveTokens,
        hostName: io.Platform.localHostname,
        platform: BridgeRegistrationService.currentPlatformName(),
      );

      final runtime = BridgeRuntime.create(
        config: BridgeConfig(
          relayURL: options.relayUrl,
          serverURL: plugin.serverUrl,
          serverPassword: plugin.serverPassword,
          authBackendURL: options.authBackendUrl,
          sseReplayWindow: SSEManager.defaultReplayWindow,
        ),
        plugin: plugin.api,
        httpClient: httpClient,
        accessTokenProvider: tokenManager,
        tokenRefresher: tokenManager,
        bridgeRegistrationService: bridgeRegistrationService,
        database: AppDatabase.create(),
        processRunner: processRunner,
        failureReporter: LogFailureReporter(),
      );
      shutdownCoordinator.add(disposable: runtime.close);
      // Defined stop semantics: stopping the active plugin cancels the
      // session first, so the bridge never keeps serving requests against a
      // stopped plugin. cancel() is idempotent and safe after run() returns,
      // which covers the ordinary post-session stop during shutdown.
      pluginManager.bindActiveSession(cancel: runtime.session.cancel);

      await BridgeDiagnostics().runAll();
      await startDebugServerIfRequested(
        debugPort: options.debugPort,
        runtime: runtime,
        shutdownCoordinator: shutdownCoordinator,
      );
      registerSignalHandlers(session: runtime.session, subscriptions: subscriptions);
      updateService.updateAvailable
          .listen((version) {
            Log.i("A new bridge version ($version) is available. Restart to update.");
          })
          .addTo(subscriptions);

      final startupFailure = failureLatch.failure;
      if (startupFailure != null) {
        Log.e("Plugin failed before the session could start: ${startupFailure.reason}");
        return 1;
      }
      failureLatch.bind((failure) {
        Log.e("Plugin failed: ${failure.reason}. Cancelling the session.");
        unawaited(runtime.session.cancel());
      });

      await runtime.session.run();
      return failureLatch.failure == null ? 0 : 1;
    } on PluginStartAbortedException {
      Log.i("Plugin start aborted as requested.");
      return 0;
    } catch (error) {
      Log.e("$error");
      return 1;
    } finally {
      await shutdownCoordinator.shutdown();
    }
  }

  /// Runs the legacy OpenCode descriptor under the cross-instance startup
  /// mutex: mutex → enforce-single-bridge → build host → descriptor.start.
  ///
  /// The mutex is held until `start()` settles; an abort would surface as
  /// [PluginStartAbortedException] from `start()` and is handled by the
  /// caller as "aborted as requested" (nothing triggers the abort signal
  /// yet — the cooperative checks arrive with the supervisor).
  ///
  /// Public so tests can drive the live orchestration with fakes;
  /// [buildPluginApi] is the test seam forwarded to the descriptor —
  /// production omits it and gets a real `OpenCodePlugin`.
  static Future<LegacyOpenCodeBridgePlugin> startLegacyOpenCodePlugin({
    required PluginConfig pluginConfig,
    required ProcessIdentity currentBridgeIdentity,
    required String ownerSessionId,
    required StartupMutexRepository startupMutexRepository,
    required BridgeInstanceService bridgeInstanceService,
    required OpenCodeOwnershipRepository ownershipRepository,
    required OpenCodeServerService openCodeServerService,
    required ProcessRepository processRepository,
    required RuntimeFileApi runtimeFileApi,
    required String runtimeDirectory,
    required ServerClock serverClock,
    required Map<String, String> environment,
    required ProcessUser? currentUser,
    required StartAbortSignal startAborted,
    LegacyPluginApiBuilder? buildPluginApi,
  }) {
    Future<LegacyOpenCodeBridgePlugin> attemptStart({required int attempt}) {
      return startupMutexRepository.withLock<LegacyOpenCodeBridgePlugin>(
        bridgePid: currentBridgeIdentity.pid,
        bridgeStartMarker: currentBridgeIdentity.startMarker,
        onLockAcquired: () async {
          Log.d("acquired startup lock");
          final resolution = await bridgeInstanceService.enforceSingleLiveBridge(
            currentPid: currentBridgeIdentity.pid,
          );
          switch (resolution.status) {
            case BridgeInstanceResolutionStatus.allowed:
              // The host contract promises the state directory exists before
              // start() runs. The store shares the runner's RuntimeFileApi:
              // its locked update() is only mutually exclusive within one
              // instance per directory.
              await io.Directory(runtimeDirectory).create(recursive: true);
              final host = BridgePluginHostImpl(
                config: pluginConfig,
                stateDirectory: runtimeDirectory,
                environment: Map<String, String>.unmodifiable(environment),
                clock: serverClock,
                startAborted: startAborted,
                bridge: BridgeHostInfoImpl(
                  identity: currentBridgeIdentity,
                  ownerSessionId: ownerSessionId,
                  processRepository: processRepository,
                ),
                processes: BridgeHostProcessService(
                  processStarter: io.Process.start,
                  processRepository: processRepository,
                  clock: serverClock,
                  currentUser: currentUser,
                  isWindows: io.Platform.isWindows,
                  platform: io.Platform.operatingSystem,
                ),
                ports: const BridgeHostPortService(loopbackPortApi: LoopbackPortApi()),
                store: BridgeHostJsonStore(fileApi: runtimeFileApi),
              );
              final descriptor = LegacyOpenCodeDescriptor(
                openCodeServerService: openCodeServerService,
                ownershipRepository: ownershipRepository,
                ownerSessionId: ownerSessionId,
                terminatedBridgeIdentities: resolution.terminatedBridges,
                buildPluginApi: buildPluginApi,
              );
              return descriptor.start(host);
            case BridgeInstanceResolutionStatus.declined:
              throw const BridgeRuntimeServerException(
                "Startup aborted because another Sesori bridge is already running and replacement was declined.",
              );
            case BridgeInstanceResolutionStatus.nonInteractive:
              throw const BridgeRuntimeServerException(
                "Startup aborted because another Sesori bridge is already running and this session is non-interactive.",
              );
          }
        },
        onLockRejected: (rejection) async {
          final lock = rejection.lock;
          final holderMatch = rejection.holderMatch;
          if (lock == null || holderMatch == null) {
            throw BridgeRuntimeServerException(
              "Startup aborted because another Sesori bridge startup is already in progress. If this persists, delete ${rejection.lockFilePath} and retry.",
            );
          }

          final status = await bridgeInstanceService.resolveStartupLockContention(
            lock: lock,
            holder: holderMatch,
            currentPid: currentBridgeIdentity.pid,
          );
          switch (status) {
            case BridgeInstanceResolutionStatus.allowed:
              if (attempt < 2) {
                return attemptStart(attempt: attempt + 1);
              }
              throw const BridgeRuntimeServerException(
                "Startup aborted because another Sesori bridge startup is still in progress after attempting replacement.",
              );
            case BridgeInstanceResolutionStatus.declined:
              throw const BridgeRuntimeServerException(
                "Startup aborted because another Sesori bridge startup is already in progress and replacement was declined.",
              );
            case BridgeInstanceResolutionStatus.nonInteractive:
              throw BridgeRuntimeServerException(
                "Startup aborted because another Sesori bridge startup is already in progress and this session is non-interactive. Bridge pid ${holderMatch.identity.pid} holds ${rejection.lockFilePath}; kill that process or delete the file to recover.",
              );
          }
        },
      );
    }

    return attemptStart(attempt: 1);
  }

  static UpdateService _createUpdateService({
    required http.Client httpClient,
    required ProcessRunner processRunner,
    required ManagedRuntimePaths managedRuntimePaths,
  }) {
    final installedFileRepository = InstalledFileRepository(
      fileReplacementApi: FileReplacementApi(processRunner: processRunner),
    );

    return UpdateService(
      releaseRepository: ReleaseRepository(
        api: GitHubReleasesApi(httpClient: httpClient),
        cache: UpdateCacheApi(
          cacheDirectory: managedRuntimePaths.cacheDirectory,
          clock: const Clock(),
        ),
        currentVersion: appVersion,
        target: currentDistributionTarget(),
      ),
      updateInstallerService: UpdateInstallService(
        updateArtifactRepository: UpdateArtifactRepository(
          downloadApi: UpdateDownloadApi(httpClient: httpClient),
          checksumManifestApi: ChecksumManifestApi(httpClient: httpClient),
          checksumVerifierApi: ChecksumVerifierApi(),
          archiveExtractorApi: ArchiveExtractorApi(processRunner: processRunner),
        ),
        installedFileRepository: installedFileRepository,
      ),
      installedFileRepository: installedFileRepository,
      updateLock: UpdateLock(currentPid: io.pid, processRunner: processRunner),
      updateRelaunchClient: UpdateRelaunchClient(processStarter: io.Process.start),
      installRoot: managedRuntimePaths.installRoot,
      executablePath: io.Platform.resolvedExecutable,
      managedExecutablePath: managedRuntimePaths.binaryPath,
      environment: io.Platform.environment,
    );
  }

  static void _optimizeOpenCodeDbIfNeeded({required Map<String, String> environment}) {
    final homeDir = environment["HOME"] ?? environment["USERPROFILE"];
    if (homeDir == null) {
      return;
    }

    OpenCodeDbMaintenanceService(
      repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
    ).optimizeIfNeeded(
      dbPath: '${environment["XDG_DATA_HOME"] ?? "$homeDir/.local/share"}/opencode/opencode.db',
    );
  }

  static ProcessUser? _resolveCurrentUser({required Map<String, String> environment}) => ProcessUser.fromRawUser(
    environment["USER"] ?? environment["USERNAME"],
  );

  static ProcessIdentity _fallbackCurrentBridgeIdentity({
    required ProcessUser? currentUser,
    required ServerClock serverClock,
    required List<String> cliArgs,
  }) {
    return ProcessIdentity(
      pid: io.pid,
      startMarker: null,
      executablePath: io.Platform.resolvedExecutable,
      commandLine: cliArgs.join(" "),
      ownerUser: currentUser,
      platform: io.Platform.operatingSystem,
      capturedAt: serverClock.now(),
    );
  }

  static String _buildOwnerSessionId({required ProcessIdentity currentBridgeIdentity}) {
    return '${currentBridgeIdentity.pid}:${currentBridgeIdentity.startMarker ?? currentBridgeIdentity.capturedAt.toIso8601String()}';
  }
}

void registerOwnedOpenCodeShutdown({
  required BridgeShutdownCoordinator shutdownCoordinator,
  required BridgeServerRuntime serverRuntime,
  required Future<void> Function(OpenCodeOwnershipRecord record) stopOwnedOpenCode,
}) {
  final ownedOpenCodeRecord = serverRuntime.ownedOpenCodeRecord;
  if (ownedOpenCodeRecord == null) {
    return;
  }

  shutdownCoordinator.add(
    disposable: () {
      return stopOwnedOpenCode(ownedOpenCodeRecord);
    },
  );
}
