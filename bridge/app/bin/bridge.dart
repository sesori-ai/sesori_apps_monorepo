import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:opencode_plugin/opencode_plugin.dart';
import 'package:sesori_bridge/src/auth/login.dart';
import 'package:sesori_bridge/src/auth/profile.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/auth/token_manager.dart';
import 'package:sesori_bridge/src/auth/validate.dart';
import 'package:sesori_bridge/src/bridge/api/gh_cli_api.dart';
import 'package:sesori_bridge/src/bridge/api/git_cli_api.dart';
import 'package:sesori_bridge/src/bridge/api/opencode_db_api.dart';
import 'package:sesori_bridge/src/bridge/bandwidth_tracker.dart';
import 'package:sesori_bridge/src/bridge/debug_server.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/bridge/log_failure_reporter.dart';
import 'package:sesori_bridge/src/bridge/metadata_service.dart';

import 'package:sesori_bridge/src/bridge/models/bridge_config.dart';
import 'package:sesori_bridge/src/bridge/orchestrator.dart';
import 'package:sesori_bridge/src/bridge/persistence/bridge_diagnostics.dart';
import 'package:sesori_bridge/src/bridge/persistence/database.dart';
import 'package:sesori_bridge/src/bridge/relay_client.dart';
import 'package:sesori_bridge/src/bridge/repositories/branch_repository.dart';
import 'package:sesori_bridge/src/bridge/repositories/opencode_db_repository.dart';
import 'package:sesori_bridge/src/bridge/repositories/permission_repository.dart';
import 'package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart';
import 'package:sesori_bridge/src/bridge/repositories/project_repository.dart';
import 'package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart';
import 'package:sesori_bridge/src/bridge/repositories/session_repository.dart';
import 'package:sesori_bridge/src/bridge/services/opencode_db_maintenance_service.dart';
import 'package:sesori_bridge/src/bridge/services/pr_sync_service.dart';
import 'package:sesori_bridge/src/bridge/services/session_persistence_service.dart';
import 'package:sesori_bridge/src/bridge/sse/sse_manager.dart';
import 'package:sesori_bridge/src/bridge/worktree_service.dart';
import 'package:sesori_bridge/src/push/completion_notifier.dart';
import 'package:sesori_bridge/src/push/push_notification_client.dart';
import 'package:sesori_bridge/src/push/push_notification_service.dart';
import 'package:sesori_bridge/src/push/push_rate_limiter.dart';
import 'package:sesori_bridge/src/push/push_session_state_tracker.dart';
import 'package:sesori_bridge/src/server/process.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log, LogLevel;

