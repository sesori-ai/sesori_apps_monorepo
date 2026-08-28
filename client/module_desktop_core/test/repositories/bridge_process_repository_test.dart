import "dart:async";
import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeProcessRepository", () {
    late _ProcessHandleFixture fixture;
    late _FakeBridgeProcessApi processApi;
    late _FakeControlChannelServer controlServer;
    late BridgeProcessRepository repository;

    setUp(() {
      fixture = _ProcessHandleFixture(pid: 123);
      processApi = _FakeBridgeProcessApi(handle: fixture.handle);
      controlServer = _FakeControlChannelServer();
      repository = BridgeProcessRepository.forTesting(
        processApi: processApi,
        controlChannelServer: controlServer,
        gracefulShutdownTimeout: const Duration(milliseconds: 20),
        forcedExitTimeout: const Duration(milliseconds: 20),
      );
    });

    tearDown(() async {
      if (!fixture.exitCode.isCompleted) {
        fixture.exitCode.complete(0);
      }
      await pumpEventQueue();
      await repository.dispose();
      await fixture.dispose();
    });

    test("spawn hands off raw stdio and emits an unexpected exit", () async {
      final Future<BridgeProcessExit> exit = repository.exits.first;

      final BridgeProcessStreams streams = await _spawn(repository);

      expect(streams.pid, 123);
      expect(streams.stdin, same(fixture.stdin));
      expect(streams.stdout, same(fixture.stdout));
      expect(streams.stderr, same(fixture.stderr));
      expect(repository.isRunning, isTrue);
      await expectLater(_spawn(repository), throwsA(isA<BridgeProcessAlreadyRunningException>()));

      fixture.exitCode.complete(7);
      expect(await exit, const BridgeProcessExit(pid: 123, exitCode: 7, expected: false));
      expect(repository.isRunning, isFalse);
    });

    test("expected stop marks before sending shutdown and emits expected exit", () async {
      await _spawn(repository);
      final Future<BridgeProcessExit> exit = repository.exits.first;
      controlServer.onSend = () {
        fixture.exitCode.complete(0);
      };

      await repository.stopExpected();

      expect(controlServer.sentFrames, hasLength(1));
      final ControlMessage message = ControlMessage.fromJson(jsonDecodeMap(controlServer.sentFrames.single));
      expect(message, const ControlMessage.shutdown());
      expect(await exit, const BridgeProcessExit(pid: 123, exitCode: 0, expected: true));
      expect(processApi.gracefulSignalPids, isEmpty);
      expect(processApi.killedTreePids, isEmpty);
    });

    test("channel loss falls back to POSIX graceful signal", () async {
      await _spawn(repository);
      final Future<BridgeProcessExit> exit = repository.exits.first;
      controlServer.sendError = const ControlHelperNotConnectedException();
      processApi.onGracefulSignal = () {
        fixture.exitCode.complete(0);
      };

      await repository.stopExpected();

      expect(processApi.gracefulSignalPids, [123]);
      expect(processApi.killedTreePids, isEmpty);
      expect((await exit).expected, isTrue);
    });

    test("no graceful path force-kills the whole tree immediately", () async {
      await _spawn(repository);
      final Future<BridgeProcessExit> exit = repository.exits.first;
      controlServer.sendError = const ControlHelperNotConnectedException();
      processApi.gracefulSignalResult = false;
      processApi.onKill = () {
        fixture.exitCode.complete(-9);
      };

      await repository.stopExpected();

      expect(processApi.gracefulSignalPids, [123]);
      expect(processApi.killedTreePids, [123]);
      expect(await exit, const BridgeProcessExit(pid: 123, exitCode: -9, expected: true));
    });

    test("a helper that exceeds the graceful deadline is tree-killed without losing the marker", () async {
      await _spawn(repository);
      final Future<BridgeProcessExit> exit = repository.exits.first;
      processApi.onKill = () {
        fixture.exitCode.complete(-9);
      };

      final Future<void> first = repository.stopExpected();
      final Future<void> second = repository.stopExpected();
      expect(second, same(first));
      await first;

      expect(controlServer.sentFrames, hasLength(1));
      expect(processApi.killedTreePids, [123]);
      expect((await exit).expected, isTrue);
    });

    test("production grace strictly exceeds the bridge teardown maximum", () {
      const Duration bridgeMaximum = Duration(seconds: 46);

      expect(BridgeProcessRepository.defaultGracefulShutdownTimeout, greaterThan(bridgeMaximum));
    });
  });
}

Future<BridgeProcessStreams> _spawn(BridgeProcessRepository repository) => repository.spawn(
  executable: "/tmp/bridge",
  arguments: const ["--control-url", "ws://127.0.0.1:1"],
  workingDirectory: null,
  environment: null,
);

class _ProcessHandleFixture({required int pid}) {
  final _MockIOSink stdin = _MockIOSink();
  final StreamController<List<int>> stdoutController = StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stderrController = StreamController<List<int>>.broadcast();
  final Completer<int> exitCode = Completer<int>();
  late final Stream<List<int>> stdout = stdoutController.stream;
  late final Stream<List<int>> stderr = stderrController.stream;
  late final BridgeProcessApiHandle handle;

  this {
    when(stdin.close).thenAnswer((_) async {});
    handle = BridgeProcessApiHandle(
      pid: pid,
      stdin: stdin,
      stdout: stdout,
      stderr: stderr,
      exitCode: exitCode.future,
    );
  }

  Future<void> dispose() async {
    await stdoutController.close();
    await stderrController.close();
  }
}

class _MockIOSink() extends Mock implements IOSink;

class _FakeBridgeProcessApi({required final BridgeProcessApiHandle handle}) implements BridgeProcessApi {
  final List<int> gracefulSignalPids = <int>[];
  final List<int> killedTreePids = <int>[];
  bool gracefulSignalResult = true;
  void Function()? onGracefulSignal;
  void Function()? onKill;

  @override
  Future<BridgeProcessApiHandle> spawn({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
  }) async => handle;

  @override
  bool sendGracefulSignal({required int pid}) {
    gracefulSignalPids.add(pid);
    onGracefulSignal?.call();
    return gracefulSignalResult;
  }

  @override
  Future<void> killProcessTree({required int pid}) async {
    killedTreePids.add(pid);
    onKill?.call();
  }
}

class _FakeControlChannelServer() implements ControlChannelServer {
  final List<String> sentFrames = <String>[];
  Object? sendError;
  void Function()? onSend;

  @override
  void send(String text) {
    final Object? error = sendError;
    if (error != null) {
      throw error;
    }
    sentFrames.add(text);
    onSend?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
