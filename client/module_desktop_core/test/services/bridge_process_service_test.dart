import "dart:async";
import "dart:convert";
import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeProcessService", () {
    late _ProcessStreamsFixture streams;
    late _FakeBridgeProcessRepository repository;
    late _FakeBridgeProcessLogTracker logTracker;
    late _FakeControlChannelServer controlServer;
    late _FakeAuthSession authSession;
    late _FakeBridgeExecutablePathResolver executablePathResolver;
    late List<String> warnings;
    late BridgeProcessService service;

    setUp(() {
      streams = _ProcessStreamsFixture(pid: 42);
      repository = _FakeBridgeProcessRepository(streams: streams.value);
      logTracker = _FakeBridgeProcessLogTracker();
      controlServer = _FakeControlChannelServer();
      authSession = _FakeAuthSession(initialState: const AuthState.unauthenticated());
      executablePathResolver = _FakeBridgeExecutablePathResolver(path: "/repo/bridge");
      warnings = <String>[];
      service = BridgeProcessService.forTesting(
        repository: repository,
        logTracker: logTracker,
        controlChannelServer: controlServer,
        authSession: authSession,
        executablePathResolver: executablePathResolver,
        reportWarning: ({required String message, required Object error, required StackTrace stackTrace}) {
          warnings.add(message);
        },
      );
    });

    tearDown(() async {
      repository.stopError = null;
      controlServer.stopError = null;
      await service.dispose();
      await repository.disposeFake();
    });

    test("signed-out start enters login-required without starting infrastructure", () async {
      await service.start();

      expect(service.state, isA<BridgeProcessLoginRequired>());
      expect(controlServer.startCalls, 0);
      expect(repository.spawnCalls, 0);
    });

    test("authenticated start creates the channel, spawns, attaches, and sends the secret off argv", () async {
      authSession.state = _authenticatedState;

      await service.start();

      expect(controlServer.startCalls, 1);
      expect(repository.spawnCalls, 1);
      expect(repository.executable, "/repo/bridge");
      expect(repository.arguments, ["--control-url", "ws://127.0.0.1:41001"]);
      expect(repository.arguments, isNot(contains("spawn-secret-1")));
      expect(logTracker.attachedStdout, same(streams.stdout));
      expect(logTracker.attachedStderr, same(streams.stderr));
      verify(() => streams.stdin.writeln("spawn-secret-1")).called(1);
      verify(() => streams.stdin.flush()).called(1);
      expect(
        service.state,
        isA<BridgeProcessRunning>().having((state) => state.pid, "pid", 42),
      );
    });

    test("clean stop delegates to the repository and tears down the channel", () async {
      authSession.state = _authenticatedState;
      await service.start();

      await service.stop();

      expect(repository.stopCalls, 1);
      expect(controlServer.stopCalls, 1);
      expect(service.state, isA<BridgeProcessStopped>());
    });

    test("an observed child exit tears down the per-spawn channel", () async {
      authSession.state = _authenticatedState;
      await service.start();

      repository.emitExit(exitCode: 7, expected: false);
      await pumpEventQueue();

      expect(controlServer.stopCalls, 1);
      expect(service.state, isA<BridgeProcessStopped>());
    });

    test("control bind failure is cleaned up and permits retry", () async {
      authSession.state = _authenticatedState;
      final StateError bindError = StateError("port bind failed");
      controlServer.startError = bindError;

      await expectLater(service.start(), throwsA(same(bindError)));

      expect(controlServer.stopCalls, 1);
      expect(repository.spawnCalls, 0);
      expect(service.state, isA<BridgeProcessStopped>());

      controlServer.startError = null;
      await service.start();
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("spawn failure rolls back the channel, surfaces the original error, and permits retry", () async {
      authSession.state = _authenticatedState;
      final StateError spawnError = StateError("missing helper");
      repository.spawnError = spawnError;

      await expectLater(service.start(), throwsA(same(spawnError)));

      expect(repository.stopCalls, 0);
      expect(controlServer.stopCalls, 1);
      expect(service.state, isA<BridgeProcessStopped>());

      repository.spawnError = null;
      await service.start();

      expect(controlServer.startCalls, 2);
      expect(repository.spawnCalls, 2);
      verify(() => streams.stdin.writeln("spawn-secret-2")).called(1);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("attach failure expected-stops the child and permits a clean retry", () async {
      authSession.state = _authenticatedState;
      final StateError attachError = StateError("pipe attach failed");
      logTracker.attachError = attachError;

      await expectLater(service.start(), throwsA(same(attachError)));

      expect(repository.stopCalls, 1);
      expect(controlServer.stopCalls, 1);
      expect(service.state, isA<BridgeProcessStopped>());

      logTracker.attachError = null;
      await service.start();

      expect(repository.spawnCalls, 2);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("exit during startup is surfaced and rolled back", () async {
      authSession.state = _authenticatedState;
      logTracker.onAttach = () {
        repository.emitExit(exitCode: 1, expected: false);
      };

      await expectLater(
        service.start(),
        throwsA(
          isA<BridgeProcessExitedDuringStartException>().having(
            (error) => error.pid,
            "pid",
            42,
          ),
        ),
      );

      expect(controlServer.stopCalls, greaterThanOrEqualTo(1));
      expect(service.state, isA<BridgeProcessStopped>());
    });

    test("cleanup failures never replace the original startup error", () async {
      authSession.state = _authenticatedState;
      final StateError attachError = StateError("pipe attach failed");
      logTracker.attachError = attachError;
      repository.stopError = StateError("kill failed");
      controlServer.stopError = StateError("server stop failed");

      await expectLater(service.start(), throwsA(same(attachError)));

      expect(warnings, hasLength(2));
      expect(service.state, isA<BridgeProcessStopping>());
    });
  });

  test("dispatcher started before spawn completes a real authenticated token handshake", () async {
    final _ProcessStreamsFixture streams = _ProcessStreamsFixture(pid: 91);
    final _FakeBridgeProcessRepository repository = _FakeBridgeProcessRepository(streams: streams.value);
    final _FakeBridgeProcessLogTracker logTracker = _FakeBridgeProcessLogTracker();
    final ControlChannelServer server = ControlChannelServer();
    final BridgeStatusTracker statusTracker = BridgeStatusTracker();
    final BridgePromptTracker promptTracker = BridgePromptTracker();
    final ControlMessageDispatcher dispatcher = ControlMessageDispatcher(
      server: server,
      tokenProvider: _FakeAuthTokenProvider(),
      statusTracker: statusTracker,
      promptTracker: promptTracker,
    );
    final BridgeProcessService service = BridgeProcessService.forTesting(
      repository: repository,
      logTracker: logTracker,
      controlChannelServer: server,
      authSession: _FakeAuthSession(initialState: _authenticatedState),
      executablePathResolver: _FakeBridgeExecutablePathResolver(path: "/repo/bridge"),
      reportWarning: ({required String message, required Object error, required StackTrace stackTrace}) {},
    );
    WebSocket? socket;
    addTearDown(() async {
      await socket?.close();
      await service.dispose();
      await dispatcher.dispose();
      await server.dispose();
      statusTracker.dispose();
      promptTracker.dispose();
      await repository.disposeFake();
    });

    dispatcher.start();
    await service.start();
    socket = await WebSocket.connect(
      server.url.toString(),
      headers: {HttpHeaders.authorizationHeader: "Bearer ${server.secret}"},
    );
    final Future<Object?> response = socket.first;

    socket.add(
      jsonEncode(
        const ControlMessage.tokenRequest(id: "bootstrap-token").toJson(),
      ),
    );

    final Object? encodedResponse = await response;
    expect(encodedResponse, isA<String>());
    final ControlMessage message = ControlMessage.fromJson(
      jsonDecodeMap(encodedResponse! as String),
    );
    expect(
      message,
      const ControlMessage.tokenResponse(id: "bootstrap-token", accessToken: "fresh-token"),
    );
    expect(statusTracker.status.helperOnline, isTrue);
  });
}

const AuthState _authenticatedState = AuthState.authenticated(
  user: AuthUser(
    id: "user-1",
    provider: AuthProvider.github,
    providerUserId: "provider-user-1",
    providerUsername: "octocat",
  ),
);

class _ProcessStreamsFixture({required int pid}) {
  final _MockIOSink stdin = _MockIOSink();
  final Stream<List<int>> stdout = const Stream<List<int>>.empty();
  final Stream<List<int>> stderr = const Stream<List<int>>.empty();
  late final BridgeProcessStreams value;

  this {
    when(stdin.flush).thenAnswer((invocation) {
      expect(invocation.memberName, #flush);
      return Future<void>.value();
    });
    value = BridgeProcessStreams(
      pid: pid,
      stdin: stdin,
      stdout: stdout,
      stderr: stderr,
    );
  }
}

class _MockIOSink() extends Mock implements IOSink;

class _FakeBridgeProcessRepository({required final BridgeProcessStreams streams}) implements BridgeProcessRepository {
  final StreamController<BridgeProcessExit> _exits = StreamController<BridgeProcessExit>.broadcast(sync: true);
  int spawnCalls = 0;
  int stopCalls = 0;
  String? executable;
  List<String>? arguments;
  Object? spawnError;
  Object? stopError;
  bool _isRunning = false;
  int? _activePid;

  @override
  Stream<BridgeProcessExit> get exits => _exits.stream;

  @override
  bool get isRunning => _isRunning;

  @override
  int? get activePid => _activePid;

  @override
  Future<BridgeProcessStreams> spawn({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
  }) async {
    spawnCalls++;
    this.executable = executable;
    this.arguments = List<String>.of(arguments, growable: false);
    final Object? failure = spawnError;
    if (failure != null) {
      throw failure;
    }
    _isRunning = true;
    _activePid = streams.pid;
    return streams;
  }

  @override
  Future<void> stopExpected() async {
    stopCalls++;
    final Object? failure = stopError;
    if (failure != null) {
      throw failure;
    }
    _isRunning = false;
    _activePid = null;
  }

  void emitExit({required int exitCode, required bool expected}) {
    final int? pid = _activePid;
    if (pid == null) {
      return;
    }
    _isRunning = false;
    _activePid = null;
    _exits.add(BridgeProcessExit(pid: pid, exitCode: exitCode, expected: expected));
  }

  Future<void> disposeFake() => _exits.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBridgeProcessLogTracker() implements BridgeProcessLogTracker {
  int attachCalls = 0;
  Stream<List<int>>? attachedStdout;
  Stream<List<int>>? attachedStderr;
  Object? attachError;
  void Function()? onAttach;

  @override
  Future<void> attach({required Stream<List<int>> stdout, required Stream<List<int>> stderr}) async {
    attachCalls++;
    attachedStdout = stdout;
    attachedStderr = stderr;
    onAttach?.call();
    final Object? failure = attachError;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeControlChannelServer() implements ControlChannelServer {
  int startCalls = 0;
  int stopCalls = 0;
  bool isRunning = false;
  Object? startError;
  Object? stopError;

  @override
  Uri get url => Uri.parse("ws://127.0.0.1:${41000 + startCalls}");

  @override
  String get secret => "spawn-secret-$startCalls";

  @override
  Future<void> start() async {
    startCalls++;
    final Object? failure = startError;
    if (failure != null) {
      throw failure;
    }
    isRunning = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    isRunning = false;
    final Object? failure = stopError;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthSession({required AuthState initialState}) implements AuthSession {
  AuthState state = initialState;

  @override
  AuthState get currentState => state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBridgeExecutablePathResolver({required final String path}) implements BridgeExecutablePathResolver {
  @override
  String resolve() => path;
}

class _FakeAuthTokenProvider() implements AuthTokenProvider {
  @override
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async => "fresh-token";
}
