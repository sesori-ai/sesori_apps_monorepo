import "dart:async";
import "dart:io" as io;

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:meta/meta.dart";
import "package:path/path.dart" as path;
import "package:rxdart/rxdart.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show ArchiveExtractor, BinaryDownloadClient, ChecksumValidator, DownloadProgress, OsVersionFormatter, PlatformOs;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgePlugin,
        BridgePluginDescriptor,
        Console,
        Log,
        PluginConfig,
        PluginStartAbortedException,
        PluginUnavailable,
        ProcessIdentity,
        ProcessUser,
        ProvisionReady,
        RuntimeProvisionProgress,
        ServerClock,
        StartAbortController,
        StartAbortSignal;
import "package:sesori_shared/sesori_shared.dart"
    show AuthClientType, AuthDeviceInfoBuilder, DeviceInfo, legacyMissingPluginId;

import "../../api/bridge_settings_api.dart";
import "../../api/control_secret_api.dart";
import "../../api/database/database.dart";
import "../../auth/access_token_provider.dart";
import "../../auth/bridge_id_migration_service.dart";
import "../../auth/bridge_id_storage.dart";
import "../../auth/bridge_registration_api.dart";
import "../../auth/bridge_registration_repository.dart";
import "../../auth/bridge_registration_service.dart";
import "../../auth/login_email_api.dart";
import "../../auth/login_email_repository.dart";
import "../../auth/login_oauth_api.dart";
import "../../auth/login_oauth_service.dart";
import "../../auth/token.dart";
import "../../auth/token_manager.dart";
import "../../auth/token_refresher.dart";
import "../../control/bridge_control_message_dispatcher.dart";
import "../../control/control_channel_loss_listener.dart";
import "../../control/control_provision_notifier.dart";
import "../../control/control_status_notifier.dart";
import "../../foundation/control_channel_client.dart";
import "../../listeners/catalog_import_console_listener.dart";
import "../../repositories/bridge_settings.dart";
import "../../repositories/bridge_settings_repository.dart";
import "../../server/api/loopback_port_api.dart";
import "../../server/api/process_id_lookup_api.dart";
import "../../server/api/runtime_file_api.dart";
import "../../server/api/system_process_api.dart";
import "../../server/api/terminal_prompt_api.dart";
import "../../server/foundation/bridge_replace_prompt.dart";
import "../../server/foundation/bridge_restart_command_builder.dart";
import "../../server/foundation/bridge_restart_env.dart";
import "../../server/host/bridge_host_info_impl.dart";
import "../../server/host/bridge_host_json_store.dart";
import "../../server/host/bridge_host_port_service.dart";
import "../../server/host/bridge_host_process_service.dart";
import "../../server/host/bridge_plugin_host_impl.dart";
import "../../server/host/plugin_state_directory.dart";
import "../../server/repositories/bridge_instance_repository.dart";
import "../../server/repositories/process_repository.dart";
import "../../server/repositories/startup_mutex_repository.dart";
import "../../server/repositories/terminal_prompt_repository.dart";
import "../../server/services/bridge_instance_service.dart";
import "../../server/services/bridge_restart_service.dart";
import "../../services/catalog_import_service.dart";
import "../../services/control_channel_token_service.dart";
import "../../services/control_prompt_service.dart";
import "../../services/control_unregister_service.dart";
import "../../services/plugin_lifecycle_service.dart";
import "../../updater/api/checksum_manifest_api.dart";
import "../../updater/api/github_releases_api.dart";
import "../../updater/api/managed_runtime_manifest_api.dart";
import "../../updater/api/platform_update_api.dart";
import "../../updater/api/update_attempt_api.dart";
import "../../updater/api/update_cache_api.dart";
import "../../updater/api/update_log_api.dart";
import "../../updater/formatters/update_message_formatter.dart";
import "../../updater/formatters/update_output_formatter.dart";
import "../../updater/foundation/filesystem_cleaner.dart";
import "../../updater/foundation/release_track.dart";
import "../../updater/foundation/update_lock.dart";
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
import "../debug_server.dart";
import "../foundation/process_runner.dart";
import "../foundation/process_runner_command_executor.dart";
import "../log_failure_reporter.dart";
import "../models/bridge_config.dart";
import "../orchestrator.dart";
import "../persistence/bridge_diagnostics.dart";
import "../relay_client.dart";
import "../sse/sse_manager.dart";
import "bridge_cli_options.dart";
import "bridge_runtime.dart";
import "bridge_runtime_auth.dart";
import "bridge_runtime_server_exception.dart";
import "bridge_shutdown_coordinator.dart";
import "plugin_registry.dart";
import "runtime_provision_formatter.dart";

/// The deliberate exit outcomes of a supervised bridge, each carrying the
/// process exit [code] the desktop GUI supervisor keys its respawn policy on.
/// Anything not represented here reads to the GUI as a crash (backoff respawn).
enum SupervisedExitCode {
  /// A phone-triggered restart handed off by exiting: the GUI must respawn.
  /// Distinct from a clean stop (0), a crash (other non-zero), and
  /// control-channel loss (1) so the GUI supervisor can tell an intentional
  /// restart apart and respawn rather than treat it as a crash.
  restart(86),

