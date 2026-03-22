import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:opencode_plugin/opencode_plugin.dart';
import 'package:sesori_bridge/src/auth/login.dart';
import 'package:sesori_bridge/src/auth/profile.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/auth/validate.dart';
import 'package:sesori_bridge/src/bridge/debug_server.dart';
import 'package:sesori_bridge/src/bridge/models/bridge_config.dart';
import 'package:sesori_bridge/src/bridge/orchestrator.dart';
import 'package:sesori_bridge/src/bridge/relay_client.dart';
import 'package:sesori_bridge/src/push/push_notification_client.dart';
import 'package:sesori_bridge/src/server/process.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log, LogLevel;

const String _defaultRelayURL = 'wss://relay.sesori.com';
const String _defaultAuthURL = 'https://api.sesori.com';
const String _defaultTargetHost = 'http://127.0.0.1';
const Duration _defaultSseReplayWindow = Duration(minutes: 5);

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

  // Server resolution
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
    sseReplayWindow: _defaultSseReplayWindow,
  );
  final plugin = OpenCodePlugin(
    serverUrl: serverURL,
    password: serverPasswordPtr,
  );
  var currentAccessToken = authTokens.accessToken;
  final pushClient = PushNotificationClient(
    authBackendURL: authBackendURL,
    accessTokenProvider: () => currentAccessToken,
  );
  final orchestrator = Orchestrator(
    config: bridgeConfig,
    client: RelayClient(relayURL, currentAccessToken),
    plugin: plugin,
    pushClient: pushClient,
    onAccessTokenRefreshed: (token) => currentAccessToken = token,
  );
  final session = orchestrator.create();

  // Create and start debug server if requested
  DebugServer? debugServer;
  if (debugPort != null) {
    debugServer = DebugServer(plugin, port: debugPort);
    try {
      await debugServer.start();
    } catch (e) {
      Log.e('failed to start debug server: $e');
      await stopServer(cmd);
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
    await _shutdown(cmd, sigintSub, sigtermSub, debugServer);
    exit(1);
  }

  await _shutdown(cmd, sigintSub, sigtermSub, debugServer);
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
) async {
  final safetyTimer = Timer(const Duration(seconds: 10), () {
    Log.e('Failed to finish gracefully');
    exit(0);
  });

  await Future.wait([
    stopServer(serverProcess),
    sigintSub.cancel(),
    if (sigtermSub != null) sigtermSub.cancel(),
    if (debugServer != null) debugServer.stop(),
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
