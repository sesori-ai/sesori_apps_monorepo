@TestOn("windows")
library;

import "dart:io";

import "package:test/test.dart";

// Runs in the Windows job of Bridge CI. The fixture binds a process and exits
// without stopping it, so only the OS closing the job handle can end it.
void main() {
  test("a bound process ends when the process holding the job exits", () async {
    final pid = await _startPingThroughFixture(bind: true);
    addTearDown(() => Process.killPid(pid));

    expect(await _endsWithin(pid: pid, timeout: const Duration(seconds: 10)), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test("an unbound process outlives the process that started it", () async {
    final pid = await _startPingThroughFixture(bind: false);
    addTearDown(() => Process.killPid(pid));

    expect(await _endsWithin(pid: pid, timeout: const Duration(seconds: 3)), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<int> _startPingThroughFixture({required bool bind}) async {
  final fixture = File("test/server/fixtures/windows_job_object_binder.dart").absolute.path;
  final result = await Process.run(Platform.resolvedExecutable, [fixture, if (!bind) "--no-bind"]);
  final pid = int.tryParse("${result.stdout}".trim());
  if (result.exitCode != 0 || pid == null) {
    fail("Fixture exited ${result.exitCode}\nstdout: ${result.stdout}\nstderr: ${result.stderr}");
  }
  return pid;
}

Future<bool> _endsWithin({required int pid, required Duration timeout}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!await _isPingRunning(pid: pid)) return true;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return false;
}

/// Filters on the image name too, so a reused pid does not read as alive.
Future<bool> _isPingRunning({required int pid}) async {
  final result = await Process.run("tasklist", [
    "/FI",
    "PID eq $pid",
    "/FI",
    "IMAGENAME eq PING.EXE",
    "/FO",
    "CSV",
    "/NH",
  ]);
  return "${result.stdout}".contains('"$pid"');
}
