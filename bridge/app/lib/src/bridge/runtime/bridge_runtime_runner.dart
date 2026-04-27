import "dart:io";

import "package:clock/clock.dart";
import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePlugin, Log;

import "../../auth/token.dart";
import "../../auth/token_manager.dart";
import "../../server/server_health_config.dart";
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

typedef BridgePluginFactory = BridgePlugin Function({required String serverUrl, required String? serverPassword});

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
    final managedRuntimePaths = const ManagedRuntimePathService().currentPaths(
      environment: Platform.environment,
    );
    shutdownCoordinator.add(disposable: httpClient.close);

    try {
      final runtimeOwnershipError = unsupportedPackageRuntimeMessage(
        executablePath: Platform.resolvedExecutable,
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

      final authTokens = await ensureAuthenticated(options: options);
      await logAuthenticatedUser(
        authBackendUrl: options.authBackendUrl,
        accessToken: authTokens.accessToken,
      );
      _optimizeOpenCodeDbIfNeeded(environment: Platform.environment);

      final serverRuntime = await resolveServer(options: options);

      final tokenManager = TokenManager(
        initialToken: authTokens.accessToken,
        authBackendUrl: options.authBackendUrl,
        loadTokens: loadTokens,
        saveTokens: saveTokens,
      );
      shutdownCoordinator.add(disposable: tokenManager.dispose);

      final serverHealthConfig = ServerHealthConfig(
        serverURL: serverRuntime.serverUrl,
        password: serverRuntime.serverPassword ?? "",
        binaryPath: options.opencodeBin,
        isManaged: !options.noAutoStart,
      );

      final runtime = await BridgeRuntime.create(
        config: BridgeConfig(
          relayURL: options.relayUrl,
          serverURL: serverRuntime.serverUrl,
          serverPassword: serverRuntime.serverPassword,
          authBackendURL: options.authBackendUrl,
          sseReplayWindow: SSEManager.defaultReplayWindow,
          version: appVersion,
          serverManaged: !options.noAutoStart,
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
        serverHealthConfig: serverHealthConfig,
        initialServerProcess: serverRuntime.process,
      );
      shutdownCoordinator.add(disposable: runtime.close);
      shutdownCoordinator.add(disposable: runtime.session.stopServerLifecycle);

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
      updateLock: UpdateLock(currentPid: pid, processRunner: processRunner),
      updateRelaunchClient: UpdateRelaunchClient(),
      installRoot: managedRuntimePaths.installRoot,
      executablePath: Platform.resolvedExecutable,
      managedExecutablePath: managedRuntimePaths.binaryPath,
      environment: Platform.environment,
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
}