const String _defaultRelayURL = 'wss://relay.sesori.com';
const String _defaultAuthURL = 'https://api.sesori.com';
const String _defaultTargetHost = 'http://127.0.0.1';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('relay', defaultsTo: _defaultRelayURL, help: 'Relay server URL')
    ..addOption(
      'port',
      defaultsTo: '4096',
      help: 'Port for opencode server to listen on',
    )
    ..addFlag(
      'no-auto-start',
      defaultsTo: false,
      help: 'Skip auto-starting opencode server (use existing localhost server)',
    )
    ..addOption(
      'password',
      defaultsTo: '',
      help: 'Override server password (auto-generated if not set)',
    )
    ..addOption(
      'opencode-bin',
      defaultsTo: 'opencode',
      help: 'Path to opencode binary',
    )
    ..addOption('auth-backend', defaultsTo: '', help: 'Auth backend URL')
    ..addFlag(
      'login',
      defaultsTo: false,
      help: 'Force re-login and clear stored tokens',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    )
    ..addOption(
      'debug-port',
      defaultsTo: '',
      help: 'Start a debug HTTP server on this port (for Postman/curl testing)',
    )
    ..addOption(
      'log-level',
      defaultsTo: 'info',
      allowed: ['verbose', 'debug', 'info', 'warning', 'error'],
      help: 'Minimum log level',
    );

  ArgResults results;
  try {
    results = parser.parse(args);
  } on ArgParserException catch (e) {
    Log.e('Error: ${e.message}');
    Log.e(parser.usage);
    exit(1);
  }

  if (results['help'] as bool) {
    // ignore: avoid_print
    print(parser.usage);
    exit(0);
  }

  // Configure log level before anything else
  Log.level = LogLevel.values.byName(results['log-level'] as String);

  // Parse all flags
  final relayURL = results['relay'] as String;
  final port = int.parse(results['port'] as String);
  final noAutoStart = results['no-auto-start'] as bool;
  final password = results['password'] as String;
  final opencodeBin = results['opencode-bin'] as String;
  final authBackendFlag = results['auth-backend'] as String;
  final forceLogin = results['login'] as bool;
  final debugPortStr = results['debug-port'] as String;
  final debugPort = debugPortStr.isNotEmpty ? int.tryParse(debugPortStr) : null;

  // Auth backend resolution: flag > env > default
  var authBackendURL = authBackendFlag;
  if (authBackendURL.isEmpty) {
    authBackendURL = Platform.environment['AUTH_BACKEND_URL'] ?? '';
  }
  if (authBackendURL.isEmpty) {
    authBackendURL = _defaultAuthURL;
  }

  // Auth flow
  TokenData authTokens;
  try {
    authTokens = await ensureAuthenticated(forceLogin, authBackendURL);
  } catch (e) {
    Log.e('authentication failed: $e');
    exit(1);
  }

  // Fetch username
  try {
    final username = await fetchUsername(
      authBackendURL,
      authTokens.accessToken,
    );
    Log.i('Authenticated as $username');
  } catch (e) {
    Log.w('Authenticated (unable to fetch profile username: $e)');
  }

  // OpenCode DB maintenance (opportunistic — runs before server start to
  // maximize the chance that OpenCode hasn't opened the DB yet)
  final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (homeDir != null) {
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'] ?? '$homeDir/.local/share';
    final openCodeDbPath = '$xdgDataHome/opencode/opencode.db';
    final dbMaintenanceService = OpenCodeDbMaintenanceService(
      repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
    );
    dbMaintenanceService.optimizeIfNeeded(dbPath: openCodeDbPath);
  }

  // Server resolution (may auto-start OpenCode process)
  final (serverURL, serverPassword, cmd) = await resolveServer(
    noAutoStart: noAutoStart,
    port: port,
    password: password,
    opencodeBin: opencodeBin,
  );

  // Convert empty password string to null for BridgeConfig / proxies
  final String? serverPasswordPtr = serverPassword.isNotEmpty ? serverPassword : null;

  // Create bridge
  final bridgeConfig = BridgeConfig(
    relayURL: relayURL,
    serverURL: serverURL,
    serverPassword: serverPasswordPtr,
    authBackendURL: authBackendURL,
    sseReplayWindow: SSEManager.defaultReplayWindow,
  );
  final plugin = OpenCodePlugin(
    serverUrl: serverURL,
    password: serverPasswordPtr,
  );
  final tokenManager = TokenManager(
    initialToken: authTokens.accessToken,
    authBackendUrl: authBackendURL,
    loadTokens: loadTokens,
    saveTokens: saveTokens,
  );
  final pushClient = PushNotificationClient(
    authBackendURL: authBackendURL,
    tokenRefreshManager: tokenManager,
  );
  final pushRateLimiter = PushRateLimiter();
  final pushSessionStateTracker = PushSessionStateTracker();
  final completionNotifier = CompletionNotifier(
    tracker: pushSessionStateTracker,
    debounceDuration: const Duration(milliseconds: 500),
  );
  final pushNotificationService = PushNotificationService(
    client: pushClient,
    rateLimiter: pushRateLimiter,
    tracker: pushSessionStateTracker,
    completionNotifier: completionNotifier,
  );

  final relayClient = RelayClient(relayURL: relayURL, accessTokenProvider: tokenManager);

  final db = AppDatabase.create();
  final processRunner = ProcessRunner();

  // Run startup diagnostics (non-blocking — logs warnings only)
  await BridgeDiagnostics().runAll();

  final failureReporter = LogFailureReporter();

  final httpClient = http.Client();
  final metadataService = MetadataService(
    client: httpClient,
    baseUrl: authBackendURL,
    tokenRefresher: tokenManager,
  );

  final pullRequestRepository = PullRequestRepository(
    pullRequestDao: db.pullRequestDao,
    projectsDao: db.projectsDao,
  );
  final sessionRepository = SessionRepository(
    plugin: plugin,
    sessionDao: db.sessionDao,
    pullRequestRepository: pullRequestRepository,
  );
  final prSyncService = PrSyncService(
    prSource: PrSourceRepository(
      ghCli: GhCliApi(processRunner: processRunner),
      gitCli: GitCliApi(processRunner: processRunner),
    ),
    pullRequestRepository: pullRequestRepository,
    sessionRepository: sessionRepository,
  );
  final projectRepository = ProjectRepository(
    plugin: plugin,
    projectsDao: db.projectsDao,
  );
  final gitCliApi = GitCliApi(processRunner: processRunner);
  final branchRepository = BranchRepository(gitCliApi: gitCliApi);
  final permissionRepository = PermissionRepository(plugin: plugin);
  final sessionPersistenceService = SessionPersistenceService(
    projectsDao: db.projectsDao,
    sessionDao: db.sessionDao,
    db: db,
  );

  final worktreeService = WorktreeService(
    branchRepository: branchRepository,
    projectsDao: db.projectsDao,
    sessionDao: db.sessionDao,
    processRunner: processRunner,
    gitPathExists: ({required String gitPath}) => FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound,
  );

  final orchestrator = Orchestrator(
    config: bridgeConfig,
    client: relayClient,
    plugin: plugin,
    metadataService: metadataService,
    pushNotificationService: pushNotificationService,
    tokenRefresher: tokenManager,
    projectsDao: db.projectsDao,
    failureReporter: failureReporter,
    prSyncService: prSyncService,
    sessionRepository: sessionRepository,
    projectRepository: projectRepository,
    permissionRepository: permissionRepository,
    sessionPersistenceService: sessionPersistenceService,
    worktreeService: worktreeService,
  );
  final session = orchestrator.create();

  // Wire up bandwidth tracking when debug server is active
  final bandwidthTracker = debugPort != null ? BandwidthTracker(bytesSent: session.bytesSent) : null;

  // Create and start debug server if requested
  DebugServer? debugServer;
  if (debugPort != null) {
    debugServer = DebugServer(
      plugin: plugin,
      router: session.router,
      port: debugPort,
      failureReporter: failureReporter,
    );
    try {
      await debugServer.start();
    } catch (e) {
      Log.e('failed to start debug server: $e');
      await stopServer(cmd);
      await db.close();
      exit(1);
    }
  }

  // Signal handling — cancel bridge on SIGINT (all platforms) and SIGTERM (Unix)
  final sigintSub = ProcessSignal.sigint.watch().listen((_) {
    unawaited(session.cancel());
  });
  StreamSubscription<ProcessSignal>? sigtermSub;
  if (!Platform.isWindows) {
    sigtermSub = ProcessSignal.sigterm.watch().listen((_) {
      unawaited(session.cancel());
    });
  }

  // Run bridge; stop the server process on exit regardless of outcome
  try {
    await session.run();
  } catch (e) {
    Log.e('$e');
    await _shutdown(cmd, sigintSub, sigtermSub, debugServer, db, bandwidthTracker, httpClient);
    exit(1);
  }

  await _shutdown(cmd, sigintSub, sigtermSub, debugServer, db, bandwidthTracker, httpClient);
}

