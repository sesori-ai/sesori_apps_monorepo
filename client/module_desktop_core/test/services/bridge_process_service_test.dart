import "dart:async";
import "dart:convert";
import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeProcessService", () {
    late _ProcessStreamsFixture streams;
    late _FakeBridgeProcessRepository repository;
    late _FakeBridgeProcessLogTracker logTracker;
    late BridgeStatusTracker statusTracker;
    late _FakeControlChannelServer controlServer;
    late _FakeAuthSession authSession;
    late _FakeBridgeExecutablePathResolver executablePathResolver;
    late DateTime now;
    late List<String> warnings;
    late BridgeProcessService service;

    setUp(() {
      streams = _ProcessStreamsFixture(pid: 42);
      repository = _FakeBridgeProcessRepository(streams: streams.value);
      logTracker = _FakeBridgeProcessLogTracker();
      statusTracker = BridgeStatusTracker();
      controlServer = _FakeControlChannelServer();
      authSession = _FakeAuthSession(initialState: const AuthState.unauthenticated());
      executablePathResolver = _FakeBridgeExecutablePathResolver(path: "/repo/bridge");
      now = DateTime.utc(2026, 8, 28);
      warnings = <String>[];
      service = BridgeProcessService.forTesting(
        repository: repository,
        logTracker: logTracker,
        statusTracker: statusTracker,
        controlChannelServer: controlServer,
        authSession: authSession,
        executablePathResolver: executablePathResolver,
        crashBackoffDelays: const <Duration>[Duration(hours: 1)],
        stableRuntime: const Duration(minutes: 5),
        recentLogCount: 20,
        now: () => now,
        reportWarning: ({required String message, required Object error, required StackTrace stackTrace}) {
          warnings.add(message);
        },
      );
    });

    Future<void> rebuildService({
      required List<Duration> crashBackoffDelays,
      required Duration stableRuntime,
      required int recentLogCount,
    }) async {
      await service.dispose();
      repository.stopCalls = 0;
      controlServer.stopCalls = 0;
      service = BridgeProcessService.forTesting(
        repository: repository,
        logTracker: logTracker,
        statusTracker: statusTracker,
        controlChannelServer: controlServer,
        authSession: authSession,
        executablePathResolver: executablePathResolver,
        crashBackoffDelays: crashBackoffDelays,
        stableRuntime: stableRuntime,
        recentLogCount: recentLogCount,
        now: () => now,
        reportWarning: ({required String message, required Object error, required StackTrace stackTrace}) {
          warnings.add(message);
        },
      );
    }

    tearDown(() async {
      repository.stopError = null;
      controlServer.stopError = null;
      await service.dispose();
      await repository.disposeFake();
      await authSession.disposeFake();
      statusTracker.dispose();
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

    test("control-channel loss tears down the channel and schedules a bounded retry", () async {
      authSession.state = _authenticatedState;
      await service.start();

      repository.emitExit(exitCode: 1, expected: false);
      await pumpEventQueue();

      expect(controlServer.stopCalls, 1);
      expect(
        service.state,
        isA<BridgeProcessCrashRetryScheduled>()
            .having((state) => state.exitCode, "exitCode", 1)
            .having((state) => state.crashCount, "crashCount", 1)
            .having((state) => state.delay, "delay", const Duration(hours: 1)),
      );
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

    test("rollback-generated expected exit still enters automatic startup retry", () async {
      authSession.state = _authenticatedState;
      await service.start();
      logTracker.attachError = StateError("pipe attach failed");
      repository.emitExpectedExitOnStop = true;
      final Future<BridgeProcessState> retryScheduled = service.states.firstWhere(
        (state) => state is BridgeProcessCrashRetryScheduled,
      );

      repository.emitExit(exitCode: 86, expected: false);
      final BridgeProcessState retryState = await retryScheduled;

      expect(repository.spawnCalls, 2);
      expect(
        retryState,
        isA<BridgeProcessCrashRetryScheduled>()
            .having((state) => state.exitCode, "exitCode", isNull)
            .having((state) => state.crashCount, "crashCount", 1),
      );
      expect(service.desiredState, BridgeProcessDesiredState.on);
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

      await pumpEventQueue();
      expect(controlServer.stopCalls, greaterThanOrEqualTo(1));
      expect(
        service.state,
        isA<BridgeProcessCrashRetryScheduled>()
            .having((state) => state.exitCode, "exitCode", 1)
            .having((state) => state.crashCount, "crashCount", 1),
      );
    });

    test("cleanup failures never replace the original startup error", () async {
      authSession.state = _authenticatedState;
      final StateError attachError = StateError("pipe attach failed");
      logTracker.attachError = attachError;
      repository.stopError = StateError("kill failed");
      controlServer.stopError = StateError("server stop failed");

      await expectLater(service.start(), throwsA(same(attachError)));

      expect(warnings, hasLength(2));
      expect(
        service.state,
        isA<BridgeProcessStopping>().having((state) => state.pid, "pid", 42),
      );
    });

    test("disposal revokes the control server while preserving the process-stop error", () async {
      authSession.state = _authenticatedState;
      await service.start();
      final StateError stopError = StateError("process stop failed");
      repository.stopError = stopError;
      controlServer.stopError = StateError("control stop failed");

      await expectLater(service.dispose(), throwsA(same(stopError)));

      expect(controlServer.stopCalls, 1);
      expect(
        warnings,
        contains("Failed to stop the bridge control server during disposal"),
      );
    });

    test("exit 86 immediately respawns exactly once", () async {
      authSession.state = _authenticatedState;
      await service.start();

      repository.emitExit(exitCode: 86, expected: false);
      await pumpEventQueue();

      expect(repository.spawnCalls, 2);
      expect(controlServer.startCalls, 2);
      expect(service.state, isA<BridgeProcessRunning>());
      await pumpEventQueue();
      expect(repository.spawnCalls, 2);
    });

    test("exit 86 during startup queues its respawn after the start slot clears", () async {
      authSession.state = _authenticatedState;
      logTracker.onAttach = () {
        logTracker.onAttach = null;
        repository.emitExit(exitCode: 86, expected: false);
      };
      final Future<BridgeProcessState> restarted = service.states.firstWhere(
        (state) => state is BridgeProcessRunning,
      );

      await expectLater(
        service.start(),
        throwsA(isA<BridgeProcessExitedDuringStartException>()),
      );
      await restarted;

      expect(repository.spawnCalls, 2);
      expect(controlServer.startCalls, 2);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("a claimed exit followed by broken-pipe startup failure consumes one crash entry", () async {
      authSession.state = _authenticatedState;
      await service.start();
      when(streams.stdin.flush).thenAnswer((_) {
        repository.emitExit(exitCode: 9, expected: false);
        return Future<void>.error(StateError("broken pipe"));
      });
      final Future<BridgeProcessState> retryScheduled = service.states.firstWhere(
        (state) => state is BridgeProcessCrashRetryScheduled,
      );

      repository.emitExit(exitCode: 86, expected: false);
      final BridgeProcessState retryState = await retryScheduled;

      expect(repository.spawnCalls, 2);
      expect(
        retryState,
        isA<BridgeProcessCrashRetryScheduled>()
            .having((state) => state.exitCode, "exitCode", 9)
            .having((state) => state.crashCount, "crashCount", 1),
      );
      await pumpEventQueue();
      expect(service.state, same(retryState));
      expect(warnings, contains("Bridge startup failed after its process exit was already claimed"));
    });

    test("an exit emitted before spawn returns is claimed by exactly one retry policy", () async {
      authSession.state = _authenticatedState;
      await service.start();
      repository.onSpawnBeforeReturn = () {
        repository.onSpawnBeforeReturn = null;
        repository.emitExit(exitCode: 9, expected: false);
      };
      final Future<BridgeProcessState> retryScheduled = service.states.firstWhere(
        (state) => state is BridgeProcessCrashRetryScheduled,
      );

      repository.emitExit(exitCode: 86, expected: false);
      final BridgeProcessState retryState = await retryScheduled;

      expect(repository.spawnCalls, 2);
      expect(
        retryState,
        isA<BridgeProcessCrashRetryScheduled>()
            .having((state) => state.exitCode, "exitCode", 9)
            .having((state) => state.crashCount, "crashCount", 1),
      );
      await pumpEventQueue();
      expect(service.state, same(retryState));
    });

    test("exit 87 waits for a successful sign-in before restarting desired On", () async {
      authSession.state = _authenticatedState;
      await service.start();

      repository.emitExit(exitCode: 87, expected: false);
      await pumpEventQueue();

      expect(service.state, isA<BridgeProcessLoginRequired>());
      expect(service.desiredState, BridgeProcessDesiredState.on);
      expect(repository.spawnCalls, 1);

      authSession.state = const AuthState.unauthenticated();
      authSession.state = _authenticatedState;
      await pumpEventQueue();

      expect(repository.spawnCalls, 2);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("an authentication completed before the exit-87 event still restarts desired On", () async {
      authSession.state = _authenticatedState;
      await service.start();
      authSession.state = const AuthState.unauthenticated();
      authSession.state = _authenticatedState;
      await pumpEventQueue(times: 2);
      final Future<BridgeProcessState> restarted = service.states
          .skip(1)
          .firstWhere(
            (state) => state is BridgeProcessRunning,
          );

      repository.emitExit(exitCode: 87, expected: false);
      await restarted;

      expect(repository.spawnCalls, 2);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("an authentication completed during exit-87 cleanup still restarts desired On", () async {
      authSession.state = _authenticatedState;
      await service.start();
      controlServer.stopGate = Completer<void>();
      final Future<BridgeProcessState> restarted = service.states
          .skip(1)
          .firstWhere(
            (state) => state is BridgeProcessRunning,
          );

      repository.emitExit(exitCode: 87, expected: false);
      await pumpEventQueue(times: 2);
      authSession.state = const AuthState.unauthenticated();
      authSession.state = _authenticatedState;
      await pumpEventQueue(times: 2);
      controlServer.stopGate!.complete();
      await restarted;

      expect(repository.spawnCalls, 2);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("manual Off while login is required prevents a later sign-in restart", () async {
      authSession.state = _authenticatedState;
      await service.start();
      repository.emitExit(exitCode: 87, expected: false);
      await pumpEventQueue();

      await service.stop();
      authSession.state = const AuthState.unauthenticated();
      authSession.state = _authenticatedState;
      await pumpEventQueue();

      expect(service.desiredState, BridgeProcessDesiredState.off);
      expect(service.state, isA<BridgeProcessStopped>());
      expect(repository.spawnCalls, 1);
    });

    test("exit 88 surfaces contention and an explicit start performs a plain respawn", () async {
      authSession.state = _authenticatedState;
      await service.start();

      repository.emitExit(exitCode: 88, expected: false);
      await pumpEventQueue();

      expect(service.state, isA<BridgeProcessContention>());
      expect(repository.spawnCalls, 1);

      await service.start();

      expect(repository.spawnCalls, 2);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("clean exit never respawns", () async {
      authSession.state = _authenticatedState;
      await service.start();

      repository.emitExit(exitCode: 0, expected: false);
      await pumpEventQueue();

      expect(service.state, isA<BridgeProcessStopped>());
      expect(service.desiredState, BridgeProcessDesiredState.off);
      expect(repository.spawnCalls, 1);
    });

    test("Start supersedes the expected marker retained by a failed Off", () async {
      authSession.state = _authenticatedState;
      await service.start();
      repository.stopError = StateError("process remained alive");
      await expectLater(service.stop(), throwsA(isA<StateError>()));

      repository.stopError = null;
      await service.start();
      final Future<BridgeProcessState> retryScheduled = service.states.firstWhere(
        (state) => state is BridgeProcessCrashRetryScheduled,
      );
      repository.emitExit(exitCode: 35, expected: true);
      final BridgeProcessState retryState = await retryScheduled;

      expect(
        retryState,
        isA<BridgeProcessCrashRetryScheduled>()
            .having((state) => state.exitCode, "exitCode", 35)
            .having((state) => state.crashCount, "crashCount", 1),
      );
      expect(service.desiredState, BridgeProcessDesiredState.on);
    });

    test("rapid crashes exhaust the bounded budget and surface only recent log lines", () async {
      await rebuildService(
        crashBackoffDelays: const <Duration>[Duration.zero, Duration.zero],
        stableRuntime: const Duration(minutes: 5),
        recentLogCount: 2,
      );
      authSession.state = _authenticatedState;
      logTracker.entries = <BridgeProcessLogEntry>[
        BridgeProcessLogEntry(
          timestamp: now,
          source: BridgeProcessLogSource.stdout,
          message: "old",
        ),
        BridgeProcessLogEntry(
          timestamp: now,
          source: BridgeProcessLogSource.stderr,
          message: "recent-1",
        ),
        BridgeProcessLogEntry(
          timestamp: now,
          source: BridgeProcessLogSource.stdout,
          message: "recent-2",
        ),
      ];
      await service.start();

      repository.emitExit(exitCode: 11, expected: false);
      await pumpEventQueue();
      expect(repository.spawnCalls, 2);
      repository.emitExit(exitCode: 12, expected: false);
      await pumpEventQueue();
      expect(repository.spawnCalls, 3);
      repository.emitExit(exitCode: 13, expected: false);
      await pumpEventQueue();

      expect(
        service.state,
        isA<BridgeProcessCrashGiveUp>()
            .having((state) => state.exitCode, "exitCode", 13)
            .having((state) => state.crashCount, "crashCount", 3)
            .having(
              (state) => state.recentLogs.map((entry) => entry.message),
              "recent logs",
              <String>["recent-1", "recent-2"],
            ),
      );
      await pumpEventQueue();
      expect(repository.spawnCalls, 3);
    });

    test("a stable control-connected runtime resets the crash budget", () async {
      await rebuildService(
        crashBackoffDelays: const <Duration>[Duration.zero, Duration(hours: 1)],
        stableRuntime: const Duration(minutes: 5),
        recentLogCount: 20,
      );
      authSession.state = _authenticatedState;
      await service.start();

      final Future<BridgeProcessState> respawned = service.states
          .skip(1)
          .firstWhere((state) => state is BridgeProcessRunning);
      repository.emitExit(exitCode: 20, expected: false);
      await respawned;
      expect(repository.spawnCalls, 2);

      statusTracker.markHelperConnected();
      await pumpEventQueue(times: 2);
      now = now.add(const Duration(minutes: 6));
      statusTracker.markHelperDisconnected();
      await pumpEventQueue(times: 2);
      repository.emitExit(exitCode: 21, expected: false);
      await pumpEventQueue();

      expect(repository.spawnCalls, 3);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("a disconnected interval does not reset the crash budget", () async {
      await rebuildService(
        crashBackoffDelays: const <Duration>[Duration.zero, Duration(hours: 1)],
        stableRuntime: const Duration(minutes: 5),
        recentLogCount: 20,
      );
      authSession.state = _authenticatedState;
      await service.start();

      final Future<BridgeProcessState> respawned = service.states
          .skip(1)
          .firstWhere((state) => state is BridgeProcessRunning);
      repository.emitExit(exitCode: 20, expected: false);
      await respawned;

      statusTracker.markHelperConnected();
      await pumpEventQueue(times: 2);
      now = now.add(const Duration(minutes: 4));
      statusTracker.markHelperDisconnected();
      await pumpEventQueue(times: 2);
      statusTracker.markHelperConnected();
      await pumpEventQueue(times: 2);
      now = now.add(const Duration(minutes: 2));
      repository.emitExit(exitCode: 21, expected: false);
      await pumpEventQueue();

      expect(
        service.state,
        isA<BridgeProcessCrashRetryScheduled>()
            .having((state) => state.crashCount, "crashCount", 2)
            .having((state) => state.delay, "delay", const Duration(hours: 1)),
      );
      expect(repository.spawnCalls, 2);
    });

    test("manual Start cancels a pending retry without a delayed second helper", () async {
      await rebuildService(
        crashBackoffDelays: const <Duration>[Duration(milliseconds: 25)],
        stableRuntime: const Duration(minutes: 5),
        recentLogCount: 20,
      );
      authSession.state = _authenticatedState;
      await service.start();
      repository.emitExit(exitCode: 30, expected: false);
      await pumpEventQueue(times: 2);
      expect(service.state, isA<BridgeProcessCrashRetryScheduled>());

      await service.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.spawnCalls, 2);
      expect(service.state, isA<BridgeProcessRunning>());
    });

    test("manual Off cancels a pending retry", () async {
      await rebuildService(
        crashBackoffDelays: const <Duration>[Duration(milliseconds: 25)],
        stableRuntime: const Duration(minutes: 5),
        recentLogCount: 20,
      );
      authSession.state = _authenticatedState;
      await service.start();
      repository.emitExit(exitCode: 31, expected: false);
      await pumpEventQueue(times: 2);
      expect(service.state, isA<BridgeProcessCrashRetryScheduled>());

      await service.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.spawnCalls, 1);
      expect(service.state, isA<BridgeProcessStopped>());
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
    final _FakeAuthSession authSession = _FakeAuthSession(initialState: _authenticatedState);
    final BridgeProcessService service = BridgeProcessService.forTesting(
      repository: repository,
      logTracker: logTracker,
      statusTracker: statusTracker,
      controlChannelServer: server,
      authSession: authSession,
      executablePathResolver: _FakeBridgeExecutablePathResolver(path: "/repo/bridge"),
      crashBackoffDelays: const <Duration>[Duration(hours: 1)],
      stableRuntime: const Duration(minutes: 5),
      recentLogCount: 20,
      now: DateTime.now,
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
      await authSession.disposeFake();
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
  bool emitExpectedExitOnStop = false;
  void Function()? onSpawnBeforeReturn;
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
    onSpawnBeforeReturn?.call();
    return streams;
  }

  @override
  Future<void> stopExpected() async {
    stopCalls++;
    final Object? failure = stopError;
    if (failure != null) {
      throw failure;
    }
    if (emitExpectedExitOnStop) {
      emitExit(exitCode: 0, expected: true);
      return;
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
  List<BridgeProcessLogEntry> entries = <BridgeProcessLogEntry>[];
  Stream<List<int>>? attachedStdout;
  Stream<List<int>>? attachedStderr;
  Object? attachError;
  void Function()? onAttach;

  @override
  List<BridgeProcessLogEntry> get snapshot => List<BridgeProcessLogEntry>.unmodifiable(entries);

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
  Completer<void>? stopGate;

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
    final Completer<void>? gate = stopGate;
    if (gate != null) {
      await gate.future;
    }
    final Object? failure = stopError;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthSession({required AuthState initialState}) implements AuthSession {
  late final BehaviorSubject<AuthState> _states;

  this {
    _states = BehaviorSubject<AuthState>.seeded(initialState);
  }

  AuthState get state => _states.value;

  set state(AuthState value) => _states.add(value);

  @override
  ValueStream<AuthState> get authStateStream => _states.stream;

  @override
  AuthState get currentState => state;

  Future<void> disposeFake() => _states.close();

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
