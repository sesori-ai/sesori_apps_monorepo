import "dart:async";
import "dart:io" as io;

import "package:sesori_bridge/src/api/macos_wake_lock_api.dart";
import "package:test/test.dart";

void main() {
  group("MacOSWakeLockApi", () {
    test("starts caffeinate with the current pid and kills it on disable", () async {
      final process = _FakeProcess();
      final invocations = <_ProcessInvocation>[];

      final api = MacOSWakeLockApi(
        processStarter: (String executable, List<String> arguments) async {
          invocations.add(_ProcessInvocation(executable: executable, arguments: arguments));
          return process;
        },
      );

      await api.enable();
      await api.disable();

      expect(invocations, hasLength(1));
      expect(invocations.single.executable, equals("caffeinate"));
      expect(invocations.single.arguments, equals(<String>["-w", io.pid.toString()]));
      expect(process.killCalled, isTrue);
    });

    test("logs warning when caffeinate process fails to start", () async {
      final invocations = <_ProcessInvocation>[];

      final api = MacOSWakeLockApi(
        processStarter: (String executable, List<String> arguments) async {
          invocations.add(_ProcessInvocation(executable: executable, arguments: arguments));
          throw const io.ProcessException("caffeinate", <String>["-w", "123"], "command not found");
        },
      );

      await api.enable();

      expect(invocations, hasLength(1));
    });
  });
}

class _ProcessInvocation {
  final String executable;
  final List<String> arguments;

  _ProcessInvocation({required this.executable, required this.arguments});
}

class _FakeProcess implements io.Process {
  bool killCalled = false;

  @override
  int get pid => 12345;

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  io.IOSink get stdin => io.stdout;

  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    killCalled = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
