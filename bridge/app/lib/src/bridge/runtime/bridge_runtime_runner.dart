import "dart:async";
import "dart:io" as io;

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as path;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgePlugin,
        BridgePluginDescriptor,
        Console,
        Log,
        PluginConfig,
        PluginFailed,
        PluginStartAbortedException,
        PluginUnavailable,
        ProcessIdentity,
        ProcessUser,
        ServerClock,
        StartAbortController,
        StartAbortSignal;

import "../../api/bridge_settings_api.dart";
import "../../auth/bridge_registration_api.dart";
import "../../auth/bridge_registration_repository.dart";
import "../../auth/bridge_registration_service.dart";
import "../../auth/login_email_api.dart";
import "../../auth/login_email_repository.dart";
import "../../auth/login_oauth_api.dart";
import "../../auth/login_oauth_service.dart";
import "../../auth/token.dart";
import "../../auth/token_manager.dart";
import "../../repositories/bridge_settings_repository.dart";
import "../../server/api/loopback_port_api.dart";
import "../../server/api/runtime_file_api.dart";
import "../../server/api/system_process_api.dart";
import "../../server/api/terminal_prompt_api.dart";
import "../../server/host/bridge_host_info_impl.dart";
import "../../server/host/bridge_host_json_store.dart";
import "../../server/host/bridge_host_port_service.dart";
import "../../server/host/bridge_host_process_service.dart";
import "../../server/host/bridge_plugin_host_impl.dart";
import "../../server/repositories/bridge_instance_repository.dart";
import "../../server/repositories/process_repository.dart";
import "../../server/repositories/startup_mutex_repository.dart";
import "../../server/repositories/terminal_prompt_repository.dart";
import "../../server/services/bridge_instance_service.dart";
import "../../updater/api/archive_extractor_api.dart";
import "../../updater/api/checksum_manifest_api.dart";
import "../../updater/api/checksum_verifier_api.dart";
import "../../updater/api/file_replacement_api.dart";
import "../../updater/api/github_releases_api.dart";
import "../../updater/api/update_cache_api.dart";
import "../../updater/api/update_download_api.dart";
import "../../updater/foundation/release_track.dart";
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
import "../foundation/process_runner.dart";
import "../log_failure_reporter.dart";
import "../models/bridge_config.dart";
import "../persistence/bridge_diagnostics.dart";
import "../persistence/database.dart";
import "../sse/sse_manager.dart";
import "bridge_cli_options.dart";
import "bridge_runtime.dart";
import "bridge_runtime_auth.dart";
import "bridge_runtime_server_exception.dart";
import "bridge_shutdown_coordinator.dart";
import "plugin_failure_latch.dart";
import "plugin_manager.dart";
import "plugin_registry.dart";

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
        browserOpenability: detectBrowserOpenability,
      ),
      environment: environment,
      loadTokens: loadTokens,
      saveTokens: saveTokens,
      clearTokens: clearTokens,
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

      // Resolve the configured release track once, here in the composition
      // root. Constructing settings access (BridgeSettingsApi reads HOME) or
      // reading the config can throw; a settings failure must never block the
      // bridge from starting, so any error falls back to the stable track.
      ReleaseTrack? configuredTrack;
      try {
        final settingsRepository = BridgeSettingsRepository(api: BridgeSettingsApi());
        configuredTrack = (await settingsRepository.loadSettings()).releaseTrack;
      } on Object catch (error) {
        Log.w("Failed to resolve release track; defaulting to stable: $error");
      }
      final releaseTrack = configuredTrack ?? ReleaseTrack.stable;
      if (releaseTrack == ReleaseTrack.internal) {
        Log.w("Release track: internal (pre-release auto-updates enabled)");
      } else {
        Log.d("Release track: ${releaseTrack.wireValue}");
      }

      final updateService = _createUpdateService(
        httpClient: httpClient,
        processRunner: processRunner,
        managedRuntimePaths: managedRuntimePaths,
        releaseTrack: releaseTrack,
      );
      await updateService.checkAndApplyUpdate(cliArgs: options.cliArgs);

      final authTokens = await runtimeAuthService.ensureAuthenticated(options: options);
      await runtimeAuthService.logAuthenticatedUser(
        authBackendUrl: options.authBackendUrl,
        accessToken: authTokens.accessToken,
      );

      final currentBridgeIdentity = await _resolveCurrentBridgeIdentity(
        processRepository: processRepository,
        currentUser: currentUser,
        serverClock: serverClock,
        cliArgs: options.cliArgs,
      );
      final ownerSessionId = _buildOwnerSessionId(currentBridgeIdentity: currentBridgeIdentity);

      final descriptor = knownPlugins.firstWhere((descriptor) => descriptor.id == pluginId);

      // Fail fast with clear, user-facing guidance if the selected plugin's
      // backend is unavailable — BEFORE the startup mutex and single-live-bridge
      // enforcement, so a missing backend (e.g. OpenCode not installed) can
      // never terminate a healthy resident bridge. The probe is read-only.
      final hostProcessService = BridgeHostProcessService(
        processStarter: io.Process.start,
        processRepository: processRepository,
        clock: serverClock,
        currentUser: currentUser,
        isWindows: io.Platform.isWindows,
        platform: io.Platform.operatingSystem,
      );
      final availability = await descriptor.checkAvailability(
        config: pluginConfig,
        processes: hostProcessService,
        environment: environment,
      );
      if (availability is PluginUnavailable) {
        Console.error(availability.message);
        return 1;
      }

      final startAbortController = StartAbortController();
      final pluginManager = PluginManager();
      pluginManager.register(
        id: descriptor.id,
        shutdownBudget: _pluginShutdownBudget,
        starter: () => startPluginUnderStartupMutex(
          descriptor: descriptor,
          pluginConfig: pluginConfig,
          currentBridgeIdentity: currentBridgeIdentity,
          ownerSessionId: ownerSessionId,
          startupMutexRepository: startupMutexRepository,
          bridgeInstanceService: bridgeInstanceService,
          processRepository: processRepository,
          runtimeFileApi: runtimeFileApi,
          runtimeDirectory: runtimeDirectory,
          serverClock: serverClock,
          environment: environment,
          currentUser: currentUser,
          startAborted: startAbortController.signal,
        ),
      );
      final plugin = await pluginManager.startPlugin(id: pluginId);
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
          pluginEndpoint: plugin.describe().endpoint ?? pluginId,
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
            Console.message("A new bridge version ($version) is available. Restart to update.");
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

  /// Runs the selected plugin descriptor under the cross-instance startup
  /// mutex: mutex → enforce-single-bridge → build host → descriptor.start.
  ///
  /// The mutex is held until `start()` settles; an abort surfaces as
  /// [PluginStartAbortedException] from `start()` and is handled by the
  /// caller as "aborted as requested", never as the error-exit path.
  ///
  /// Public so tests can drive the live orchestration with a fake
  /// [descriptor]; production passes the registry-selected one.
  static Future<BridgePlugin> startPluginUnderStartupMutex({
    required BridgePluginDescriptor descriptor,
    required PluginConfig pluginConfig,
    required ProcessIdentity currentBridgeIdentity,
    required String ownerSessionId,
    required StartupMutexRepository startupMutexRepository,
    required BridgeInstanceService bridgeInstanceService,
    required ProcessRepository processRepository,
    required RuntimeFileApi runtimeFileApi,
    required String runtimeDirectory,
    required ServerClock serverClock,
    required Map<String, String> environment,
    required ProcessUser? currentUser,
    required StartAbortSignal startAborted,
  }) {
    Future<BridgePlugin> attemptStart({required int attempt}) {
      return startupMutexRepository.withLock<BridgePlugin>(
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
                  terminatedBridgeIdentities: resolution.terminatedBridges,
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
    required ReleaseTrack releaseTrack,
  }) {
    final installedFileRepository = InstalledFileRepository(
      fileReplacementApi: FileReplacementApi(processRunner: processRunner),
    );

    // Opportunistically authenticate GitHub release checks when a token is
    // present in the environment. Unauthenticated requests share a 60/hour
    // per-IP budget that is easily exhausted behind shared/NAT'd networks; a
    // token lifts the bridge to the authenticated 5000/hour limit. Resolve the
    // first non-empty value so a blank GITHUB_TOKEN does not shadow a valid
    // GH_TOKEN.
    final githubToken = [
      io.Platform.environment['GITHUB_TOKEN'],
      io.Platform.environment['GH_TOKEN'],
    ].map((token) => token?.trim()).firstWhere(
      (token) => token != null && token.isNotEmpty,
      orElse: () => null,
    );

    return UpdateService(
      releaseRepository: ReleaseRepository(
        api: GitHubReleasesApi(httpClient: httpClient, authToken: githubToken),
        cache: UpdateCacheApi(
          cacheDirectory: managedRuntimePaths.cacheDirectory,
          clock: const Clock(),
        ),
        currentVersion: appVersion,
        target: currentDistributionTarget(),
        track: releaseTrack,
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

  static ProcessUser? _resolveCurrentUser({required Map<String, String> environment}) => ProcessUser.fromRawUser(
    environment["USER"] ?? environment["USERNAME"],
  );

  /// Resolves this bridge's own [ProcessIdentity], degrading to a locally
  /// constructed fallback when the process-table inspection returns null or
  /// throws.
  ///
  /// Capturing the live identity is best-effort: it only enriches the owner
  /// session id with the OS-reported start marker. The inspection shells out
  /// to `tasklist`/`ps`, which can time out (especially on Windows right after
  /// login). A failure here must never abort startup — the bridge has a
  /// complete fallback identity, so we log the degradation and use it.
  static Future<ProcessIdentity> _resolveCurrentBridgeIdentity({
    required ProcessRepository processRepository,
    required ProcessUser? currentUser,
    required ServerClock serverClock,
    required List<String> cliArgs,
  }) async {
    try {
      final inspected = await processRepository.inspectProcess(pid: io.pid);
      if (inspected != null) {
        return inspected;
      }
      Log.w("Could not find own process (pid ${io.pid}) in the process table; using fallback identity");
    } on Object catch (error) {
      Log.w("Failed to inspect own process (pid ${io.pid}); using fallback identity: $error");
    }
    return _fallbackCurrentBridgeIdentity(
      currentUser: currentUser,
      serverClock: serverClock,
      cliArgs: cliArgs,
    );
  }

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
