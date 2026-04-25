import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/api/linux_wake_lock_api.dart";
import "package:test/test.dart";

void main() {
  group("LinuxWakeLockApi", () {
    test("spawns systemd-inhibit and kills it on disable", () async {
      final fakeProcess = _FakeProcess();
      final invocations = <_ProcessInvocation>[];
      final api = LinuxWakeLockApi(
        processStarter: (String executable, List<String> arguments) async {
          invocations.add(
            _ProcessInvocation(executable: executable, arguments: arguments),
          );
          return fakeProcess;
        },
      );

      await api.enable();
      await api.disable();

      expect(invocations, hasLength(1));
      expect(invocations.single.executable, equals("systemd-inhibit"));
      expect(
        invocations.single.arguments,
        equals(<String>[
          "--what=idle:sleep",
          "--who=sesori-bridge",
          "--why=Bridge is running",
          "sleep",
          "infinity",
        ]),
      );
      expect(fakeProcess.killSignals, hasLength(1));
      expect(fakeProcess.killSignals.single, equals(ProcessSignal.sigterm));
    });

    test("logs a warning when systemd-inhibit is unavailable", () async {
      final invocations = <_ProcessInvocation>[];
      final api = LinuxWakeLockApi(
        processStarter: (String executable, List<String> arguments) async {
          invocations.add(
            _ProcessInvocation(executable: executable, arguments: arguments),
          );
          throw const ProcessException(
            "systemd-inhibit",
            <String>[
              "--what=idle:sleep",
              "--who=sesori-bridge",
              "--why=Bridge is running",
              "sleep",
              "infinity",
            ],
            "No such file or directory",
          );
        },
      );

      await api.enable();
      await api.disable();

      expect(invocations, hasLength(1));
      expect(invocations.single.executable, equals("systemd-inhibit"));
      expect(invocations.single.arguments, isNotEmpty);
    });
  });
}

class _ProcessInvocation {
  _ProcessInvocation({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}

class _FakeProcess implements Process {
  final List<ProcessSignal> killSignals = <ProcessSignal>[];
  final Completer<int> _exitCode = Completer<int>();

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  int get pid => 12345;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    if (!_exitCode.isCompleted) {
      _exitCode.complete(0);
    }

    return true;
  }
}
