import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/server/api/system_process_api.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("SystemProcessApi (Windows)", () {
    test("inspectProcess issues a PID-scoped tasklist filter", () async {
      final runner = _RecordingProcessRunner(
        stdout: '"sesori-bridge.exe","321","Console","1","12,345 K","Running","HOST\\alex","0:00:01","N/A"\r\n',
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
      );

      final identity = await api.inspectProcess(pid: 321);

      // The OS must do the filtering — never a full /V process-table scan.
      expect(runner.calls, hasLength(1));
      final call = runner.calls.single;
      expect(call.executable, equals("tasklist"));
      expect(call.arguments, containsAllInOrder(<String>["/FI", "PID eq 321"]));

      expect(identity, isNotNull);
      expect(identity!.pid, equals(321));
      expect(identity.executablePath, equals("sesori-bridge.exe"));
      expect(identity.ownerUser, equals(ProcessUser.fromRawUser(r"HOST\alex")));
      expect(identity.platform, equals("windows"));
    });

    test("inspectProcess returns null when tasklist reports no matching task", () async {
      final runner = _RecordingProcessRunner(
        stdout: "INFO: No tasks are running which match the specified criteria.\r\n",
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
      );

      final identity = await api.inspectProcess(pid: 999999);

      expect(identity, isNull);
      expect(runner.calls.single.arguments, containsAllInOrder(<String>["/FI", "PID eq 999999"]));
    });

    test("inspectProcess throws on non-zero tasklist exit", () async {
      final runner = _RecordingProcessRunner(exitCode: 1, stderr: "boom");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
      );

      await expectLater(
        api.inspectProcess(pid: 321),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}

class _RecordedCall {
  _RecordedCall({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}

class _RecordingProcessRunner implements ProcessRunner {
  _RecordingProcessRunner({this.exitCode = 0, this.stdout = "", this.stderr = ""});

  final int exitCode;
  final String stdout;
  final String stderr;
  final List<_RecordedCall> calls = <_RecordedCall>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    calls.add(_RecordedCall(executable: executable, arguments: arguments));
    return ProcessResult(1, exitCode, stdout, stderr);
  }
}
