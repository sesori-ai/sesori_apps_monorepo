import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/runtime/plugin_registry.dart' show knownPlugins, preferredDefaultPluginId;
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

const String _accessToken = 'supervised-e2e-access-token';
const String _bridgeId = 'supervised-e2e-bridge';
const Duration _operationTimeout = Duration(seconds: 45);

void main() {
  test(
    'supervised helper handshakes, restarts, and unregisters against local fakes',
    () async {
      final String? executable = _resolveBridgeExecutable();
      if (executable == null) {
        if (Platform.environment['SESORI_E2E_REQUIRED'] == '1') {
          throw StateError(
            'Supervised E2E helper is missing; build it with `dart build cli -o build/cli` first.',
          );
        }
        markTestSkipped(
          'Build the helper first (`dart build cli -o build/cli`) or set '
          'SESORI_DESKTOP_BRIDGE_PATH to its bundled executable.',
        );
        return;
      }

      final Directory root = await Directory.systemTemp.createTemp('sesori-supervised-e2e-');
      final Directory home = Directory(p.join(root.path, 'home'));
      final Directory data = Directory(p.join(root.path, 'data'));
      await home.create(recursive: true);
      await data.create(recursive: true);
      await _writeIsolatedBridgeConfig(home: home);
      final Map<String, String> environment = _isolatedEnvironment(home: home);

      final _FakeAuthServer auth = await _FakeAuthServer.start();
      final _FakeRelayServer relay = await _FakeRelayServer.start();
      _ControlHost? firstControl;
      _ControlHost? secondControl;
      _HelperProcess? firstHelper;
      _HelperProcess? secondHelper;
      final httpClient = HttpClient();
      try {
        firstControl = await _ControlHost.start(generation: 1);
        firstHelper = await _HelperProcess.start(
          executable: executable,
          control: firstControl,
          auth: auth,
          relay: relay,
          dataDirectory: data,
          environment: environment,
        );

        final ControlMessage firstRegisteredMessage = await firstControl.waitFor(
          predicate: (message) => message is ControlRegistered,
        );
        final String firstRegisteredId = (firstRegisteredMessage as ControlRegistered).bridgeId;
        expect(firstRegisteredId, _bridgeId);
        await auth.waitForRegistrationCount(count: 1);
        await relay.waitForAuthCount(count: 1);
        expect(auth.registrationBridgeIds, <String?>[null]);
        expect(relay.authBridgeIds, <String?>[_bridgeId]);
        expect(relay.authTokens, <String>[_accessToken]);
        expect(relay.authRoles, <String>['bridge']);
        expect(firstControl.tokenRequestCount, greaterThan(0));
        expect(File(p.join(data.path, 'bridge_id')).readAsStringSync(), _bridgeId);

        final Uri debugUrl = await firstHelper.debugUrl;
        final Uri restartUrl = debugUrl.replace(path: '/global/restart');
        final HttpClientRequest restartRequest = await httpClient.postUrl(restartUrl);
        final HttpClientResponse restartResponse = await restartRequest.close().timeout(_operationTimeout);
        final String restartBody = await restartResponse.transform(utf8.decoder).join();
        expect(restartResponse.statusCode, HttpStatus.ok);
        expect(jsonDecodeMap(restartBody)['restarting'], isTrue);

        final int firstExitCode = await firstHelper.process.exitCode.timeout(_operationTimeout);
        expect(firstExitCode, BridgeSupervisedExitCode.restart.code);
        expect(firstControl.protocolError, isNull);
        final String firstSecret = firstControl.secret;
        await firstControl.close();
        firstControl = null;

        secondControl = await _ControlHost.start(generation: 2);
        secondHelper = await _HelperProcess.start(
          executable: executable,
          control: secondControl,
          auth: auth,
          relay: relay,
          dataDirectory: data,
          environment: environment,
        );
        final ControlMessage secondRegisteredMessage = await secondControl.waitFor(
          predicate: (message) => message is ControlRegistered,
        );
        expect((secondRegisteredMessage as ControlRegistered).bridgeId, _bridgeId);
        await auth.waitForRegistrationCount(count: 2);
        await relay.waitForAuthCount(count: 2);
        expect(auth.registrationBridgeIds, <String?>[null, _bridgeId]);
        expect(secondControl.secret, isNot(firstSecret));
        expect(secondControl.tokenRequestCount, greaterThan(0));
        await secondHelper.debugUrl;

        secondControl.send(const ControlMessage.unregisterAndExit());
        await auth.waitForDeletion();
        expect(auth.deletedBridgeIds, <String>[_bridgeId]);
        final int secondExitCode = await secondHelper.process.exitCode.timeout(_operationTimeout);
        expect(secondExitCode, BridgeSupervisedExitCode.cleanStop.code);
        expect(File(p.join(data.path, 'bridge_id')).existsSync(), isFalse);
        expect(secondControl.protocolError, isNull);
        expect(auth.protocolError, isNull);
        expect(relay.protocolError, isNull);
      } catch (error, stackTrace) {
        await _writeDiagnostics(
          firstHelper: firstHelper,
          secondHelper: secondHelper,
          firstControl: firstControl,
          secondControl: secondControl,
          auth: auth,
          relay: relay,
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      } finally {
        await firstHelper?.terminate();
        await secondHelper?.terminate();
        await firstControl?.close();
        await secondControl?.close();
        await auth.close();
        await relay.close();
        httpClient.close(force: true);
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

String? _resolveBridgeExecutable() {
  final String? override = Platform.environment['SESORI_DESKTOP_BRIDGE_PATH']?.trim();
  if (override != null && override.isNotEmpty) {
    if (!File(override).existsSync()) {
      throw StateError('SESORI_DESKTOP_BRIDGE_PATH does not exist: $override');
    }
    return override;
  }

  final String executableName = Platform.isWindows ? 'bridge.exe' : 'bridge';
  final List<String> candidates = <String>[
    p.join(Directory.current.path, 'build', 'cli', 'bundle', 'bin', executableName),
    p.join(Directory.current.path, 'build', 'cli', 'bundle', 'bin', 'bridge'),
  ];
  for (final String candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }
  return null;
}

Future<void> _writeIsolatedBridgeConfig({required Directory home}) async {
  final File config = File(p.join(home.path, '.config', 'sesori', 'config.json'));
  await config.parent.create(recursive: true);
  await config.writeAsString(
    jsonEncode(<String, Object?>{
      'sleepPrevention': 'off',
      'yolo': false,
      'releaseTrack': 'stable',
      'pullRequestRefreshIntervalSeconds': 3600,
      'plugins': <String, Object?>{
        // OpenCode's attach mode is the only registered plugin path that can
        // be disabled safely only when it remains eligible; keep it enabled
        // but point it at an intentionally unused port below. Every other
        // plugin is disabled so setup inspection never probes host tools.
        'disabled': <String>[
          for (final plugin in knownPlugins)
            if (plugin.id != preferredDefaultPluginId) plugin.id,
        ],
      },
    }),
  );
}

Map<String, String> _isolatedEnvironment({required Directory home}) {
  final String localAppData = p.join(home.path, 'AppData', 'Local');
  final String xdgConfigHome = p.join(home.path, '.config');
  final String xdgDataHome = p.join(home.path, '.local', 'share');
  return <String, String>{
    ...Platform.environment,
    'HOME': home.path,
    'USERPROFILE': home.path,
    'LOCALAPPDATA': localAppData,
    'APPDATA': p.join(home.path, 'AppData', 'Roaming'),
    'XDG_CONFIG_HOME': xdgConfigHome,
    'XDG_DATA_HOME': xdgDataHome,
    'SESORI_NO_UPDATE': '1',
    'CI': '1',
  }..remove('AUTH_BACKEND_URL');
}

Future<void> _writeDiagnostics({
  required _HelperProcess? firstHelper,
  required _HelperProcess? secondHelper,
  required _ControlHost? firstControl,
  required _ControlHost? secondControl,
  required _FakeAuthServer auth,
  required _FakeRelayServer relay,
  required Object error,
  required StackTrace stackTrace,
}) async {
  final String? rawDirectory = Platform.environment['SESORI_E2E_ARTIFACT_DIR']?.trim();
  if (rawDirectory == null || rawDirectory.isEmpty) {
    return;
  }
  try {
    final Directory directory = Directory(rawDirectory);
    await directory.create(recursive: true);
    String helperOutput(_HelperProcess? helper) {
      if (helper == null) {
        return '<not started>\n';
      }
      return <String>[...helper.output, ...helper.errors].map(_redactDiagnostic).join('\n');
    }

    await File(p.join(directory.path, 'helper-1.log')).writeAsString(helperOutput(firstHelper));
    await File(p.join(directory.path, 'helper-2.log')).writeAsString(helperOutput(secondHelper));
    await File(p.join(directory.path, 'fake-servers.log')).writeAsString(
      <String>[
        'auth registrations: ${auth.registrationBridgeIds}',
        'auth deletions: ${auth.deletedBridgeIds}',
        'control-1 protocol error: ${firstControl?.protocolError}',
        'control-2 protocol error: ${secondControl?.protocolError}',
        'auth protocol error: ${auth.protocolError}',
        'relay auth count: ${relay.authBridgeIds.length}',
        'relay bridge ids: ${relay.authBridgeIds}',
        'relay roles: ${relay.authRoles}',
        'relay protocol error: ${relay.protocolError}',
      ].join('\n'),
    );
    await File(p.join(directory.path, 'failure.txt')).writeAsString('$error\n$stackTrace\n');
  } on Object catch (diagnosticError, diagnosticStackTrace) {
    // Artifact collection must never replace the original assertion failure.
    stderr.writeln('Could not write supervised E2E diagnostics: $diagnosticError\n$diagnosticStackTrace');
  }
}

String _redactDiagnostic(String value) => value.replaceAll(_accessToken, '<redacted-token>');

class _HelperProcess({
  required final Process process,
  required final Future<Uri> debugUrl,
  required final List<String> output,
  required final List<String> errors,
}) {
  late final Future<int> _exitCode;
  bool _exited = false;

  this {
    _exitCode = process.exitCode;
    unawaited(_exitCode.then((_) => _exited = true));
  }

  static Future<_HelperProcess> start({
    required String executable,
    required _ControlHost control,
    required _FakeAuthServer auth,
    required _FakeRelayServer relay,
    required Directory dataDirectory,
    required Map<String, String> environment,
  }) async {
    final Process process = await Process.start(
      executable,
      <String>[
        '--control-url',
        control.url.toString(),
        '--relay',
        relay.url.toString(),
        '--auth-backend',
        auth.url.toString(),
        '--data-dir',
        dataDirectory.path,
        '--debug-port',
        '0',
        '--log-level',
        'error',
        '--opencode-no-auto-start',
        '--opencode-port',
        '1',
      ],
      environment: environment,
      runInShell: false,
    );

    final List<String> output = <String>[];
    final List<String> errors = <String>[];
    final Completer<Uri> debugUrl = Completer<Uri>();
    void recordLine({required String line, required List<String> destination}) {
      if (destination.length < 200) {
        destination.add(line);
      }
      final RegExpMatch? match = RegExp(r'Debug server listening on http://127\.0\.0\.1:(\d+)').firstMatch(line);
      if (match != null && !debugUrl.isCompleted) {
        debugUrl.complete(Uri.parse('http://127.0.0.1:${match.group(1)}'));
      }
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => recordLine(line: line, destination: output));
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => recordLine(line: line, destination: errors));

    // The helper reads exactly one secret line before opening the supervised
    // control connection. Pipe observers are attached first so an immediate
    // startup failure is never hidden by a broken-pipe write.
    process.stdin.writeln(control.secret);
    await process.stdin.flush();

    try {
      final _HelperProcess helper = _HelperProcess(
        process: process,
        debugUrl: debugUrl.future.timeout(
          _operationTimeout,
          onTimeout: () => throw StateError(
            'Helper did not publish its debug-server port. stdout=${output.join('\n')} stderr=${errors.join('\n')}',
          ),
        ),
        output: output,
        errors: errors,
      );
      return helper;
    } on Object catch (error, stackTrace) {
      await _terminateRawProcess(process: process);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> terminate() async {
    if (!_exited) {
      final bool exited = await Future.any<bool>(<Future<bool>>[
        _exitCode.then((_) => true),
        Future<void>.delayed(Duration.zero).then((_) => false),
      ]);
      if (exited) {
        _exited = true;
        return;
      }
    }
    await _terminateRawProcess(process: process);
    try {
      await _exitCode.timeout(const Duration(seconds: 5));
    } on Object {
      // Cleanup is best-effort after the bounded kill attempt; the assertions
      // above retain the actual test failure.
    }
  }

  static Future<void> _terminateRawProcess({required Process process}) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', <String>['/PID', '${process.pid}', '/T', '/F']);
      } else {
        final bool groupKilled = Process.killPid(-process.pid, ProcessSignal.sigkill);
        if (!groupKilled) {
          process.kill(ProcessSignal.sigkill);
        }
      }
    } on Object {
      process.kill(ProcessSignal.sigkill);
    }
  }
}

class _ControlHost({
  required final String secret,
  required final int generation,
}) {
  late final HttpServer _server;
  final StreamController<ControlMessage> _messages = StreamController<ControlMessage>.broadcast(sync: true);
  final List<ControlMessage> _history = <ControlMessage>[];
  WebSocket? _socket;
  // ignore: cancel_subscriptions, cancelled in close()
  StreamSubscription<dynamic>? _socketSubscription;
  int tokenRequestCount = 0;
  Object? protocolError;

  Uri get url => Uri.parse('ws://127.0.0.1:${_server.port}');

  static Future<_ControlHost> start({required int generation}) async {
    final _ControlHost host = _ControlHost(
      secret: 'supervised-e2e-secret-$generation',
      generation: generation,
    );
    host._server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    host._server.listen(
      (request) => unawaited(host._handleRequest(request)),
      onError: (Object error, StackTrace stackTrace) {
        host.protocolError ??= error;
      },
    );
    return host;
  }

  Future<ControlMessage> waitFor({required bool Function(ControlMessage) predicate}) async {
    for (final ControlMessage message in _history) {
      if (predicate(message)) {
        return message;
      }
    }
    final Completer<ControlMessage> completer = Completer<ControlMessage>();
    late final StreamSubscription<ControlMessage> subscription;
    subscription = _messages.stream.listen((ControlMessage message) {
      if (predicate(message) && !completer.isCompleted) {
        completer.complete(message);
        unawaited(subscription.cancel());
      }
    });
    try {
      return await completer.future.timeout(_operationTimeout);
    } finally {
      await subscription.cancel();
    }
  }

  void send(ControlMessage message) {
    final WebSocket? socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('No helper socket is connected for control generation $generation');
    }
    socket.add(jsonEncode(message.toJson()));
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final String? authorization = request.headers.value(HttpHeaders.authorizationHeader);
    if (authorization != 'Bearer $secret') {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final WebSocket socket = await WebSocketTransformer.upgrade(request);
    _socket = socket;
    _socketSubscription = socket.listen(
      (dynamic data) => _handleFrame(data: data, socket: socket),
      onError: (Object error, StackTrace stackTrace) {
        _clearSocket(socket);
      },
      onDone: () => _clearSocket(socket),
      cancelOnError: false,
    );
  }

  void _handleFrame({required dynamic data, required WebSocket socket}) {
    if (data is! String && data is! List<int>) {
      return;
    }
    final String frame = data is String ? data : utf8.decode(data as List<int>, allowMalformed: true);
    final ControlMessage message;
    try {
      message = ControlMessage.fromJson(jsonDecodeMap(frame));
    } on Object catch (error) {
      protocolError ??= error;
      return;
    }
    _history.add(message);
    _messages.add(message);
    switch (message) {
      case ControlTokenRequest(:final id):
        tokenRequestCount++;
        socket.add(
          jsonEncode(
            ControlMessage.tokenResponse(id: id, accessToken: _accessToken).toJson(),
          ),
        );
      case ControlTokenResponse() ||
          ControlStatus() ||
          ControlPromptRequest() ||
          ControlPromptResponse() ||
          ControlShutdown() ||
          ControlUnregisterAndExit() ||
          ControlRegistered():
        break;
    }
  }

  void _clearSocket(WebSocket socket) {
    if (identical(_socket, socket)) {
      _socket = null;
      _socketSubscription = null;
    }
  }

  Future<void> close() async {
    final StreamSubscription<dynamic>? subscription = _socketSubscription;
    _socketSubscription = null;
    await subscription?.cancel();
    final WebSocket? socket = _socket;
    _socket = null;
    try {
      await socket?.close().timeout(const Duration(seconds: 3));
    } on Object {
      // The helper owns its socket after process exit; force-close the server
      // below even if the close handshake does not complete.
    }
    await _server.close(force: true);
    await _messages.close();
  }
}

class _FakeAuthServer() {
  late final HttpServer _server;
  final List<String?> registrationBridgeIds = <String?>[];
  final List<String> deletedBridgeIds = <String>[];
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  Object? protocolError;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeAuthServer> start() async {
    final _FakeAuthServer server = _FakeAuthServer();
    server._server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server._server.listen(
      server._handleRequest,
      onError: (Object error, StackTrace stackTrace) {
        server.protocolError ??= error;
      },
    );
    return server;
  }

  Future<void> waitForRegistrationCount({required int count}) async {
    if (registrationBridgeIds.length >= count) {
      return;
    }
    await _changes.stream.firstWhere((_) => registrationBridgeIds.length >= count).timeout(_operationTimeout);
  }

  Future<void> waitForDeletion() async {
    if (deletedBridgeIds.isNotEmpty) {
      return;
    }
    await _changes.stream.firstWhere((_) => deletedBridgeIds.isNotEmpty).timeout(_operationTimeout);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final String? authorization = request.headers.value(HttpHeaders.authorizationHeader);
      if (authorization != 'Bearer $_accessToken') {
        protocolError ??= StateError('Fake auth received an unexpected authorization header');
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/auth/bridges') {
        final RegisterBridgeRequest body = RegisterBridgeRequest.fromJson(
          jsonDecodeMap(await utf8.decoder.bind(request).join()),
        );
        registrationBridgeIds.add(body.bridgeId);
        _changes.add(null);
        await _jsonResponse(
          request.response,
          status: HttpStatus.created,
          body: BridgeSummary(
            id: _bridgeId,
            name: body.name,
            platform: body.platform,
            addedAt: DateTime.utc(2026, 8, 30),
            lastSeenAt: null,
          ).toJson(),
        );
        return;
      }
      if (request.method == 'DELETE' &&
          request.uri.pathSegments.length == 3 &&
          request.uri.pathSegments[0] == 'auth' &&
          request.uri.pathSegments[1] == 'bridges') {
        final String id = request.uri.pathSegments.last;
        deletedBridgeIds.add(id);
        _changes.add(null);
        await _jsonResponse(request.response, status: HttpStatus.ok, body: null);
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/auth/me') {
        await _jsonResponse(
          request.response,
          status: HttpStatus.ok,
          body: <String, Object?>{
            'user': const AuthUser(
              id: 'supervised-e2e-account',
              provider: AuthProvider.github,
              providerUserId: 'supervised-e2e-provider-user',
              providerUsername: 'supervised-e2e',
            ).toJson(),
          },
        );
        return;
      }
      protocolError ??= StateError('Unexpected fake-auth request: ${request.method} ${request.uri.path}');
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } on Object catch (error) {
      protocolError ??= error;
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future<void> _jsonResponse(HttpResponse response, {required int status, required Object? body}) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    if (body != null) {
      response.write(jsonEncode(body));
    }
    await response.close();
  }

  Future<void> close() async {
    await _server.close(force: true);
    await _changes.close();
  }
}

class _FakeRelayServer() {
  late final HttpServer _server;
  final List<WebSocket> _sockets = <WebSocket>[];
  final List<String?> authBridgeIds = <String?>[];
  final List<String> authTokens = <String>[];
  final List<String> authRoles = <String>[];
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);
  Object? protocolError;

  Uri get url => Uri.parse('ws://127.0.0.1:${_server.port}');

  static Future<_FakeRelayServer> start() async {
    final _FakeRelayServer server = _FakeRelayServer();
    server._server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server._server.listen(
      (request) => unawaited(server._handleRequest(request)),
      onError: (Object error, StackTrace stackTrace) {
        server.protocolError ??= error;
      },
    );
    return server;
  }

  Future<void> waitForAuthCount({required int count}) async {
    if (authBridgeIds.length >= count) {
      return;
    }
    await _changes.stream.firstWhere((_) => authBridgeIds.length >= count).timeout(_operationTimeout);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final WebSocket socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    socket.listen(
      (dynamic data) => _handleFrame(data: data),
      onError: (Object error, StackTrace stackTrace) {
        protocolError ??= error;
      },
      onDone: () => _sockets.remove(socket),
      cancelOnError: false,
    );
  }

  void _handleFrame({required dynamic data}) {
    if (data is! String && data is! List<int>) {
      return;
    }
    final String frame = data is String ? data : utf8.decode(data as List<int>, allowMalformed: true);
    final RelayMessage message;
    try {
      message = RelayMessage.fromJson(jsonDecodeMap(frame));
    } on Object catch (error) {
      protocolError ??= error;
      return;
    }
    if (message case AuthRelayMessage(:final token, :final role, :final bridgeId)) {
      authTokens.add(token);
      authRoles.add(role);
      authBridgeIds.add(bridgeId);
      _changes.add(null);
      if (token != _accessToken || role != 'bridge' || bridgeId != _bridgeId) {
        protocolError ??= StateError('Unexpected relay auth message');
      }
    }
  }

  Future<void> close() async {
    final List<WebSocket> sockets = List<WebSocket>.of(_sockets);
    _sockets.clear();
    for (final WebSocket socket in sockets) {
      try {
        await socket.close().timeout(const Duration(seconds: 3));
      } on Object {
        // Force-close the listening server below even if a peer is wedged.
      }
    }
    await _server.close(force: true);
    await _changes.close();
  }
}
