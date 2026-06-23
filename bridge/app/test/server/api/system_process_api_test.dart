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

    test("inspectProcess returns null for a non-positive PID without shelling out", () async {
      final runner = _RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
      );

      expect(await api.inspectProcess(pid: 0), isNull);
      expect(await api.inspectProcess(pid: -1), isNull);
      expect(runner.calls, isEmpty);
    });
  });

  group("SystemProcessApi (POSIX)", () {
    test("inspectProcess issues a PID-scoped ps query and parses one identity", () async {
      final runner = _RecordingProcessRunner(
        stdout: "  321 alex     Mon Jun 22 09:15:01 2026 /usr/local/bin/sesori-bridge --relay wss://relay\n",
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
      );

      final identity = await api.inspectProcess(pid: 321);

      // The OS must do the filtering — never a full process-table scan.
      expect(runner.calls, hasLength(1));
      final call = runner.calls.single;
      expect(call.executable, equals("ps"));
      expect(call.arguments, containsAllInOrder(<String>["-p", "321"]));
      expect(call.arguments, contains("-wwo"));
      // The list selectors `a`/`x` must be dropped for the targeted lookup.
      expect(call.arguments, isNot(contains("-axwwo")));
      expect(call.environment, equals(<String, String>{"LC_ALL": "C"}));

      expect(identity, isNotNull);
      expect(identity!.pid, equals(321));
      expect(identity.startMarker, equals("Mon Jun 22 09:15:01 2026"));
      expect(identity.executablePath, equals("/usr/local/bin/sesori-bridge"));
      expect(identity.commandLine, equals("/usr/local/bin/sesori-bridge --relay wss://relay"));
      expect(identity.ownerUser, equals(ProcessUser.fromRawUser("alex")));
      expect(identity.platform, equals("macos"));
    });

    test("inspectProcess returns null (without throwing) when ps exits non-zero with no stderr", () async {
      // A vanished pid: `ps -p` exits non-zero with empty stdout AND empty
      // stderr. That is the legitimate "no such process" signal.
      final runner = _RecordingProcessRunner(exitCode: 1, stdout: "", stderr: "");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
      );

      final identity = await api.inspectProcess(pid: 999999);

      expect(identity, isNull);
      expect(runner.calls.single.arguments, containsAllInOrder(<String>["-p", "999999"]));
    });

    test("inspectProcess throws (not null) when ps exits non-zero with stderr", () async {
      // A genuine invocation/format failure writes to stderr. It must NOT be
      // collapsed to null — callers rely on POSIX self-inspection errors
      // staying fatal so the startup lock is never poisoned with a
      // marker-less fallback identity.
      final runner = _RecordingProcessRunner(exitCode: 1, stdout: "", stderr: "ps: unknown option");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
      );

      await expectLater(
        api.inspectProcess(pid: 321),
        throwsA(isA<ProcessException>()),
      );
    });

    test("inspectProcess returns null when ps yields no matching row", () async {
      final runner = _RecordingProcessRunner(stdout: "\n");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
      );

      expect(await api.inspectProcess(pid: 321), isNull);
    });

    test("inspectProcess returns null for a non-positive PID without shelling out", () async {
      final runner = _RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
      );

      expect(await api.inspectProcess(pid: 0), isNull);
      expect(await api.inspectProcess(pid: -1), isNull);
      expect(runner.calls, isEmpty);
    });
  });
}

class _RecordedCall {
  _RecordedCall({required this.executable, required this.arguments, required this.environment});

  final String executable;
  final List<String> arguments;
  final Map<String, String>? environment;
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
    calls.add(_RecordedCall(executable: executable, arguments: arguments, environment: environment));
    return ProcessResult(1, exitCode, stdout, stderr);
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) {
    throw UnimplementedError();
  }
}