  /// The desktop GUI cannot supply an access token at bootstrap (signed out /
  /// mid-login / unreachable). Distinct from a crash so the GUI supervisor
  /// surfaces a login prompt instead of backoff-respawning a helper that can
  /// never start. The exit code is the authoritative signal; the best-effort
  /// `loginNeeded` prompt sent just before exiting is advisory.
  authRequired(87),

  /// Same-machine single-live contention kept this bridge from starting:
  /// another bridge is already running (or holds the startup mutex) and the
  /// replace ask ended in a decline or could not be answered (GUI declined /
  /// unreachable / prompt timeout / teardown). Distinct from a crash so the
  /// GUI supervisor can surface an "another bridge is running — take over?"
  /// state instead of backoff-respawning a helper that would just re-prompt
  /// forever. The incumbent bridge keeps running; taking over is a plain
  /// respawn whose fresh replace prompt the GUI answers with accept.
  bridgeContention(88),

  /// The GUI's `unregister_and_exit` logout command: a deliberate clean stop,
  /// so the GUI must not respawn.
  logout(0),

  /// The control channel to the GUI was lost past the grace period (ADR A9):
  /// an abnormal exit — the parent is gone, so a loss must never read as a
  /// clean stop even when the shutdown itself completes fine.
  controlChannelLost(1);

  const SupervisedExitCode(this.code);

  /// The process exit code reported to the GUI supervisor.
  final int code;
}

Future<int> runBridgeApp({
  required BridgeCliOptions options,
  required Map<String, PluginConfig> pluginConfigs,
}) {
  return BridgeRuntimeRunner.run(
    options: options,
    pluginConfigs: pluginConfigs,
  );
}

class BridgeRuntimeRunner {
  const BridgeRuntimeRunner._();

  /// Soft deadline granted to the plugin's ordered `shutdown()` step. The
  /// shutdown coordinator's backstop is sized from it (budget + slack).
  static const Duration _pluginShutdownBudget = Duration(seconds: 10);

