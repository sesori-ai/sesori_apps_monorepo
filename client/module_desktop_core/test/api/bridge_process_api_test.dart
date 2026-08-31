import "dart:async";
import "dart:io";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  group("BridgeProcessApi", () {
    test("spawn returns raw stdio and forwards launch settings", () async {
      final _ProcessFixture fixture = _ProcessFixture(pid: 42);
      addTearDown(fixture.dispose);
      String? launchedExecutable;
      List<String>? launchedArguments;
      String? launchedWorkingDirectory;
      Map<String, String>? launchedEnvironment;
      final BridgeProcessApi api = BridgeProcessApi.forTesting(
        isWindows: false,
        startProcess:
            ({
              required String executable,
              required List<String> arguments,
              required String? workingDirectory,
              required Map<String, String>? environment,
            }) async {
              launchedExecutable = executable;
              launchedArguments = arguments;
              launchedWorkingDirectory = workingDirectory;
              launchedEnvironment = environment;
              return fixture.process;
            },
        runCommand: _unusedCommandRunner,
        sendSignal: _unusedSignalSender,
      );

      final BridgeProcessApiHandle handle = await api.spawn(
        executable: "/opt/sesori/bridge",
        arguments: const ["--control-url", "ws://127.0.0.1:1"],
        workingDirectory: "/workspace",
        environment: const {"A": "B"},
      );

      expect(handle.pid, 42);
      expect(handle.stdin, same(fixture.stdin));
      expect(handle.stdout, same(fixture.stdout));
      expect(handle.stderr, same(fixture.stderr));
      expect(launchedExecutable, "/opt/sesori/bridge");
      expect(launchedArguments, const ["--control-url", "ws://127.0.0.1:1"]);
      expect(launchedWorkingDirectory, "/workspace");
      expect(launchedEnvironment, const {"A": "B"});
    });

    test("spawn rejects a non-positive child pid before returning it", () async {
      final _ProcessFixture fixture = _ProcessFixture(pid: 0);
      addTearDown(fixture.dispose);
      when(() => fixture.process.kill(ProcessSignal.sigkill)).thenReturn(true);
      final BridgeProcessApi api = BridgeProcessApi.forTesting(
        isWindows: false,
        startProcess: ({
          required String executable,
          required List<String> arguments,
          required String? workingDirectory,
          required Map<String, String>? environment,
        }) async => fixture.process,
        runCommand: _unusedCommandRunner,
        sendSignal: _unusedSignalSender,
      );

      await expectLater(
        api.spawn(
          executable: "bridge",
          arguments: const <String>[],
          workingDirectory: null,
          environment: null,
        ),
        throwsA(isA<InvalidBridgeProcessIdException>()),
      );
      verify(() => fixture.process.kill(ProcessSignal.sigkill)).called(1);
    });

    test("POSIX process-tree kill targets the dedicated helper process group", () async {
      final List<(int, ProcessSignal)> signals = <(int, ProcessSignal)>[];
      final BridgeProcessApi api = BridgeProcessApi.forTesting(
        isWindows: false,
        startProcess: _unusedStarter,
        runCommand: _unusedCommandRunner,
        sendSignal: ({required int pid, required ProcessSignal signal}) {
          signals.add((pid, signal));
          return true;
        },
      );

      await api.killProcessTree(pid: 100);

      expect(signals, equals(<(int, ProcessSignal)>[(-100, ProcessSignal.sigkill)]));
    });

    test("POSIX process-tree kill reports rejected group delivery", () async {
      final BridgeProcessApi api = BridgeProcessApi.forTesting(
        isWindows: false,
        startProcess: _unusedStarter,
        runCommand: _unusedCommandRunner,
        sendSignal: ({required int pid, required ProcessSignal signal}) => false,
      );

      await expectLater(
        api.killProcessTree(pid: 100),
        throwsA(
          isA<BridgeProcessTreeKillException>()
              .having((error) => error.pid, "pid", 100)
              .having((error) => error.details, "details", contains("process group 100")),
        ),
      );
    });

    test("Windows force-kill uses taskkill tree mode", () async {
      String? launchedExecutable;
      List<String>? launchedArguments;
      final BridgeProcessApi api = BridgeProcessApi.forTesting(
        isWindows: true,
        startProcess: _unusedStarter,
        runCommand: ({required String executable, required List<String> arguments}) async {
          launchedExecutable = executable;
          launchedArguments = arguments;
          return ProcessResult(1, 0, "", "");
        },
        sendSignal: _unusedSignalSender,
      );

      await api.killProcessTree(pid: 321);

      expect(launchedExecutable, "taskkill");
      expect(launchedArguments, const ["/PID", "321", "/T", "/F"]);
      expect(api.sendGracefulSignal(pid: 321), isFalse);
    });

    test("all signal and kill entry points reject non-positive pids", () async {
      final BridgeProcessApi api = BridgeProcessApi.forTesting(
        isWindows: false,
        startProcess: _unusedStarter,
        runCommand: _unusedCommandRunner,
        sendSignal: _unusedSignalSender,
      );

      expect(() => api.sendGracefulSignal(pid: 0), throwsA(isA<InvalidBridgeProcessIdException>()));
      await expectLater(api.killProcessTree(pid: -1), throwsA(isA<InvalidBridgeProcessIdException>()));
    });
  });
}

Future<Process> _unusedStarter({
  required String executable,
  required List<String> arguments,
  required String? workingDirectory,
  required Map<String, String>? environment,
}) => throw UnimplementedError();

Future<ProcessResult> _unusedCommandRunner({
  required String executable,
  required List<String> arguments,
}) => throw UnimplementedError();

bool _unusedSignalSender({required int pid, required ProcessSignal signal}) => throw UnimplementedError();

class _ProcessFixture({required int pid}) {
  final _MockProcess process = _MockProcess();
  final _MockIOSink stdin = _MockIOSink();
  final StreamController<List<int>> stdoutController = StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stderrController = StreamController<List<int>>.broadcast();
  final Completer<int> exitCode = Completer<int>();
  late final Stream<List<int>> stdout = stdoutController.stream;
  late final Stream<List<int>> stderr = stderrController.stream;

  this {
    when(() => process.pid).thenReturn(pid);
    when(() => process.stdin).thenReturn(stdin);
    when(() => process.stdout).thenAnswer((_) => stdout);
    when(() => process.stderr).thenAnswer((_) => stderr);
    when(() => process.exitCode).thenAnswer((_) => exitCode.future);
  }

  Future<void> dispose() async {
    await stdoutController.close();
    await stderrController.close();
  }
}

class _MockProcess() extends Mock implements Process;

class _MockIOSink() extends Mock implements IOSink;
