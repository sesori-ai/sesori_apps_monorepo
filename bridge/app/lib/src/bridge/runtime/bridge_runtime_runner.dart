import "dart:io" as io;

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:path/path.dart" as path;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi, Log;

import "../../auth/login_email_api.dart";
import "../../auth/login_email_repository.dart";
import "../../auth/login_oauth_api.dart";
import "../../auth/token.dart";
import "../../auth/token_manager.dart";
import "../../server/api/loopback_port_api.dart";
import "../../server/api/open_code_process_api.dart";
import "../../server/api/runtime_file_api.dart";
import "../../server/api/system_process_api.dart";
import "../../server/api/terminal_prompt_api.dart";
import "../../server/foundation/process_identity.dart";
import "../../server/foundation/server_clock.dart";
import "../../server/repositories/bridge_instance_repository.dart";
import "../../server/repositories/open_code_ownership_record.dart";
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

typedef BridgePluginFactory = BridgePluginApi Function({required String serverUrl, required String? serverPassword});

Future<int> runBridgeApp({
  required BridgeCliOptions options,
  required BridgePluginFactory pluginFactory,
}) {
  return BridgeRuntimeRunner.run(
    options: options,
    pluginFactory: pluginFactory,
  );
}

class BridgeRuntimeRunner {
  const BridgeRuntimeRunner._();

  static Future<int> run({
    required BridgeCliOptions options,
    required BridgePluginFactory pluginFactory,
  }) async {
    final shutdownCoordinator = BridgeShutdownCoordinator();
    final subscriptions = CompositeSubscription();
    shutdownCoordinator.add(disposable: subscriptions.cancel);
    final httpClient = http.Client();
    final processRunner = ProcessRunner();
    const serverClock = ServerClock();
    final environment = io.Platform.environment;
    final currentUser = _resolveCurrentUser(environment: environment);
    final managedRuntimePaths = const ManagedRuntimePathService().currentPaths(
      environment: environment,
    );
    final runtimeFileApi = RuntimeFileApi(
      runtimeDirectory: path.join(managedRuntimePaths.cacheDirectory, "runtime"),
    );
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
    );
    final terminalPromptApi = TerminalPromptApi(
      stdin: io.stdin,
      stdout: io.stdout,
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
      loginOAuthApi: LoginOAuthApi(authBackendUrl: options.authBackendUrl),
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

      final serverRuntime = await resolveServer(
        options: options,
        currentBridgeIdentity: currentBridgeIdentity,
        ownerSessionId: ownerSessionId,
        startupMutexRepository: startupMutexRepository,
        ownershipRepository: ownershipRepository,
        bridgeInstanceService: bridgeInstanceService,
        openCodeServerService: openCodeServerService,
      );
      registerOwnedOpenCodeShutdown(
        shutdownCoordinator: shutdownCoordinator,
        serverRuntime: serverRuntime,
        stopOwnedOpenCode: (record) {
          return openCodeServerService.stopOwnedServer(record: record);
        },
      );

      final tokenManager = TokenManager(
        initialToken: authTokens.accessToken,
        authBackendUrl: options.authBackendUrl,
        loadTokens: loadTokens,
        saveTokens: saveTokens,
      );
      shutdownCoordinator.add(disposable: tokenManager.dispose);

      final runtime = BridgeRuntime.create(
        config: BridgeConfig(
          relayURL: options.relayUrl,
          serverURL: serverRuntime.serverUrl,
          serverPassword: serverRuntime.serverPassword,
          authBackendURL: options.authBackendUrl,
          sseReplayWindow: SSEManager.defaultReplayWindow,
        ),
        plugin: pluginFactory(
          serverUrl: serverRuntime.serverUrl,
          serverPassword: serverRuntime.serverPassword,
        ),
        httpClient: httpClient,
        accessTokenProvider: tokenManager,
        tokenRefresher: tokenManager,
        database: AppDatabase.create(),
        processRunner: processRunner,
        failureReporter: LogFailureReporter(),
      );
      shutdownCoordinator.add(disposable: runtime.close);

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

      await runtime.session.run();
      return 0;
    } catch (error) {
      Log.e("$error");
      return 1;
    } finally {
      await shutdownCoordinator.shutdown();
    }
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
      updateRelaunchClient: UpdateRelaunchClient(),
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

  static String? _resolveCurrentUser({required Map<String, String> environment}) {
    return environment["USER"] ?? environment["USERNAME"];
  }

  static ProcessIdentity _fallbackCurrentBridgeIdentity({
    required String? currentUser,
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