/// Performs graceful shutdown: stops the server and cancels signal listeners.
///
/// A 10-second safety timer guarantees the process exits even if some async
/// operation (e.g. a WebSocket close handshake) never completes.
Future<void> _shutdown(
  Process? serverProcess,
  StreamSubscription<ProcessSignal> sigintSub,
  StreamSubscription<ProcessSignal>? sigtermSub,
  DebugServer? debugServer,
  AppDatabase db,
  BandwidthTracker? bandwidthTracker,
  http.Client httpClient,
) async {
  final safetyTimer = Timer(const Duration(seconds: 10), () {
    Log.e('Failed to finish gracefully');
    exit(0);
  });

  bandwidthTracker?.dispose();
  httpClient.close();

  await Future.wait([
    stopServer(serverProcess),
    sigintSub.cancel(),
    if (sigtermSub != null) sigtermSub.cancel(),
    if (debugServer != null) debugServer.stop(),
    db.close(),
  ]);

  safetyTimer.cancel();
}

/// Resolves the server URL and starts the server process if necessary.
///
/// The server always runs on localhost — only the port is configurable.
/// Returns `(serverURL, serverPassword, process)` where [process] is `null`
/// when using a pre-existing server.
Future<(String, String, Process?)> resolveServer({
  required bool noAutoStart,
  required int port,
  required String password,
  required String opencodeBin,
}) async {
  final serverURL = '$_defaultTargetHost:$port';

  if (noAutoStart) {
    Log.i('Using existing server at $serverURL (auto-start disabled)');
    return (serverURL, password, null);
  }

  var serverPassword = password;
  if (serverPassword.isEmpty) {
    serverPassword = generatePassword();
  }

  Process cmd;
  try {
    cmd = await startServer(opencodeBin, port, serverPassword);
  } catch (e) {
    Log.e('failed to start opencode server: $e');
    exit(1);
  }

  try {
    await waitReady(serverURL, serverPassword);
  } catch (e) {
    await stopServer(cmd);
    Log.e('opencode server failed to start: $e');
    exit(1);
  }

  Log.i('opencode server started on port $port');
  return (serverURL, serverPassword, cmd);
}

