@TestOn("windows")
library;

import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/server/api/system_process_api.dart";
import "package:sesori_bridge/src/server/api/windows_job_object_api.dart";
import "package:sesori_bridge/src/server/host/bridge_host_process_service.dart";
import "package:sesori_bridge/src/server/repositories/process_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

// Runs in the Windows job of Bridge CI, over the real process table.
void main() {
  test("stopping a child that shares helpers ends its tool command and leaves the helper running", () async {
    final host = BridgeHostProcessService(
      processStarter: Process.start,
      processRepository: ProcessRepository(
        api: SystemProcessApi(processRunner: ProcessRunner(), clock: const ServerClock(), isWindows: true),
        windowsJobObjectApi: WindowsJobObjectApi(),
        currentUser: null,
      ),
      clock: const ServerClock(),
      currentUser: null,
      isWindows: true,
    );
    // Like `omp acp`: one ordinary child (a tool command) and one helper whose
    // command line carries the marker (the shared daemon). Start-Process does
    // not quote its arguments, so the marker lands in a PowerShell comment.
    // Each child gets its own hidden console, so none holds this test's pipes.
    final root = await host.spawn(
      includeParentEnvironment: true,
      executable: "powershell.exe",
      arguments: const [
        "-NoProfile",
        "-NonInteractive",
        "-Command",
        _rootScript,
      ],
      environment: null,
      workingDirectory: null,
      runInShell: false,
      lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: {"__test_shared_helper"}),
    );
    addTearDown(() => Process.killPid(root.pid));
    root.stderr.drain<void>().ignore();
    final pidsLine = await root.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .firstWhere((line) => line.startsWith("pids "));
    final [helper, toolCommand] = pidsLine.substring("pids ".length).trim().split(" ").map(int.parse).toList();
    addTearDown(() => Process.killPid(helper));
    addTearDown(() => Process.killPid(toolCommand));
    expect(await _isRunning(pid: helper, image: "POWERSHELL.EXE"), isTrue);
    expect(await _isRunning(pid: toolCommand, image: "PING.EXE"), isTrue);

    await host.signalGraceful(pid: root.pid);

    await root.exitCode.timeout(const Duration(seconds: 10));
    expect(await _endsWithin(pid: toolCommand, image: "PING.EXE", timeout: const Duration(seconds: 10)), isTrue);
    expect(await _endsWithin(pid: helper, image: "POWERSHELL.EXE", timeout: const Duration(seconds: 3)), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

const _rootScript =
    r"$h = Start-Process powershell.exe -WindowStyle Hidden -PassThru "
    "-ArgumentList '-NoProfile','-Command','Start-Sleep 120; #','__test_shared_helper'; "
    r"$c = Start-Process ping.exe -WindowStyle Hidden -PassThru -ArgumentList '-n','120','127.0.0.1'; "
    r"[Console]::WriteLine('pids ' + $h.Id + ' ' + $c.Id); [Console]::Out.Flush(); Start-Sleep 120";

Future<bool> _endsWithin({required int pid, required String image, required Duration timeout}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!await _isRunning(pid: pid, image: image)) return true;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return false;
}

/// Filters on the image name too, so a reused pid does not read as alive.
Future<bool> _isRunning({required int pid, required String image}) async {
  final result = await Process.run("tasklist", [
    "/FI",
    "PID eq $pid",
    "/FI",
    "IMAGENAME eq $image",
    "/FO",
    "CSV",
    "/NH",
  ]);
  return "${result.stdout}".contains('"$pid"');
}
