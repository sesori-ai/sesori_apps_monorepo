import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:opencode_plugin/opencode_plugin.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../auth/login.dart";
import "../../auth/profile.dart";
import "../../auth/token.dart";
import "../../auth/token_manager.dart";
import "../../auth/validate.dart";
import "../../server/process.dart";
import "../api/opencode_db_api.dart";
import "../foundation/process_runner.dart";
import "../log_failure_reporter.dart";
import "../models/bridge_config.dart";
import "../orchestrator.dart";
import "../persistence/bridge_diagnostics.dart";
import "../persistence/database.dart";
import "../repositories/opencode_db_repository.dart";
import "../services/opencode_db_maintenance_service.dart";
import "../sse/sse_manager.dart";
import "bridge_cli_options.dart";
import "bridge_runtime_builder.dart";
import "bridge_shutdown_coordinator.dart";
import "update_service_builder.dart";

const String _defaultTargetHost = "http://127.0.0.1";

Future<int> runBridgeApp({required BridgeCliOptions options}) async {
  final shutdownCoordinator = BridgeShutdownCoordinator();
  final subscriptions = CompositeSubscription();
  shutdownCoordinator.add(disposable: subscriptions.cancel);

  final httpClient = http.Client();
  shutdownCoordinator.add(disposable: httpClient.close);

  try {
    final updateService = buildUpdateService(httpClient: httpClient);

    await updateService.checkAndApplyUpdate(cliArgs: options.cliArgs);

    final authTokens = await _ensureAuthenticated(options: options);
    await _logAuthenticatedUser(
      authBackendUrl: options.authBackendUrl,
      accessToken: authTokens.accessToken,
    );
    _optimizeOpenCodeDbIfNeeded(environment: Platform.environment);

    final serverRuntime = await _resolveServer(options: options);
    shutdownCoordinator.add(
      disposable: () async => stopServer(serverRuntime.process),
    );

    final bridgeConfig = BridgeConfig(
      relayURL: options.relayUrl,
      serverURL: serverRuntime.serverUrl,
      serverPassword: serverRuntime.serverPassword,
      authBackendURL: options.authBackendUrl,
      sseReplayWindow: SSEManager.defaultReplayWindow,
    );
    final tokenManager = TokenManager(
      initialToken: authTokens.accessToken,
      authBackendUrl: options.authBackendUrl,
      loadTokens: loadTokens,
      saveTokens: saveTokens,
    );
    shutdownCoordinator.add(disposable: tokenManager.dispose);

    final runtime = BridgeRuntimeBuilder(
      config: bridgeConfig,
      plugin: OpenCodePlugin(
        serverUrl: serverRuntime.serverUrl,
        password: serverRuntime.serverPassword,
      ),
      httpClient: httpClient,
      accessTokenProvider: tokenManager,
      tokenRefresher: tokenManager,
      database: AppDatabase.create(),
      processRunner: ProcessRunner(),
      failureReporter: LogFailureReporter(),
    ).create();
    shutdownCoordinator.add(disposable: runtime.close);

    await BridgeDiagnostics().runAll();
    await _startDebugServerIfRequested(
      debugPort: options.debugPort,
      runtime: runtime,
      shutdownCoordinator: shutdownCoordinator,
    );
    _registerSignalHandlers(
      session: runtime.session,
      subscriptions: subscriptions,
    );
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

Future<void> _startDebugServerIfRequested({
  required int? debugPort,
  required BridgeRuntime runtime,
  required BridgeShutdownCoordinator shutdownCoordinator,
}) async {
  if (debugPort == null) {
    return;
  }

  final bandwidthTracker = runtime.createBandwidthTracker();
  shutdownCoordinator.add(disposable: bandwidthTracker.dispose);

  try {
    final debugServer = runtime.createDebugServer(port: debugPort);
    shutdownCoordinator.add(disposable: debugServer.stop);
    await debugServer.start();
  } catch (error) {
    Log.e("failed to start debug server: $error");
  }
}

void _registerSignalHandlers({
  required OrchestratorSession session,
  required CompositeSubscription subscriptions,
}) {
  ProcessSignal.sigint.watch().listen((_) => unawaited(session.cancel())).addTo(subscriptions);

  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => unawaited(session.cancel())).addTo(subscriptions);
  }
}

Future<_ServerRuntime> _resolveServer({required BridgeCliOptions options}) async {
  final serverUrl = "$_defaultTargetHost:${options.port}";
  if (options.noAutoStart) {
    Log.i("Using existing server at $serverUrl (auto-start disabled)");
    return _ServerRuntime(
      serverUrl: serverUrl,
      serverPassword: options.password.isNotEmpty ? options.password : null,
      process: null,
    );
  }

  final serverPassword = options.password.isEmpty ? generatePassword() : options.password;
  final process = await startServer(options.opencodeBin, options.port, serverPassword);
  try {
    await waitReady(serverUrl, serverPassword);
  } catch (error) {
    await stopServer(process);
    throw Exception("opencode server failed to start: $error");
  }

  Log.i("opencode server started on port ${options.port}");
  return _ServerRuntime(
    serverUrl: serverUrl,
    serverPassword: serverPassword,
    process: process,
  );
}

Future<TokenData> _ensureAuthenticated({required BridgeCliOptions options}) async {
  if (options.forceLogin) {
    await clearTokens();
    return _loginAndPersist(authBackendUrl: options.authBackendUrl);
  }

  try {
    final storedTokens = await loadTokens();
    final (validatedTokens, ok) = await validateToken(
      options.authBackendUrl,
      storedTokens.accessToken,
      storedTokens.refreshToken,
    );
    if (ok) {
      final tokensToSave = TokenData(
        accessToken: validatedTokens.accessToken,
        refreshToken: validatedTokens.refreshToken,
        bridgeToken: storedTokens.bridgeToken,
      );
      await saveTokens(tokensToSave);
      return tokensToSave;
    }
  } on FileSystemException catch (error) {
    if (error.osError?.errorCode != 2) {
      throw Exception("load stored tokens: $error");
    }
  } catch (error) {
    throw Exception("validate stored tokens: $error");
  }

  return _loginAndPersist(authBackendUrl: options.authBackendUrl);
}

Future<TokenData> _loginAndPersist({required String authBackendUrl}) async {
  final tokens = await login(authBackendUrl);
  await saveTokens(tokens);
  return tokens;
}

Future<void> _logAuthenticatedUser({
  required String authBackendUrl,
  required String accessToken,
}) async {
  try {
    final username = await fetchUsername(authBackendUrl, accessToken);
    Log.i("Authenticated as $username");
  } catch (error) {
    Log.w("Authenticated (unable to fetch profile username: $error)");
  }
}

void _optimizeOpenCodeDbIfNeeded({required Map<String, String> environment}) {
  final homeDir = environment["HOME"] ?? environment["USERPROFILE"];
  if (homeDir == null) {
    return;
  }

  final xdgDataHome = environment["XDG_DATA_HOME"] ?? "$homeDir/.local/share";
  final openCodeDbPath = "$xdgDataHome/opencode/opencode.db";
  final dbMaintenanceService = OpenCodeDbMaintenanceService(
    repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
  );
  dbMaintenanceService.optimizeIfNeeded(dbPath: openCodeDbPath);
}

class _ServerRuntime {
  final String serverUrl;
  final String? serverPassword;
  final Process? process;

  const _ServerRuntime({
    required this.serverUrl,
    required this.serverPassword,
    required this.process,
  });
}