  static Future<int> run({
    required BridgeCliOptions options,
    required Map<String, PluginConfig> pluginConfigs,
  }) async {
    final startAbortController = StartAbortController();
    final pluginLifecycleService = PluginLifecycleService();
    BridgeRuntime? runtime;
    DebugServer? debugServer;
    CatalogImportConsoleListener? catalogImportConsoleListener;
    Future<void>? sessionRun;
    Future<void>? earlyPluginDispose;
    // The single typed slot for a deliberate supervised exit (restart /
    // auth-required / contention / logout / control-channel loss). Set at the
    // moment an outcome is decided — BEFORE any shutdown runs — so both the
    // explicit return and the coordinator backstop report the same code even
    // when the stop hangs or throws (the backstop's timing varies with how
    // many ordered steps are registered, so racing it is not reliable).
    //
    // Write discipline preserves the old sentinel priority: the deliberate
    // outcomes assign unconditionally (they are phase-disjoint, and an
    // intentional exit outranks a pending control-channel loss), while the
    // loss listener assigns with `??=` so a loss never overwrites an already
    // decided intentional exit.
    SupervisedExitCode? requestedSupervisedExit;
    final shutdownCoordinator = BridgeShutdownCoordinator(
      backstopExitCode: () => requestedSupervisedExit?.code ?? 0,
      startWasAborted: () => startAbortController.isAborted,
    );
    shutdownCoordinator
      ..addPhase(
        phase: BridgeShutdownPhase.signal,
        action: startAbortController.abort,
      )
      ..addPhase(
        phase: BridgeShutdownPhase.signal,
        action: () => runtime?.catalogImportService.beginShutdown(),
      )
      ..addPhase(
        phase: BridgeShutdownPhase.signal,
        action: () => runtime?.session.beginShutdown(),
      )
      ..addPhase(
        phase: BridgeShutdownPhase.signal,
        action: () => debugServer?.beginShutdown(),
      )
      ..addPhase(
        phase: BridgeShutdownPhase.signal,
        action: () => catalogImportConsoleListener?.dispose(),
      )
      ..addPhase(
        phase: BridgeShutdownPhase.earlyPluginDispose,
        action: () {
          earlyPluginDispose = pluginLifecycleService.disposeStartedApis();
        },
        budget: _pluginShutdownBudget,
      )
      ..addPhase(
        phase: BridgeShutdownPhase.drain,
        action: () => earlyPluginDispose ?? Future<void>.value(),
      )
      ..addPhase(
        phase: BridgeShutdownPhase.drain,
        action: () => runtime?.catalogImportService.drain() ?? Future<void>.value(),
      )
      ..addPhase(
        phase: BridgeShutdownPhase.drain,
        action: () => sessionRun ?? Future<void>.value(),
      )
      ..addPhase(
        phase: BridgeShutdownPhase.drain,
        action: () => debugServer?.drain() ?? Future<void>.value(),
      )
      ..addPhase(
        phase: BridgeShutdownPhase.lifecycle,
        action: pluginLifecycleService.dispose,
        budget: _pluginShutdownBudget,
      )
      ..addPhase(
        phase: BridgeShutdownPhase.shared,
        action: () => runtime?.close(),
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
    final processIdLookupApi = ProcessIdLookupApi.forPlatform(
      isWindows: io.Platform.isWindows,
      processRunner: processRunner,
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
    shutdownCoordinator.add(disposable: httpClient.close);

    final bridgeClientType = _bridgeClientType();
    final runtimeAuthService = BridgeRuntimeAuthService(
      loginEmailRepository: LoginEmailRepository(
        emailAuthApi: LoginEmailApi(authBackendUrl: options.authBackendUrl),
        promptForCredentials: terminalPromptRepository.promptForEmailCredentials,
      ),
      loginOAuthService: LoginOAuthService(
        api: LoginOAuthApi(
          authBackendUrl: options.authBackendUrl,
          client: httpClient,
          clientType: bridgeClientType,
          device: _bridgeDeviceInfo(clientType: bridgeClientType),
        ),
        browserLauncher: openOAuthBrowser,
        browserOpenability: detectBrowserOpenability,
      ),
      environment: environment,
      loadTokens: loadTokens,
      saveTokens: saveTokens,
      clearTokens: clearTokens,
    );

    // Persisted bridge-id storage (its own file, not token.json). Constructed
    // here so the supervised registration service below can share it; the
    // legacy-id migration that populates it still runs at its normal point
    // before authentication.
    final bridgeIdStorage = BridgeIdStorage(filePath: bridgeIdPath());

    try {
      // Copy a legacy bridge id out of token.json into its own storage before
      // anything ID-dependent runs — in particular before the supervised control
      // channel + dispatcher come up, so a GUI `unregister_and_exit` that arrives
      // during early startup unregisters the migrated id instead of reading an
      // empty store and leaking the server-side registration. The first token
      // save no longer serializes bridgeId, so skipping this would erase the only
      // copy. A failure here aborts startup so the next run retries the copy with
      // the legacy source still intact.
      await BridgeIdMigrationService(
        bridgeIdStorage: bridgeIdStorage,
        readLegacyBridgeId: readLegacyBridgeId,
      ).migrate();

      // Supervised mode (desktop GUI): bring up the loopback control channel
      // before anything else so the GUI sees the helper connect promptly. Every
      // step here is gated by `--control-url`; standalone startup is unchanged.
      ControlChannelTokenService? controlChannelTokenService;
      ControlPromptService? controlPromptService;
      // Kept in scope past this block: the ControlStatusNotifier (built later,
      // once the plugin exists) shares this client.
      ControlChannelClient? controlChannelClient;
      // Kept in scope for the plugin starter: tees runtime-provisioning progress
      // onto the control channel so the GUI can render first-run progress.
      ControlProvisionNotifier? controlProvisionNotifier;
      // Built early in supervised mode so the dispatcher can route the logout
      // `unregister_and_exit` command; reused as THE registration service later.
      // Standalone builds it after the interactive auth flow yields its token
      // refresher.
      BridgeRegistrationService? supervisedRegistrationService;
      if (options.isSupervised) {
        controlChannelClient = await _connectSupervisedControlChannel(
          options: options,
          shutdownCoordinator: shutdownCoordinator,
          // `??=`: a loss must never demote an already decided intentional
          // exit (restart/auth/logout/contention) to the abnormal code.
          requestAbnormalExit: () => requestedSupervisedExit ??= SupervisedExitCode.controlChannelLost,
        );
        // The GUI is the token authority in supervised mode: the bridge pulls
        // its access token from the control channel instead of the interactive
        // terminal login. Shares the same client the loss listener observes.
        controlChannelTokenService = ControlChannelTokenService(client: controlChannelClient);
        shutdownCoordinator.add(disposable: controlChannelTokenService.dispose);
        // User prompts (replace-bridge, login-needed) go to the GUI instead of
        // a terminal the helper doesn't have.
        controlPromptService = ControlPromptService(client: controlChannelClient);
        shutdownCoordinator.add(disposable: controlPromptService.dispose);
        // The GUI's supplied token is this bridge's authority, so the control
        // token service is the refresher. Reads the persisted id only at
        // runtime (unregister/register), after the migration below, so building
        // it before that migration is safe.
        supervisedRegistrationService = _buildRegistrationService(
          httpClient: httpClient,
          authBackendUrl: options.authBackendUrl,
          tokenRefresher: controlChannelTokenService,
          bridgeIdStorage: bridgeIdStorage,
        );
        shutdownCoordinator.add(disposable: supervisedRegistrationService.dispose);
        // Handles the GUI's `unregister_and_exit` logout command: unregister the
        // bridgeId, then gracefully shut down and exit 0 (a clean stop, so the
        // GUI does not respawn us). Record the logout sentinel first so a hung
        // shutdown's backstop still reports 0 rather than a latched-failure 1.
        final controlUnregisterService = ControlUnregisterService(
          registrationService: supervisedRegistrationService,
          terminate: () {
            requestedSupervisedExit = SupervisedExitCode.logout;
            return _shutdownThenExit(
              shutdownCoordinator: shutdownCoordinator,
              code: SupervisedExitCode.logout.code,
            );
          },
        );
        // The single inbound subscriber: decodes GUI→helper frames once and
        // routes them to the owning service. Started before the bootstrap token
        // pull below so its response is never missed.
        final controlMessageDispatcher = BridgeControlMessageDispatcher(
          client: controlChannelClient,
          tokenService: controlChannelTokenService,
          promptService: controlPromptService,
          unregisterService: controlUnregisterService,
        );
        controlMessageDispatcher.start();
        shutdownCoordinator.add(disposable: controlMessageDispatcher.dispose);
        // Provision-progress tee: the runner's provisioning loop feeds each
        // event here, and the notifier maps + best-effort pushes it to the GUI.
        // It observes no stream and owns no subscription, so nothing to dispose.
        controlProvisionNotifier = ControlProvisionNotifier(client: controlChannelClient);
      }

      final BridgeReplacePrompt replacePrompt = controlPromptService ?? terminalPromptRepository;
      final bridgeInstanceService = BridgeInstanceService(
        bridgeInstanceRepository: BridgeInstanceRepository(
          processIdLookupApi: processIdLookupApi,
          processApi: systemProcessApi,
          currentUser: currentUser,
        ),
        replacePrompt: replacePrompt,
        processRepository: processRepository,
        clock: serverClock,
      );

      final runtimeOwnershipError = unsupportedPackageRuntimeMessage(
        executablePath: io.Platform.resolvedExecutable,
        managedExecutablePath: managedRuntimePaths.binaryPath,
      );
      if (runtimeOwnershipError != null) {
        Log.e(runtimeOwnershipError);
        return 1;
      }

      // Resolve settings once at the composition root. Constructing settings
      // access (BridgeSettingsApi reads HOME) or reading the config can throw;
      // a settings failure must never block the bridge from starting.
      var bridgeSettings = const BridgeSettings();
      try {
        final settingsRepository = BridgeSettingsRepository(api: BridgeSettingsApi());
        bridgeSettings = await settingsRepository.loadSettings();
      } on Object catch (error, stackTrace) {
        Log.w("Failed to resolve bridge settings; using defaults", error, stackTrace);
      }
      final releaseTrack = bridgeSettings.releaseTrack;
      if (bridgeSettings.yolo) {
        Console.warning(
          "YOLO mode enabled: permission requests will be auto-approved without being sent to clients.",
        );
      }
      // Resolve the shared policy once so startup diagnostics and update
      // lifecycle gating cannot disagree about whether this run may update.
      final bool updatesEnabledForThisInstall = !shouldSkipUpdates(
        environment: environment,
        executablePath: io.Platform.resolvedExecutable,
        managedExecutablePath: managedRuntimePaths.binaryPath,
        isSupervised: options.isSupervised,
      );
      if (releaseTrack == ReleaseTrack.internal) {
        final updateStatus = updatesEnabledForThisInstall
            ? "pre-release auto-updates enabled"
            : "auto-updates disabled for this run";
        Log.w("Release track: internal ($updateStatus)");
      } else {
        Log.d("Release track: ${releaseTrack.wireValue}");
      }

      final updateLifecycle = _buildUpdateLifecycleService(
        httpClient: httpClient,
        processRunner: processRunner,
        managedRuntimePaths: managedRuntimePaths,
        releaseTrack: releaseTrack,
        isSupervised: options.isSupervised,
      );
      // Reconcile a prior in-place update first (fast, local): confirm a
      // pending activation, surface a prior failure, sweep residue. Best-effort:
      // reconciliation is maintenance and must never block startup.
      //
      // Gate it on the same skip check the periodic update path uses: a
      // non-managed binary (npm payload, dev build, CI, or updates disabled)
      // must not touch the managed install's attempt/residue state, and a
      // supervised (GUI-bundled) bridge must never rewrite itself.
      if (updatesEnabledForThisInstall) {
        try {
          await updateLifecycle.reconcile();
        } on Object catch (error) {
          Log.w("Update reconciliation failed (non-fatal): $error");
        }
      }

      // Supervised mode short-circuits the interactive auth bootstrap: no
      // provider menu, no email/password prompt — the access token comes from
      // the GUI over the control channel. Standalone runs the unchanged
      // interactive flow. logAuthenticatedUser is identical on both paths.
      final String authAccessToken;
      final supervisedTokenService = controlChannelTokenService;
      if (supervisedTokenService != null) {
        try {
          authAccessToken = await supervisedTokenService.getAccessToken();
        } on ControlTokenUnavailableException catch (error, stackTrace) {
          // The GUI cannot supply a token (signed out / mid-login / down). Exit
          // with the auth-required sentinel so the GUI prompts for login instead
          // of backoff-respawning a helper that can never start. The prompt is
          // advisory (best-effort); the exit code is the authoritative signal.
          Log.e("Cannot start supervised — no access token from the desktop app", error, stackTrace);
          controlPromptService?.announceLoginNeeded();
          requestedSupervisedExit = SupervisedExitCode.authRequired;
          return SupervisedExitCode.authRequired.code;
        }
      } else {
        final authTokens = await runtimeAuthService.ensureAuthenticated(options: options);
        authAccessToken = authTokens.accessToken;
      }
      await runtimeAuthService.logAuthenticatedUser(
        authBackendUrl: options.authBackendUrl,
        accessToken: authAccessToken,
      );

      final currentBridgeIdentity = await _resolveCurrentBridgeIdentity(
        processRepository: processRepository,
        currentUser: currentUser,
        serverClock: serverClock,
        cliArgs: options.cliArgs,
        isWindows: io.Platform.isWindows,
      );
      final ownerSessionId = _buildOwnerSessionId(currentBridgeIdentity: currentBridgeIdentity);

      final descriptors = [
        for (final pluginId in options.enabledPluginIds)
          knownPlugins.firstWhere((descriptor) => descriptor.id == pluginId),
      ];
      pluginLifecycleService.registerSelection(
        knownPluginIds: {for (final descriptor in knownPlugins) descriptor.id},
        enabledPlugins: [
          for (var index = 0; index < descriptors.length; index++)
            (
              id: descriptors[index].id,
              displayName: descriptors[index].displayName,
              isDefault: index == 0,
            ),
        ],
      );
      final hostProcessService = BridgeHostProcessService(
        processStarter: io.Process.start,
        processRepository: processRepository,
        clock: serverClock,
        currentUser: currentUser,
        isWindows: io.Platform.isWindows,
        platform: io.Platform.operatingSystem,
      );
      final availabilityResults = await Future.wait(
        descriptors.map((descriptor) async {
          try {
            return (
              descriptor: descriptor,
              availability: await descriptor.checkAvailability(
                config: pluginConfigs[descriptor.id]!,
                processes: hostProcessService,
                environment: environment,
              ),
              error: null,
              stackTrace: null,
            );
          } on Object catch (error, stackTrace) {
            return (
              descriptor: descriptor,
              availability: null,
              error: error,
              stackTrace: stackTrace,
            );
          }
        }),
      );
      final availableDescriptors = <BridgePluginDescriptor>[];
      for (final result in availabilityResults) {
        switch (result.availability) {
          case PluginUnavailable(:final message):
            pluginLifecycleService.registerUnavailable(id: result.descriptor.id);
            Console.error(message);
          case null:
            pluginLifecycleService.registerUnavailable(id: result.descriptor.id);
            Console.error("${result.descriptor.displayName} availability check failed: ${result.error}");
          default:
            availableDescriptors.add(result.descriptor);
        }
      }
      if (availableDescriptors.isEmpty) {
        return 1;
      }
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

      final startedPlugins = <String, BridgePlugin>{};
      await startPluginsUnderStartupMutex(
        descriptors: availableDescriptors,
        pluginConfigs: pluginConfigs,
        lifecycleService: pluginLifecycleService,
        startedPlugins: startedPlugins,
        managedRuntimePaths: managedRuntimePaths,
        currentBridgeIdentity: currentBridgeIdentity,
        ownerSessionId: ownerSessionId,
        startupMutexRepository: startupMutexRepository,
        bridgeInstanceService: bridgeInstanceService,
        processRepository: processRepository,
        openCodeRuntimeFileApi: runtimeFileApi,
        serverClock: serverClock,
        environment: environment,
        currentUser: currentUser,
        startAborted: startAbortController.signal,
        provisionNotifier: controlProvisionNotifier,
      );
      if (startAbortController.isAborted) {
        Log.i("Plugin start aborted as requested.");
        return 0;
      }
      for (final pluginId in options.enabledPluginIds) {
        final plugin = startedPlugins[pluginId];
        if (plugin != null) Console.message("Target [$pluginId]: ${plugin.describe().endpoint ?? pluginId}");
      }

      // In supervised mode the GUI is the token authority: the control-channel
      // token service is the access-token provider + refresher, pulling tokens
      // from the GUI over the loopback channel. Standalone keeps the
      // TokenManager, which refreshes against the auth server with the locally
      // stored refresh token (no GUI exists to ask). The control service's
      // dispose is already registered with the shutdown coordinator above.
      final AccessTokenProvider accessTokenProvider;
      final TokenRefresher tokenRefresher;
      if (supervisedTokenService != null) {
        accessTokenProvider = supervisedTokenService;
        tokenRefresher = supervisedTokenService;
      } else {
        final tokenManager = TokenManager(
          initialToken: authAccessToken,
          authBackendUrl: options.authBackendUrl,
          loadTokens: loadTokens,
          saveTokens: saveTokens,
        );
        shutdownCoordinator.add(disposable: tokenManager.dispose);
        accessTokenProvider = tokenManager;
        tokenRefresher = tokenManager;
      }

      // Supervised mode already built this early (so the dispatcher could route
      // the logout command); reuse that instance. Standalone builds it here, now
      // that the interactive auth flow has produced its token refresher.
      final BridgeRegistrationService bridgeRegistrationService;
      if (supervisedRegistrationService != null) {
        bridgeRegistrationService = supervisedRegistrationService;
      } else {
        bridgeRegistrationService = _buildRegistrationService(
          httpClient: httpClient,
          authBackendUrl: options.authBackendUrl,
          tokenRefresher: tokenRefresher,
          bridgeIdStorage: bridgeIdStorage,
        );
        shutdownCoordinator.add(disposable: bridgeRegistrationService.dispose);
      }

      // Constructed here (not inside BridgeRuntime.create) so supervised mode
      // can observe its connectionState stream below.
      final relayClient = RelayClient(
        relayURL: options.relayUrl,
        accessTokenProvider: accessTokenProvider,
        bridgeIdProvider: bridgeRegistrationService,
      );

      // Supervised status pushes: the notifier owns every outbound
      // status-class send (status + registered) over the control channel,
      // observing the plugin's lifecycle stream, the relay's connection-state
      // stream, and registration successes. Started before the session runs so
      // the initial registration and relay connect are never missed.
      ControlStatusNotifier? controlStatusNotifier;
      if (controlChannelClient != null) {
        controlStatusNotifier = ControlStatusNotifier(
          client: controlChannelClient,
          pluginMetadata: pluginLifecycleService.metadataSnapshots,
          relayConnectionState: relayClient.connectionState,
          registrations: bridgeRegistrationService.registrations,
        );
        controlStatusNotifier.start();
        shutdownCoordinator.add(disposable: controlStatusNotifier.dispose);
      }

      final restartService = BridgeRestartService(
        processRepository: processRepository,
        commandBuilder: const BridgeRestartCommandBuilder(),
        binaryPath: managedRuntimePaths.binaryPath,
        cliArgs: options.cliArgs,
        currentPid: io.pid,
        // Supervised: the GUI owns the lifecycle and respawns us, so a restart
        // exits with the sentinel code instead of spawning a successor (which
        // would replay --control-url with no off-argv secret and fail closed).
        isSupervised: options.isSupervised,
      );

      // Run startup diagnostics before composing the runtime so the
      // filesystem-access result can be carried into the health snapshot the
      // phone reads (to proactively warn about missing macOS Full Disk Access).
      // Diagnostics are advisory: an unexpected failure must never abort
      // startup, so default to "ok" (no degraded warning) on error.
      var filesystemAccessOk = true;
      try {
        final diagnostics = BridgeDiagnostics();
        filesystemAccessOk = await diagnostics.checkFilesystemAccess();
        await diagnostics.checkGitAvailable();
      } on Object catch (error, stackTrace) {
        Log.w("Startup diagnostics failed; continuing without a degraded-access warning", error, stackTrace);
      }

      final database = AppDatabase.create();
      final failureReporter = LogFailureReporter();
      final composition = Orchestrator(
        config: BridgeConfig(
          relayURL: options.relayUrl,
          authBackendURL: options.authBackendUrl,
          sseReplayWindow: SSEManager.defaultReplayWindow,
          yolo: bridgeSettings.yolo,
        ),
        client: relayClient,
        legacyMissingPluginId: legacyMissingPluginId,
        pluginLifecycleService: pluginLifecycleService,
        database: database,
        httpClient: httpClient,
        processRunner: processRunner,
        accessTokenProvider: accessTokenProvider,
        tokenRefresher: tokenRefresher,
        bridgeRegistrationService: bridgeRegistrationService,
        failureReporter: failureReporter,
        restartService: restartService,
        filesystemAccessOk: filesystemAccessOk,
        statusNotifier: controlStatusNotifier,
      ).create();
      runtime = BridgeRuntime(
        database: database,
        failureReporter: failureReporter,
        restartService: restartService,
        composition: composition,
      );
      final activeRuntime = runtime;

      if (!options.isSupervised) {
        catalogImportConsoleListener = CatalogImportConsoleListener(
          progress: activeRuntime.catalogImportService.progress,
        );
        catalogImportConsoleListener.start();
      }
      startCatalogImports(
        service: activeRuntime.catalogImportService,
        pluginIds: [
          for (final pluginId in options.enabledPluginIds)
            if (pluginLifecycleService.compositionView.operationalPlugins.containsKey(pluginId)) pluginId,
        ],
        headlessPluginIds: options.importPluginIds,
      );

      debugServer = await startDebugServerIfRequested(
        debugPort: options.debugPort,
        runtime: activeRuntime,
        shutdownCoordinator: shutdownCoordinator,
      );
      registerSignalHandlers(session: activeRuntime.session, subscriptions: subscriptions);
      // Background: check + download + stage + apply-in-place on a 4h cadence.
      // The swap takes effect on the next launch (or a phone-triggered restart).
      shutdownCoordinator.add(disposable: updateLifecycle.dispose);
      updateLifecycle.start();

      try {
        sessionRun = activeRuntime.session.run();
        await sessionRun;
      } finally {
        // A supervised phone-triggered restart handed the session off by exiting
        // rather than spawning a successor; resolve the GUI-respawn sentinel here
        // (in a finally) so it survives even if a teardown await in run()/cancel()
        // throws — otherwise the error path below would return a crash code and
        // the GUI would back off instead of respawning. `restartService` is only
        // in scope inside this try, hence resolving into the outer-scoped local.
        // Assigned before the outer `finally`'s shutdown runs, so a hung-shutdown
        // backstop reports the same code too.
        if (restartService.supervisedRestartRequested) {
          requestedSupervisedExit = SupervisedExitCode.restart;
        }
      }
      if (requestedSupervisedExit == SupervisedExitCode.restart) {
        return SupervisedExitCode.restart.code;
      }
      return 0;
    } on PluginStartAbortedException {
      if (startAbortController.isAborted) {
        Log.i("Plugin start aborted as requested.");
        return 0;
      }
      rethrow;
    } on BridgeRuntimeServerException catch (error) {
      // Same-machine single-live contention: another bridge is running (or
      // holds the startup mutex) and this bridge did not replace it. Standalone
      // keeps today's loud abort (exit 1). Supervised exits with the dedicated
      // contention sentinel so the GUI shows "another bridge is running — take
      // over?" instead of misreading the abort as a crash and backoff-
      // respawning a helper that would just re-prompt forever.
      Log.e("$error");
      if (options.isSupervised) {
        requestedSupervisedExit = SupervisedExitCode.bridgeContention;
        return SupervisedExitCode.bridgeContention.code;
      }
      return 1;
    } catch (error, stackTrace) {
      // Honor an already-completed supervised restart handoff: a teardown error
      // after the handoff is still an intentional restart, so return the sentinel
      // (GUI respawns) rather than the crash code.
      if (requestedSupervisedExit == SupervisedExitCode.restart) {
        Log.w("Session teardown failed after a supervised restart handoff", error, stackTrace);
        return SupervisedExitCode.restart.code;
      }
      Log.e("$error");
      return 1;
    } finally {
      try {
        await shutdownCoordinator.shutdown();
      } catch (error, stackTrace) {
        // `shutdownCoordinator.shutdown()` rethrows a failed ordered/parallel
        // step (by design — a failed plugin stop must surface as a non-zero
        // exit). Thrown from this `finally`, that would override the return
        // value. For a supervised restart, auth-required, or contention exit
        // that must NOT happen: the exit must stay the sentinel so the GUI
        // respawns (86), prompts for login (87), or offers a take-over (88)
        // rather than treating it as a crash. For every other exit — including
        // logout and control-channel loss, whose graceful path exits the
        // process itself — preserve the loud-failure behaviour by rethrowing.
        switch (requestedSupervisedExit) {
          case SupervisedExitCode.restart:
          case SupervisedExitCode.authRequired:
          case SupervisedExitCode.bridgeContention:
            Log.w(
              "Shutdown error during a supervised sentinel exit; preserving the sentinel exit code",
              error,
              stackTrace,
            );
          case SupervisedExitCode.logout:
          case SupervisedExitCode.controlChannelLost:
          case null:
            rethrow;
        }
      }
    }
  }

  @visibleForTesting
  static void startCatalogImports({
    required CatalogImportService service,
    required List<String> pluginIds,
    required List<String> headlessPluginIds,
  }) {
    for (final pluginId in pluginIds) {
      service.start(pluginId: pluginId, trigger: CatalogImportTrigger.automatic);
    }
    for (final headlessPluginId in headlessPluginIds) {
      service.start(pluginId: headlessPluginId, trigger: CatalogImportTrigger.headless);
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
  /// A9), then connect the GUI's loopback control channel and return the
  /// connected client so the caller can pull the initial access token over it.
  /// Both the client and the loss listener are torn down via the shutdown
  /// coordinator. Only ever called when `--control-url` is set.
  static Future<ControlChannelClient> _connectSupervisedControlChannel({
    required BridgeCliOptions options,
    required BridgeShutdownCoordinator shutdownCoordinator,
    required void Function() requestAbnormalExit,
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
      // The composition root owns the exit-code vocabulary, so the listener's
      // code is pinned to the enum here rather than relying on the listener's
      // own default staying in sync with it.
      exitCode: SupervisedExitCode.controlChannelLost.code,
      // Don't hard-exit straight from the loss timer: that bypasses the ordered
      // plugin stop in the shutdown coordinator and could orphan an owned
      // backend runtime (e.g. OpenCode). Record the abnormal outcome (so the
      // coordinator backstop reports it too if the stop hangs), then shut down
      // gracefully before exiting.
      exitProcess: (code) {
        requestAbnormalExit();
        unawaited(_shutdownThenExit(shutdownCoordinator: shutdownCoordinator, code: code));
      },
    );
    lossListener.start();
    shutdownCoordinator.add(disposable: lossListener.dispose);

    await controlChannelClient.connect();
    return controlChannelClient;
  }

  /// Builds the bridge registration service. Extracted so supervised mode can
  /// construct it early (sharing the control token service as its refresher) to
  /// route the logout command, while standalone builds it after interactive auth
  /// yields its refresher — both from one definition.
  static BridgeRegistrationService _buildRegistrationService({
    required http.Client httpClient,
    required String authBackendUrl,
    required TokenRefresher tokenRefresher,
    required BridgeIdStorage bridgeIdStorage,
  }) {
    return BridgeRegistrationService(
      repository: BridgeRegistrationRepository(
        api: BridgeRegistrationApi(
          authBackendUrl: authBackendUrl,
          client: httpClient,
        ),
      ),
      tokenRefresher: tokenRefresher,
      bridgeIdStorage: bridgeIdStorage,
      // Safe helper (not io.Platform.localHostname directly): hostname
      // resolution can throw a SocketException in restricted/containerized
      // environments; degrade to "" (which BridgeRegistrationService clamps to
      // "sesori-bridge") instead of crashing startup.
      hostName: _localHostname(),
      platform: BridgeRegistrationService.currentPlatformName(),
    );
  }

  /// Runs the ordered shutdown (stopping the plugin and any owned runtime),
  /// then exits with [code]. Two supervised paths use it: the control-channel
  /// parent-loss policy (ADR A9) and the GUI logout `unregister_and_exit`
  /// command. Running the ordered shutdown first means a hard exit can never
  /// orphan the backend process. If the stop hangs, the coordinator backstop
  /// fires; for the loss path the abnormal code recorded via
  /// `requestAbnormalExit` is reported so a loss is never seen as a clean exit.
  /// The precise exit code the GUI observes is finalized in Phase 2 (PR 2.7).
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
  ///
  /// In supervised mode [provisionNotifier] tees each event onto the control
  /// channel so the GUI can render first-run progress; standalone passes null
  /// and only the stderr render runs (byte-identical).
  static Future<void> _ensurePluginRuntime({
    required BridgePluginDescriptor descriptor,
    required BridgePluginHostImpl host,
    required ControlProvisionNotifier? provisionNotifier,
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
      provisionNotifier?.handleProvisionProgress(event: event);
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
  static Future<void> startPluginsUnderStartupMutex({
    required List<BridgePluginDescriptor> descriptors,
    required Map<String, PluginConfig> pluginConfigs,
    required PluginLifecycleService lifecycleService,
    required Map<String, BridgePlugin> startedPlugins,
    required ManagedRuntimePaths managedRuntimePaths,
    required ProcessIdentity currentBridgeIdentity,
    required String ownerSessionId,
    required StartupMutexRepository startupMutexRepository,
    required BridgeInstanceService bridgeInstanceService,
    required ProcessRepository processRepository,
    required RuntimeFileApi openCodeRuntimeFileApi,
    required ServerClock serverClock,
    required Map<String, String> environment,
    required ProcessUser? currentUser,
    required StartAbortSignal startAborted,
    required ControlProvisionNotifier? provisionNotifier,
  }) {
    Future<void> attemptStart({required int attempt}) {
      return startupMutexRepository.withLock<void>(
        bridgePid: currentBridgeIdentity.pid,
        bridgeStartMarker: currentBridgeIdentity.startMarker,
        onLockAcquired: () async {
          Log.d("acquired startup lock");
          final resolution = await bridgeInstanceService.enforceSingleLiveBridge(
            currentPid: currentBridgeIdentity.pid,
          );
          switch (resolution.status) {
            case BridgeInstanceResolutionStatus.allowed:
              final hosts = <String, BridgePluginHostImpl>{};
              for (final descriptor in descriptors) {
                final stateDirectory = pluginStateDirectoryPath(paths: managedRuntimePaths, pluginId: descriptor.id);
                await io.Directory(stateDirectory).create(recursive: true);
                final fileApi = descriptor.id == openCodePluginId
                    ? openCodeRuntimeFileApi
                    : RuntimeFileApi(runtimeDirectory: stateDirectory);
                hosts[descriptor.id] = BridgePluginHostImpl(
                  config: pluginConfigs[descriptor.id]!,
                  stateDirectory: stateDirectory,
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
                  store: BridgeHostJsonStore(fileApi: fileApi),
                );
              }

              final settlements = <Future<void>>[];
              for (final descriptor in descriptors) {
                final host = hosts[descriptor.id]!;
                Future<BridgePlugin> startFuture;
                try {
                  await _ensurePluginRuntime(
                    descriptor: descriptor,
                    host: host,
                    provisionNotifier: provisionNotifier,
                  );
                  startFuture = Future<BridgePlugin>.sync(() => descriptor.start(host));
                } on Object catch (error, stackTrace) {
                  startFuture = Future<BridgePlugin>.error(error, stackTrace);
                }
                final observedStart = startFuture.then((plugin) {
                  startedPlugins[descriptor.id] = plugin;
                  return plugin;
                });
                settlements.add(
                  lifecycleService.registerStart(
                    id: descriptor.id,
                    startFuture: observedStart,
                    shutdownBudget: _pluginShutdownBudget,
                  ),
                );
              }
              Object? firstError;
              StackTrace? firstStackTrace;
              for (final settlement in settlements) {
                try {
                  await settlement;
                } on PluginStartAbortedException catch (error, stackTrace) {
                  if (!startAborted.isAborted) {
                    firstError ??= error;
                    firstStackTrace ??= stackTrace;
                  }
                } on Object catch (error, stackTrace) {
                  firstError ??= error;
                  firstStackTrace ??= stackTrace;
                }
              }
              if (firstError != null) {
                Error.throwWithStackTrace(firstError, firstStackTrace!);
              }
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
    required bool isSupervised,
  }) {
    const clock = Clock();
    final messageFormatter = UpdateMessageFormatter(
      outFormatter: UpdateOutputFormatter.forStream(out: io.stdout, environment: io.Platform.environment),
      errFormatter: UpdateOutputFormatter.forStream(out: io.stderr, environment: io.Platform.environment),
    );
    const filesystemCleaner = FilesystemCleaner();
    final installRoot = managedRuntimePaths.installRoot;

    // The unattended auto-updater must not hijack the terminal with a
    // spontaneous progress bar, so its download progress is forwarded to a
    // broadcast sink with no listener: events are dropped and nothing is
    // buffered. It lives for the process lifetime (an explicit close is
    // unnecessary for a broadcast controller that retains nothing).
    final progressController = StreamController<DownloadProgress>.broadcast();

    // Opportunistically authenticate GitHub release checks when a token is
    // present in the environment. Unauthenticated requests share a 60/hour
    // per-IP budget that is easily exhausted behind shared/NAT'd networks; a
    // token lifts the bridge to the authenticated 5000/hour limit. Resolve the
    // first non-empty value so a blank GITHUB_TOKEN does not shadow a valid
    // GH_TOKEN.
    final githubToken =
        [
              io.Platform.environment['GITHUB_TOKEN'],
              io.Platform.environment['GH_TOKEN'],
            ]
            .map((token) => token?.trim())
            .firstWhere(
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
          progressSink: progressController.sink,
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
      isSupervised: isSupervised,
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
  static AuthClientType _bridgeClientType() =>
      switch (PlatformOs.fromOperatingSystem(operatingSystem: io.Platform.operatingSystem)) {
        PlatformOs.macos => AuthClientType.bridgeMacos,
        PlatformOs.windows => AuthClientType.bridgeWindows,
        PlatformOs.linux => AuthClientType.bridgeLinux,
      };

  static DeviceInfo _bridgeDeviceInfo({required AuthClientType clientType}) {
    return const AuthDeviceInfoBuilder().build(
      clientType: clientType,
      detectedName: _localHostname(),
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
