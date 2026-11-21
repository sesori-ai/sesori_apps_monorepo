import "dart:io";

import "package:sesori_bridge/src/server/api/system_process_api.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/fake_process_runner.dart";

void main() {
  const windowsProcessRow =
      '"sesori-bridge.exe","321","Console","1","12,345 K","Running","HOST\\alex","0:00:01","N/A"\r\n';

  group("SystemProcessApi (Windows)", () {
    test("inspectProcess issues a PID-scoped tasklist filter", () async {
      final runner = RecordingProcessRunner(
        stdout: '"sesori-bridge.exe","321","Console","1","12,345 K","Running","HOST\\alex","0:00:01","N/A"\r\n',
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
      );

      final identity = await api.inspectProcess(pid: 321);

      // The OS must do the filtering — never a full /V process-table scan.
      expect(runner.calls, hasLength(1));
      final call = runner.calls.single;
      expect(call.executable, equals("tasklist"));
      expect(call.arguments, containsAllInOrder(<String>["/FI", "PID eq 321"]));

      if (identity == null) fail("expected a process identity");
      expect(identity.pid, equals(321));
      expect(identity.executablePath, equals("sesori-bridge.exe"));
      expect(identity.ownerUser, equals(ProcessUser.fromRawUser(r"HOST\alex")));
    });

    test("inspectProcess returns null when tasklist reports no matching task", () async {
      final runner = RecordingProcessRunner(
        stdout: "INFO: No tasks are running which match the specified criteria.\r\n",
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
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
      );

      expect(await api.inspectProcess(pid: 0), isNull);
      expect(await api.inspectProcess(pid: -1), isNull);
      expect(runner.calls, isEmpty);
    });

    test("sendGracefulSignal requests the full Windows process tree without forcing", () async {
      final runner = RecordingProcessRunner(stdout: windowsProcessRow);
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
      );

      final result = await api.sendGracefulSignal(pid: 321);

      expect(runner.calls, hasLength(2));
      expect(runner.calls.first.executable, "tasklist");
      expect(runner.calls.last.executable, "taskkill");
      expect(runner.calls.last.arguments, ["/PID", "321", "/T"]);
      expect(result.requestedSignal, ShutdownSignal.graceful);
      expect(result.deliveredSignal, ProcessSignal.sigterm);
      expect(result.wasRequested, isTrue);
    });

    test("sendForceSignal force-terminates the full Windows process tree", () async {
      final runner = RecordingProcessRunner(stdout: windowsProcessRow);
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
      );

      final result = await api.sendForceSignal(pid: 321);

      expect(runner.calls, hasLength(2));
      expect(runner.calls.first.executable, "tasklist");
      expect(runner.calls.last.executable, "taskkill");
      expect(runner.calls.last.arguments, ["/PID", "321", "/T", "/F"]);
      expect(result.requestedSignal, ShutdownSignal.force);
      expect(result.deliveredSignal, ProcessSignal.sigkill);
      expect(result.wasRequested, isTrue);
    });

    test("a failed tree request is not hidden by the root disappearing afterward", () async {
      final runner = RecordingProcessRunner(
        responder: (executable, arguments, {environment, workingDirectory, timeout = const Duration(seconds: 15)}) {
          return executable == "tasklist"
              ? ProcessResult(1, 0, windowsProcessRow, "")
              : ProcessResult(2, 5, "", "A descendant could not be terminated");
        },
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
      );

      await expectLater(
        api.sendForceSignal(pid: 321),
        throwsA(
          isA<ProcessException>().having(
            (error) => error.message,
            "message",
            contains("A descendant could not be terminated"),
          ),
        ),
      );
      // Root-only post-inspection would be unable to prove tree success. There
      // must be no third call that can collapse the partial failure to absence.
      expect(runner.calls.map((call) => call.executable).toList(), ["tasklist", "taskkill"]);
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
      );

      await expectLater(
        api.sendForceSignal(pid: 321),
        throwsA(
          isA<ProcessException>()
              .having((error) => error.errorCode, "exit code", 5)
              .having((error) => error.message, "message", contains("Access is denied")),
        ),
      );
      expect(runner.calls.map((call) => call.executable).toList(), ["tasklist", "taskkill"]);
    });

    test("Windows signals skip taskkill when inspection proves the process is already gone", () async {
      final runner = RecordingProcessRunner(
        stdout: "INFO: No tasks match the specified criteria.\r\n",
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
      );

      expect((await api.sendGracefulSignal(pid: 321)).wasRequested, isFalse);
      expect(runner.calls.map((call) => call.executable).toList(), ["tasklist"]);
    });

    test("Windows signals reject non-positive PIDs without shelling out", () async {
      final runner = RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
      );

      expect((await api.sendGracefulSignal(pid: 0)).wasRequested, isFalse);
      expect((await api.sendForceSignal(pid: -1)).wasRequested, isFalse);
      expect(runner.calls, isEmpty);
    });

    test("listDescendants walks the CIM process table and leaves out shared helpers", () async {
      // 10 -> 11 (tool command) -> 12; 10 -> 13 (shared daemon) -> 14 (its service);
      // 15 names 10 as its parent but is older, so that id was reused.
      final runner = RecordingProcessRunner(
        stdout:
            '"ProcessId","ParentProcessId","CreationTime","CommandLine"\r\n'
            '"0","0","",""\r\n'
            '"10","4","100","""C:\\Program Files\\omp\\omp.exe"" acp"\r\n'
            '"11","10","110","cmd.exe /c ping -n 30 127.0.0.1"\r\n'
            '"12","11","111","ping -n 30 127.0.0.1"\r\n'
            '"13","10","120","""C:\\Program Files\\omp\\omp.exe"" __omp_worker_daemon"\r\n'
            '"14","13","130","""C:\\Program Files\\omp\\omp.exe"" __omp_worker_shell_process"\r\n'
            '"15","10","50","C:\\Windows\\explorer.exe"\r\n'
            '"16","15","60","notepad.exe"\r\n',
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
      );

      final descendants = await api.listDescendants(pid: 10, sharedHelperArguments: const {"__omp_worker_daemon"});

      expect(descendants, unorderedEquals(<int>[11, 12]));
      expect(runner.calls.single.executable, equals("powershell.exe"));
      expect(runner.calls.single.arguments.last, contains("Win32_Process"));
    });

    test("killWindowsProcess force-kills only the process itself", () async {
      final runner = RecordingProcessRunner(stdout: windowsProcessRow);
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: true,
      );

      final result = await api.killWindowsProcess(pid: 321, requestedSignal: ShutdownSignal.graceful);

      expect(runner.calls.last.executable, "taskkill");
      expect(runner.calls.last.arguments, ["/PID", "321", "/F"]);
      expect(result.requestedSignal, ShutdownSignal.graceful);
      expect(result.deliveredSignal, ProcessSignal.sigkill);
      expect(result.wasRequested, isTrue);
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

      if (identity == null) fail("expected a process identity");
      expect(identity.pid, equals(321));
      expect(identity.startMarker, equals("Mon Jun 22 09:15:01 2026"));
      expect(identity.executablePath, equals("/usr/local/bin/sesori-bridge"));
      expect(identity.commandLine, equals("/usr/local/bin/sesori-bridge --relay wss://relay"));
      expect(identity.ownerUser, equals(ProcessUser.fromRawUser("alex")));
    });

    test("inspectProcess returns null (without throwing) when ps exits non-zero with no stderr", () async {
      // A vanished pid: `ps -p` exits non-zero with empty stdout AND empty
      // stderr. That is the legitimate "no such process" signal.
      final runner = RecordingProcessRunner(exitCode: 1, stdout: "", stderr: "");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
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
      );

      expect(await api.inspectProcess(pid: 321), isNull);
    });

    test("inspectProcess returns null for a non-positive PID without shelling out", () async {
      final runner = RecordingProcessRunner();
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
      );

      expect(await api.inspectProcess(pid: 0), isNull);
      expect(await api.inspectProcess(pid: -1), isNull);
      expect(runner.calls, isEmpty);
    });

    test("listDescendants returns every process below the pid, detached ones included", () async {
      // 10 -> 11 -> 13, 10 -> 12; 20 is a sibling tree; 1 is init.
      final runner = RecordingProcessRunner(
        stdout:
            "    1     0 /sbin/launchd\n"
            "   10     1 /usr/local/bin/agent acp\n"
            "   11    10 /bin/sh -c npm run dev\n"
            "   12    10 /usr/local/bin/agent __worker\n"
            "   13    11 node server.js\n"
            "   20     1 /bin/zsh\n"
            "   21    20 /usr/local/bin/agent\n",
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
      );

      final descendants = await api.listDescendants(pid: 10, sharedHelperArguments: const <String>{});

      expect(descendants, unorderedEquals(<int>[11, 12, 13]));
      expect(runner.calls.single.executable, equals("ps"));
      expect(runner.calls.single.arguments, equals(<String>["-A", "-o", "pid=,ppid=,args="]));
    });

    test("listDescendants leaves out a shared helper and everything below it", () async {
      // 10 -> 11 (tool command) -> 12; 10 -> 13 (shared daemon) -> 14 (its service).
      final runner = RecordingProcessRunner(
        stdout:
            "   10     1 /opt/omp acp\n"
            "   11    10 /bin/bash -c sleep 30\n"
            "   12    11 sleep 30\n"
            "   13    10 /opt/omp __omp_worker_daemon\n"
            "   14    13 /opt/omp __omp_worker_shell_process --source /tmp/s\n"
            "   15    10 /opt/omp __omp_worker_daemon_extra\n",
      );
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
      );

      final descendants = await api.listDescendants(pid: 10, sharedHelperArguments: const {"__omp_worker_daemon"});

      // Markers match whole arguments, so 15 is still signalled.
      expect(descendants, unorderedEquals(<int>[11, 12, 15]));
    });

    test("listDescendants throws when ps fails", () async {
      final runner = RecordingProcessRunner(exitCode: 1, stderr: "ps: unknown option");
      final api = SystemProcessApi(
        processRunner: runner,
        clock: const ServerClock(),
        isWindows: false,
      );

      await expectLater(
        api.listDescendants(pid: 10, sharedHelperArguments: const <String>{}),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}