/// Ensures the user is authenticated, running the login flow if necessary.
///
/// Ported from Go's `ensureAuthenticated`:
/// 1. `--login` → clear tokens → login → save → return
/// 2. Try load tokens → if file not found → login → save → return
/// 3. Validate tokens → if valid, preserve bridgeToken, save, return
/// 4. Otherwise → login → save → return
Future<TokenData> ensureAuthenticated(
  bool forceLogin,
  String authBackendURL,
) async {
  if (forceLogin) {
    try {
      await clearTokens();
    } catch (e) {
      throw Exception('clear stored tokens: $e');
    }
    return _loginAndPersist(authBackendURL);
  }

  TokenData storedTokens;
  try {
    storedTokens = await loadTokens();
  } on FileSystemException catch (e) {
    // File not found (ENOENT = 2) means first run or tokens were cleared
    if (e.osError?.errorCode == 2) {
      return _loginAndPersist(authBackendURL);
    }
    throw Exception('load stored tokens: $e');
  }

  late (TokenData, bool) validated;
  try {
    validated = await validateToken(
      authBackendURL,
      storedTokens.accessToken,
      storedTokens.refreshToken,
    );
  } catch (e) {
    throw Exception('validate stored tokens: $e');
  }

  final (validatedTokens, ok) = validated;
  if (ok) {
    // Preserve the bridgeToken from the stored tokens
    final tokensToSave = TokenData(
      accessToken: validatedTokens.accessToken,
      refreshToken: validatedTokens.refreshToken,
      bridgeToken: storedTokens.bridgeToken,
    );
    try {
      await saveTokens(tokensToSave);
    } catch (e) {
      throw Exception('persist validated tokens: $e');
    }
    return tokensToSave;
  }

  return _loginAndPersist(authBackendURL);
}

/// Runs the browser-based login flow and persists the resulting tokens.
Future<TokenData> _loginAndPersist(String authBackendURL) async {
  final tokens = await login(authBackendURL);
  try {
    await saveTokens(tokens);
  } catch (e) {
    throw Exception('save tokens: $e');
  }
  return tokens;
}
