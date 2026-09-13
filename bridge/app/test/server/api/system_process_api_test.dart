import "dart:io";

import "package:sesori_bridge/src/server/api/system_process_api.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/fake_process_runner.dart";

void main() {
  group("SystemProcessApi (Windows)", () {
    test("inspectProcess issues a PID-scoped tasklist filter", () async {
      final runner = RecordingProcessRunner(
        stdout: '"sesori-bridge.exe","321","Console","1","12,345 K","Running","HOST\\alex","0:00:01","N/A"\r\n',
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
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
      final runner = RecordingProcessRunner(
        stdout: "INFO: No tasks are running which match the specified criteria.\r\n",
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
      );

      final identity = await api.inspectProcess(pid: 999999);

      expect(identity, isNull);
      expect(runner.calls.single.arguments, containsAllInOrder(<String>["/FI", "PID eq 999999"]));
    });

    test("inspectProcess throws on non-zero tasklist exit", () async {
      final runner = RecordingProcessRunner(exitCode: 1, stderr: "boom");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
      );

      await expectLater(
        api.inspectProcess(pid: 321),
        throwsA(isA<ProcessException>()),
      );
    });

    test("inspectProcess returns null for a non-positive PID without shelling out", () async {
      final runner = RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
      );

      expect(await api.inspectProcess(pid: 0), isNull);
      expect(await api.inspectProcess(pid: -1), isNull);
      expect(runner.calls, isEmpty);
    });

    test("sendGracefulSignal requests the full Windows process tree without forcing", () async {
      final runner = RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
      );

      final result = await api.sendGracefulSignal(pid: 321);

      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.executable, "taskkill");
      expect(runner.calls.single.arguments, ["/PID", "321", "/T"]);
      expect(result.requestedSignal, ShutdownSignal.graceful);
      expect(result.deliveredSignal, ProcessSignal.sigterm);
      expect(result.wasRequested, isTrue);
    });

    test("sendForceSignal force-terminates the full Windows process tree", () async {
      final runner = RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
      );

      final result = await api.sendForceSignal(pid: 321);

      expect(runner.calls, hasLength(1));
      expect(runner.calls.single.executable, "taskkill");
      expect(runner.calls.single.arguments, ["/PID", "321", "/T", "/F"]);
      expect(result.requestedSignal, ShutdownSignal.force);
      expect(result.deliveredSignal, ProcessSignal.sigkill);
      expect(result.wasRequested, isTrue);
    });

    test("Windows signals exclude a restart predecessor from tree termination", () async {
      final runner = RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: 321,
      );

      await api.sendGracefulSignal(pid: 321);
      await api.sendForceSignal(pid: 321);

      expect(runner.calls.map((call) => call.arguments).toList(), [
        ["/PID", "321"],
        ["/PID", "321", "/F"],
      ]);
    });

    test("Windows signals throw with taskkill diagnostics while the process remains", () async {
      final runner = RecordingProcessRunner(
        responder: (executable, arguments, {environment, workingDirectory, timeout = const Duration(seconds: 15)}) {
          if (executable == "taskkill") return ProcessResult(1, 5, "", "Access is denied");
          return ProcessResult(
            2,
            0,
            '"sesori-bridge.exe","321","Console","1","12,345 K","Running","HOST\\alex","0:00:01","N/A"\r\n',
            "",
          );
        },
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
      );

      await expectLater(
        api.sendForceSignal(pid: 321),
        throwsA(
          isA<ProcessException>()
              .having((error) => error.errorCode, "exit code", 5)
              .having((error) => error.message, "message", contains("Access is denied")),
        ),
      );
      expect(runner.calls.map((call) => call.executable).toList(), ["taskkill", "tasklist"]);
    });

    test("Windows signals treat a failed taskkill as already gone only after inspection", () async {
      final runner = RecordingProcessRunner(
        responder: (executable, arguments, {environment, workingDirectory, timeout = const Duration(seconds: 15)}) {
          return executable == "taskkill"
              ? ProcessResult(1, 128, "", "No running instance")
              : ProcessResult(2, 0, "INFO: No tasks match the specified criteria.\r\n", "");
        },
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
      );

      expect((await api.sendGracefulSignal(pid: 321)).wasRequested, isFalse);
      expect(runner.calls.map((call) => call.executable).toList(), ["taskkill", "tasklist"]);
    });

    test("Windows signals reject non-positive PIDs without shelling out", () async {
      final runner = RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
        platform: "windows",
        treeTerminationExcludedRootPid: null,
      );

      expect((await api.sendGracefulSignal(pid: 0)).wasRequested, isFalse);
      expect((await api.sendForceSignal(pid: -1)).wasRequested, isFalse);
      expect(runner.calls, isEmpty);
    });
  });

  group("SystemProcessApi (POSIX)", () {
    test("inspectProcess issues a PID-scoped ps query and parses one identity", () async {
      final runner = RecordingProcessRunner(
        stdout: "  321 alex     Mon Jun 22 09:15:01 2026 /usr/local/bin/sesori-bridge --relay wss://relay\n",
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
        treeTerminationExcludedRootPid: null,
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
      final runner = RecordingProcessRunner(exitCode: 1, stdout: "", stderr: "");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
        treeTerminationExcludedRootPid: null,
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
      final runner = RecordingProcessRunner(exitCode: 1, stdout: "", stderr: "ps: unknown option");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
        treeTerminationExcludedRootPid: null,
      );

      await expectLater(
        api.inspectProcess(pid: 321),
        throwsA(isA<ProcessException>()),
      );
    });

    test("inspectProcess returns null when ps yields no matching row", () async {
      final runner = RecordingProcessRunner(stdout: "\n");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
        treeTerminationExcludedRootPid: null,
      );

      expect(await api.inspectProcess(pid: 321), isNull);
    });

    test("inspectProcess returns null for a non-positive PID without shelling out", () async {
      final runner = RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
        platform: "macos",
        treeTerminationExcludedRootPid: null,
      );

      expect(await api.inspectProcess(pid: 0), isNull);
      expect(await api.inspectProcess(pid: -1), isNull);
      expect(runner.calls, isEmpty);
    });
  });
}
