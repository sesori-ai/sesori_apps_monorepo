import "dart:async";
import "dart:io" as io;

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:meta/meta.dart";
import "package:path/path.dart" as path;
import "package:rxdart/rxdart.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show ArchiveExtractor, BinaryDownloadClient, ChecksumValidator, OsVersionFormatter, PlatformOs;
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
        ProvisionReady,
        RuntimeProvisionProgress,
        ServerClock,
        StartAbortController,
        StartAbortSignal;
import "package:sesori_shared/sesori_shared.dart" show DeviceInfo;

import "../../api/bridge_settings_api.dart";
import "../../api/control_secret_api.dart";
import "../../auth/bridge_registration_api.dart";
import "../../auth/bridge_registration_repository.dart";
import "../../auth/bridge_registration_service.dart";
import "../../auth/login_email_api.dart";
import "../../auth/login_email_repository.dart";
import "../../auth/login_oauth_api.dart";
import "../../auth/login_oauth_service.dart";
import "../../auth/token.dart";
import "../../auth/token_manager.dart";
import "../../control/control_channel_loss_listener.dart";
import "../../foundation/control_channel_client.dart";
import "../../repositories/bridge_settings_repository.dart";
import "../../server/api/loopback_port_api.dart";
import "../../server/api/runtime_file_api.dart";
import "../../server/api/system_process_api.dart";
import "../../server/api/terminal_prompt_api.dart";
import "../../server/foundation/bridge_restart_command_builder.dart";
import "../../server/foundation/bridge_restart_env.dart";
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
import "../../server/services/bridge_restart_service.dart";
import "../../updater/api/checksum_manifest_api.dart";
import "../../updater/api/github_releases_api.dart";
import "../../updater/api/managed_runtime_manifest_api.dart";
import "../../updater/api/platform_update_api.dart";
import "../../updater/api/update_attempt_api.dart";
import "../../updater/api/update_cache_api.dart";
import "../../updater/api/update_log_api.dart";
import "../../updater/foundation/filesystem_cleaner.dart";
import "../../updater/foundation/release_track.dart";
import "../../updater/foundation/update_lock.dart";
import "../../updater/foundation/update_message_formatter.dart";
import "../../updater/foundation/update_policy.dart";
import "../../updater/models/distribution_target.dart";
import "../../updater/models/managed_runtime_paths.dart";
import "../../updater/repositories/release_repository.dart";
import "../../updater/repositories/update_artifact_repository.dart";
import "../../updater/repositories/update_attempt_repository.dart";
import "../../updater/repositories/update_installation_repository.dart";
import "../../updater/repositories/update_log_repository.dart";
import "../../updater/services/managed_runtime_path_service.dart";
import "../../updater/services/update_apply_service.dart";
import "../../updater/services/update_install_service.dart";
import "../../updater/services/update_lifecycle_service.dart";
import "../../updater/services/update_reconciliation_service.dart";
import "../../updater/services/update_service.dart";
import "../../version.dart";
import "../foundation/process_runner.dart";
import "../foundation/process_runner_command_executor.dart";
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
import "runtime_provision_formatter.dart";

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
    // Set when a control-channel loss triggers shutdown, so BOTH the explicit
    // exit and the coordinator backstop report the abnormal code. A loss must
    // never look like a clean (0) exit, even if the stop hangs — and because
    // the backstop fires at (ordered budget + slack), its timing varies with
    // how many ordered steps are registered (none yet before the plugin
    // starts), so a fixed timeout race against it is not reliable.
    int? supervisedLossExitCode;
    final shutdownCoordinator = BridgeShutdownCoordinator(
      backstopExitCode: () => supervisedLossExitCode ?? (failureLatch.failure == null ? 0 : 1),
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
          clientType: "bridge_${PlatformOs.fromOperatingSystem(operatingSystem: io.Platform.operatingSystem).value}",
          device: _bridgeDeviceInfo(),
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
      // Supervised mode (desktop GUI): bring up the loopback control channel
      // before anything else so the GUI sees the helper connect promptly. Every
      // step here is gated by `--control-url`; standalone startup is unchanged.
      if (options.isSupervised) {
        await _startSupervisedControlChannel(
          options: options,
          shutdownCoordinator: shutdownCoordinator,
          requestAbnormalExit: (code) => supervisedLossExitCode = code,
        );
      }

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

      final updateLifecycle = _buildUpdateLifecycleService(
        httpClient: httpClient,
        processRunner: processRunner,
        managedRuntimePaths: managedRuntimePaths,
        releaseTrack: releaseTrack,
      );
      // Reconcile a prior in-place update first (fast, local): confirm a
      // pending activation, surface a prior failure, sweep residue. Best-effort:
      // reconciliation is maintenance and must never block startup.
      //
      // Gate it on the same skip check the periodic update path uses: a
      // non-managed binary (npm payload, dev build, CI, or updates disabled)
      // must not touch the managed install's attempt/residue state.
      final bool updatesEnabledForThisInstall = !shouldSkipUpdates(
        environment: environment,
        executablePath: io.Platform.resolvedExecutable,
        managedExecutablePath: managedRuntimePaths.binaryPath,
      );
      if (updatesEnabledForThisInstall) {
        try {
          await updateLifecycle.reconcile();
        } on Object catch (error) {
          Log.w("Update reconciliation failed (non-fatal): $error");
        }
      }

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
        isWindows: io.Platform.isWindows,
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
      // If this bridge was spawned by a restart, wait for the predecessor to
      // exit before single-live-bridge enforcement so the handoff is clean.
      final predecessorPidRaw = environment[sesoriRestartPredecessorPidEnvVar];
      final predecessorPid = predecessorPidRaw == null ? null : int.tryParse(predecessorPidRaw);
      if (predecessorPid != null) {
        await bridgeInstanceService.awaitPredecessorBridgeExit(
          predecessorPid: predecessorPid,
          timeout: const Duration(seconds: 30),
        );

        // The reconcile() above may have skipped because the restart predecessor
        // still held the update lock mid-apply. Now that it has exited and
        // released the lock, reconcile again so a pending activation (or failure)
        // from the predecessor's in-flight apply is confirmed/surfaced this
        // launch instead of lingering until a future restart.
        if (updatesEnabledForThisInstall) {
          try {
            await updateLifecycle.reconcile();
          } on Object catch (error) {
            Log.w("Update reconciliation after predecessor exit failed (non-fatal): $error");
          }
        }
      }

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

      final restartService = BridgeRestartService(
        processRepository: processRepository,
        commandBuilder: const BridgeRestartCommandBuilder(),
        binaryPath: managedRuntimePaths.binaryPath,
        cliArgs: options.cliArgs,
        currentPid: io.pid,
      );

      // Run startup diagnostics before composing the runtime so the
      // filesystem-access result can be carried into the health snapshot the
      // phone reads (to proactively warn about missing macOS Full Disk Access).
      final diagnostics = BridgeDiagnostics();
      final filesystemAccessOk = await diagnostics.checkFilesystemAccess();
      await diagnostics.checkGitAvailable();

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
        restartService: restartService,
        filesystemAccessOk: filesystemAccessOk,
      );
      shutdownCoordinator.add(disposable: runtime.close);
      // Defined stop semantics: stopping the active plugin cancels the
      // session first, so the bridge never keeps serving requests against a
      // stopped plugin. cancel() is idempotent and safe after run() returns,
      // which covers the ordinary post-session stop during shutdown.
      pluginManager.bindActiveSession(cancel: runtime.session.cancel);

      await startDebugServerIfRequested(
        debugPort: options.debugPort,
        runtime: runtime,
        shutdownCoordinator: shutdownCoordinator,
      );
      registerSignalHandlers(session: runtime.session, subscriptions: subscriptions);
      // Background: check + download + stage + apply-in-place on a 4h cadence.
      // The swap takes effect on the next launch (or a phone-triggered restart).
      shutdownCoordinator.add(disposable: updateLifecycle.dispose);
      updateLifecycle.start();

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

  /// Whether [url] is an acceptable supervised control-channel endpoint: a
  /// loopback host over ws/wss. The GUI hosts the control channel on loopback,
  /// so anything else is rejected — the bridge fails closed rather than sending
  /// the per-spawn bearer secret to a non-loopback endpoint (defense in depth,
  /// since `--control-url` is GUI-supplied and could be misconfigured/tampered).
  @visibleForTesting
  static bool isLoopbackControlUrl(Uri url) {
    if (url.scheme != "ws" && url.scheme != "wss") return false;
    final host = url.host.toLowerCase();
    return host == "127.0.0.1" || host == "localhost" || host == "::1";
  }

  /// Supervised-mode bootstrap: validate the loopback control URL, read the
  /// per-spawn secret off-argv (stdin), arm the parent-loss exit policy (ADR
  /// A9), then connect the GUI's loopback control channel. Both the client and
  /// the loss listener are torn down via the shutdown coordinator. Only ever
  /// called when `--control-url` is set.
  static Future<void> _startSupervisedControlChannel({
    required BridgeCliOptions options,
    required BridgeShutdownCoordinator shutdownCoordinator,
    required void Function(int code) requestAbnormalExit,
  }) async {
    final url = Uri.parse(options.controlUrl!);
    if (!isLoopbackControlUrl(url)) {
      throw StateError(
        "Refusing supervised control URL '${options.controlUrl}': must be a loopback ws/wss endpoint",
      );
    }

    final secret = await ControlSecretApi(input: io.stdin).readSecret();
    final controlChannelClient = ControlChannelClient(url: url, secret: secret);
    shutdownCoordinator.add(disposable: controlChannelClient.dispose);

    // Subscribe the parent-loss policy BEFORE connecting: the first
    // `disconnected` transition must never be missed (reconnect failures don't
    // re-emit it), otherwise a GUI crash during this startup window would leave
    // the ADR A9 grace timer un-armed and the helper running with no parent.
    final lossListener = ControlChannelLossListener(
      connectionState: controlChannelClient.connectionState,
      // Don't hard-exit straight from the loss timer: that bypasses the ordered
      // plugin stop in the shutdown coordinator and could orphan an owned
      // backend runtime (e.g. OpenCode). Record the abnormal code (so the
      // coordinator backstop reports it too if the stop hangs), then shut down
      // gracefully before exiting.
      exitProcess: (code) {
        requestAbnormalExit(code);
        unawaited(_shutdownThenExit(shutdownCoordinator: shutdownCoordinator, code: code));
      },
    );
    lossListener.start();
    shutdownCoordinator.add(disposable: lossListener.dispose);

    await controlChannelClient.connect();
  }

  /// Graceful termination for the control-channel parent-loss policy (ADR A9):
  /// run the ordered shutdown (which stops the plugin and any owned runtime)
  /// before exiting, so a hard exit from the loss timer cannot orphan the
  /// backend process. If the stop hangs, the coordinator backstop fires — and
  /// because the loss code was recorded via `requestAbnormalExit`, the backstop
  /// reports that abnormal code, not the neutral 0, so a loss is never seen as a
  /// clean exit regardless of the backstop's (step-count-dependent) timing. The
  /// precise exit code the GUI observes is finalized in Phase 2 (PR 2.7).
  static Future<void> _shutdownThenExit({
    required BridgeShutdownCoordinator shutdownCoordinator,
    required int code,
  }) async {
    try {
      await shutdownCoordinator.shutdown();
    } catch (error, stackTrace) {
      Log.w("[control] graceful shutdown after control-channel loss failed", error, stackTrace);
    }
    io.exit(code);
  }

  /// Runs the plugin's runtime-provisioning phase, rendering progress and
  /// recording the resolved launch path on [host] for `start()` to read.
  ///
  /// A [ProvisionFailed] terminal event is non-fatal: it is rendered, the path
  /// stays unset, and `start()` proceeds in a degraded state. A cooperative
  /// abort during provisioning surfaces as [PluginStartAbortedException], which
  /// the caller already treats as "aborted as requested".
  static Future<void> _ensurePluginRuntime({
    required BridgePluginDescriptor descriptor,
    required BridgePluginHostImpl host,
  }) async {
    final formatter = RuntimeProvisionFormatter(
      interactive: io.stderr.hasTerminal,
      runtimeName: descriptor.displayName,
    );
    await for (final RuntimeProvisionProgress event in descriptor.ensureRuntime(host: host)) {
      final String? rendered = formatter.format(event);
      if (rendered != null) {
        io.stderr.write(rendered);
      }
      if (event is ProvisionReady) {
        host.provisionedRuntimePath = event.binaryPath;
      }
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
              // Ensure the plugin's backend runtime exists (download it if
              // needed), recording the resolved launch path on the host, before
              // start(). Runs under the mutex so concurrent bridge instances
              // can't install the same managed runtime at once.
              await _ensurePluginRuntime(descriptor: descriptor, host: host);
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

  static UpdateLifecycleService _buildUpdateLifecycleService({
    required http.Client httpClient,
    required ProcessRunner processRunner,
    required ManagedRuntimePaths managedRuntimePaths,
    required ReleaseTrack releaseTrack,
  }) {
    const clock = Clock();
    const messageFormatter = UpdateMessageFormatter();
    const filesystemCleaner = FilesystemCleaner();
    final installRoot = managedRuntimePaths.installRoot;

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

    final logRepository = UpdateLogRepository(
      api: UpdateLogApi(installRoot: installRoot, clock: clock),
    );
    final attemptRepository = UpdateAttemptRepository(
      api: UpdateAttemptApi(installRoot: installRoot),
    );
    final installationRepository = UpdateInstallationRepository(
      platformUpdateApi: PlatformUpdateApi.forPlatform(processRunner: processRunner),
      manifestApi: const ManagedRuntimeManifestApi(),
    );
    final updateLock = UpdateLock(currentPid: io.pid, processRunner: processRunner, clock: clock);
    final updateApplyService = UpdateApplyService(
      installationRepository: installationRepository,
      attemptRepository: attemptRepository,
      logRepository: logRepository,
      updateLock: updateLock,
      filesystemCleaner: filesystemCleaner,
      clock: clock,
      currentVersion: appVersion,
      installRoot: installRoot,
    );

    final distributionTarget = currentDistributionTarget();
    final commandExecutor = ProcessRunnerCommandExecutor(processRunner: processRunner);

    final updateService = UpdateService(
      releaseRepository: ReleaseRepository(
        api: GitHubReleasesApi(httpClient: httpClient, authToken: githubToken),
        cache: UpdateCacheApi(
          cacheDirectory: managedRuntimePaths.cacheDirectory,
          clock: clock,
        ),
        currentVersion: appVersion,
        target: distributionTarget,
        track: releaseTrack,
      ),
      updateInstallService: UpdateInstallService(
        updateArtifactRepository: UpdateArtifactRepository(
          downloadClient: BinaryDownloadClient(httpClient: httpClient),
          checksumManifestApi: ChecksumManifestApi(httpClient: httpClient),
          checksumValidator: ChecksumValidator(),
          archiveExtractor: ArchiveExtractor(commandExecutor: commandExecutor),
          archiveFormat: distributionTarget.archiveFormat,
        ),
        filesystemCleaner: filesystemCleaner,
        // The background updater uses the shared, fixed staging paths.
        workspaceLabel: null,
      ),
      updateApplyService: updateApplyService,
      logRepository: logRepository,
      messageFormatter: messageFormatter,
      installRoot: installRoot,
      executablePath: io.Platform.resolvedExecutable,
      managedExecutablePath: managedRuntimePaths.binaryPath,
      environment: io.Platform.environment,
    );

    final reconciliationService = UpdateReconciliationService(
      attemptRepository: attemptRepository,
      logRepository: logRepository,
      installationRepository: installationRepository,
      messageFormatter: messageFormatter,
      updateLock: updateLock,
      currentVersion: appVersion,
      installRoot: installRoot,
    );

    return UpdateLifecycleService(
      updateService: updateService,
      reconciliationService: reconciliationService,
    );
  }

  static ProcessUser? _resolveCurrentUser({required Map<String, String> environment}) => ProcessUser.fromRawUser(
    environment["USER"] ?? environment["USERNAME"],
  );

  /// Resolves this bridge's own [ProcessIdentity], degrading to a locally
  /// constructed fallback when the process-table inspection cannot identify it.
  ///
  /// Capturing the live identity is best-effort: it only enriches the owner
  /// session id with the OS-reported start marker.
  ///
  /// Failure handling is platform-specific on purpose:
  ///
  /// - On Windows the inspection shells out to `tasklist`, which can time out
  ///   right after login. Windows identities never carry a start marker, so a
  ///   null-marker fallback is indistinguishable from a real Windows identity
  ///   and is safe for the startup lock. We therefore tolerate inspection
  ///   failures and degrade rather than abort startup.
  /// - On POSIX, `ps` is fast and identities DO carry a start marker. A
  ///   null-marker fallback would poison the startup lock: a later bridge
  ///   inspecting the holder reads the real (non-null) marker, sees the
  ///   mismatch as stale, steals the lock, and starts concurrently. So a POSIX
  ///   inspection error must stay fatal — we never substitute a marker-less
  ///   fallback for a process the OS can actually describe.
  static Future<ProcessIdentity> _resolveCurrentBridgeIdentity({
    required ProcessRepository processRepository,
    required ProcessUser? currentUser,
    required ServerClock serverClock,
    required List<String> cliArgs,
    required bool isWindows,
  }) async {
    try {
      final inspected = await processRepository.inspectProcess(pid: io.pid);
      if (inspected != null) {
        return inspected;
      }
      Log.w("Could not find own process (pid ${io.pid}) in the process table; using fallback identity");
    } on Object catch (error) {
      if (!isWindows) {
        // A marker-less fallback would corrupt the startup lock on POSIX (see
        // method doc), so surface the failure instead of degrading.
        rethrow;
      }
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

  /// Describes this bridge machine for the auth-server confirmation page.
  ///
  /// Best-effort: [io.Platform.localHostname] is virtually always present, but
  /// we fall back to a constant so the server's required, non-empty `name` is
  /// always satisfied, and clamp to the 120-char server limit. The cosmetic OS
  /// version is omitted when it can't be derived.
  static DeviceInfo _bridgeDeviceInfo() {
    final hostname = _localHostname().trim();
    final name = hostname.isEmpty ? "Sesori Bridge" : hostname;
    return DeviceInfo(
      name: name.length > 120 ? name.substring(0, 120).trim() : name,
      osVersion: const OsVersionFormatter().format(
        operatingSystem: io.Platform.operatingSystem,
        operatingSystemVersion: io.Platform.operatingSystemVersion,
        osReleaseContents: _readLinuxOsRelease(),
      ),
      appVersion: appVersion,
    );
  }

  /// `Platform.localHostname` can throw (e.g. `SocketException` when hostname
  /// resolution fails in restricted/containerized environments). The descriptor
  /// is best-effort, so degrade to an empty name and let the caller fall back.
  static String _localHostname() {
    try {
      return io.Platform.localHostname;
    } on Object catch (error) {
      Log.w("Failed to read localHostname for the device descriptor", error);
      return "";
    }
  }

  /// Reads `/etc/os-release` (Linux only) so [OsVersionFormatter] can derive the
  /// distro label; null on other platforms or when the file can't be read.
  static String? _readLinuxOsRelease() {
    if (!io.Platform.isLinux) return null;
    try {
      return io.File("/etc/os-release").readAsStringSync();
    } on io.IOException catch (error) {
      Log.w("Failed to read /etc/os-release for the device descriptor", error);
      return null;
    }
  }
}
