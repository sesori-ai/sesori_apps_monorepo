@TestOn("windows")
library;

import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/server/api/windows_job_object_api.dart";
import "package:test/test.dart";

// Runs in the Windows job of Bridge CI. The fixture stands in for the bridge:
// only the OS closing its job handle can end what it leaves running.
void main() {
  test("a runtime cmd.exe starts inside the job ends when the bridge is killed", () async {
    final fixture = await Process.start(Platform.resolvedExecutable, [_fixturePath, "--start-in-job"]);
    addTearDown(fixture.kill);
    final errors = StringBuffer();
    fixture.stderr.transform(utf8.decoder).listen(errors.write);
    final lines = await fixture.stdout.transform(utf8.decoder).transform(const LineSplitter()).take(1).toList();
    final pid = lines.isEmpty ? null : int.tryParse(lines.first.trim());
    if (pid == null) {
      fail("Fixture printed $lines\nstderr: $errors");
    }
    addTearDown(() => Process.killPid(pid));
    expect(await _isRunning(pid: pid, image: "POWERSHELL.EXE"), isTrue);

    // TerminateProcess, as in a crash: no bridge code runs on the way out.
    fixture.kill();

    expect(await _endsWithin(pid: pid, image: "POWERSHELL.EXE", timeout: const Duration(seconds: 10)), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test("a bound process ends when the process holding the job exits", () async {
    final pid = await _startPingThroughFixture(bind: true);
    addTearDown(() => Process.killPid(pid));

    expect(await _endsWithin(pid: pid, image: "PING.EXE", timeout: const Duration(seconds: 10)), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test("an unbound process outlives the process that started it", () async {
    final pid = await _startPingThroughFixture(bind: false);
    addTearDown(() => Process.killPid(pid));

    expect(await _endsWithin(pid: pid, image: "PING.EXE", timeout: const Duration(seconds: 3)), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

  group("starting inside the job gives the same result as Process.start", () {
    final temp = Directory.systemTemp.path;
    final cases = <_Case>[
      (
        name: "stdin and stdout",
        executable: "sort",
        arguments: [],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        includeParentEnvironment: true,
        input: "beta\r\nalpha\r\n",
        shows: "alpha\r\nbeta",
        exitCode: 0,
      ),
      (
        name: "quoted arguments",
        executable: "cmd",
        arguments: ["/c", "echo", "a b", 'c"d', r'e\"f', r"g h\", "", "tab\there"],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        includeParentEnvironment: true,
        input: null,
        shows: "tab\there",
        exitCode: 0,
      ),
      (
        name: "runInShell",
        executable: "echo",
        arguments: ["x y", "z"],
        environment: null,
        workingDirectory: null,
        runInShell: true,
        includeParentEnvironment: true,
        input: null,
        shows: "x y",
        exitCode: 0,
      ),
      (
        name: "environment over the parent's",
        executable: "cmd",
        arguments: ["/c", "set"],
        environment: {"SESORI_JOB_TEST": "one two"},
        workingDirectory: null,
        runInShell: false,
        includeParentEnvironment: true,
        input: null,
        shows: "SESORI_JOB_TEST=one two",
        exitCode: 0,
      ),
      (
        name: "environment without the parent's",
        executable: "cmd",
        arguments: ["/c", "set"],
        environment: {"SESORI_JOB_TEST": "only"},
        workingDirectory: null,
        runInShell: false,
        includeParentEnvironment: false,
        input: null,
        shows: "SESORI_JOB_TEST=only",
        exitCode: 0,
      ),
      (
        name: "stderr and exit code",
        executable: "cmd",
        arguments: ["/c", "echo out & echo oops 1>&2 & exit 3"],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        includeParentEnvironment: true,
        input: null,
        shows: "out",
        exitCode: 3,
      ),
      (
        name: "working directory",
        executable: "cmd",
        arguments: ["/c", "cd"],
        environment: null,
        workingDirectory: temp,
        runInShell: false,
        includeParentEnvironment: true,
        input: null,
        shows: temp.split(r"\\").lastWhere((part) => part.isNotEmpty),
        exitCode: 0,
      ),
    ];
    for (final testCase in cases) {
      test(testCase.name, () async {
        final expected = await _collect(
          process: await Process.start(
            testCase.executable,
            testCase.arguments,
            environment: testCase.environment,
            workingDirectory: testCase.workingDirectory,
            runInShell: testCase.runInShell,
            includeParentEnvironment: testCase.includeParentEnvironment,
          ),
          input: testCase.input,
        );
        final actual = await _collect(
          process: WindowsJobObjectApi().startBoundToBridgeLifetime(
            executable: testCase.executable,
            arguments: testCase.arguments,
            environment: testCase.environment,
            workingDirectory: testCase.workingDirectory,
            runInShell: testCase.runInShell,
            includeParentEnvironment: testCase.includeParentEnvironment,
          ),
          input: testCase.input,
        );

        // Unordered: the in-job environment block is sorted and Process.start's is not.
        expect(LineSplitter.split(actual.stdout), unorderedEquals(LineSplitter.split(expected.stdout)));
        expect((actual.stderr, actual.exitCode), (expected.stderr, expected.exitCode));
        expect(actual.stdout, contains(testCase.shows));
        expect(actual.exitCode, testCase.exitCode);
      });
    }

    test("kill", () async {
      final process = WindowsJobObjectApi().startBoundToBridgeLifetime(
        executable: "ping",
        arguments: ["-n", "30", "127.0.0.1"],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        includeParentEnvironment: true,
      );
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());

      expect(process.kill(), isTrue);
      expect(await process.exitCode, -1);
      expect(process.kill(), isFalse);
    });
  });

  test("an explicit variable replaces the parent's whatever its case", () async {
    final result = await _collect(
      process: WindowsJobObjectApi().startBoundToBridgeLifetime(
        executable: "cmd",
        arguments: ["/c", "set"],
        environment: {"pAtH": r"C:\sesori-job-test"},
        workingDirectory: null,
        runInShell: false,
        includeParentEnvironment: true,
      ),
      input: null,
    );

    expect(LineSplitter.split(result.stdout).where((line) => line.toUpperCase().startsWith("PATH=")), [
      r"pAtH=C:\sesori-job-test",
    ]);
  });
}

typedef _Case = ({
  String name,
  String executable,
  List<String> arguments,
  Map<String, String>? environment,
  String? workingDirectory,
  bool runInShell,
  bool includeParentEnvironment,
  String? input,
  String shows,
  int exitCode,
});

Future<({String stdout, String stderr, int exitCode})> _collect({
  required Process process,
  required String? input,
}) async {
  final stdout = process.stdout.transform(systemEncoding.decoder).join();
  final stderr = process.stderr.transform(systemEncoding.decoder).join();
  if (input != null) {
    process.stdin.write(input);
  }
  await process.stdin.close();
  return (stdout: await stdout, stderr: await stderr, exitCode: await process.exitCode);
}

String get _fixturePath => File("test/server/fixtures/windows_job_object_binder.dart").absolute.path;

Future<int> _startPingThroughFixture({required bool bind}) async {
  final result = await Process.run(Platform.resolvedExecutable, [_fixturePath, if (!bind) "--no-bind"]);
  final pid = int.tryParse("${result.stdout}".trim());
  if (result.exitCode != 0 || pid == null) {
    fail("Fixture exited ${result.exitCode}\nstdout: ${result.stdout}\nstderr: ${result.stderr}");
  }
  return pid;
}

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
