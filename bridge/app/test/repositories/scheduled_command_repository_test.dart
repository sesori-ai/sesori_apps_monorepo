@TestOn("!windows")
library;

import "dart:async";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/api/shell_command_api.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:sesori_bridge/src/repositories/models/scheduled_command_result.dart";
import "package:sesori_bridge/src/repositories/prompt_upload_repository.dart";
import "package:sesori_bridge/src/repositories/scheduled_command_repository.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:test/test.dart";

void main() {
  late Directory root;
  late Directory project;
  late ScheduledCommandRepository commands;
  late PromptUploadRepository outputs;

  setUp(() {
    root = Directory.systemTemp.createTempSync("scheduled_command_test_");
    addTearDown(() => root.deleteSync(recursive: true));
    project = Directory(p.join(root.path, "project"))..createSync();
    commands = ScheduledCommandRepository(
      shell: ShellCommandApi.forPlatform(
        platform: PlatformOs.linux,
        runner: const StreamingProcessRunner(),
        tools: ProcessRunner(),
        environment: const {"SHELL": "/bin/sh"},
      ),
      files: const FilesystemApi(),
    );
    outputs = PromptUploadRepository(filesystemApi: const FilesystemApi(), uploadsRoot: p.join(root.path, "output"));
  });

  Future<ScheduledCommandResult> run({
    required String command,
    Duration timeout = const Duration(seconds: 30),
    Future<void>? stop,
  }) async {
    return await commands.run(
      folder: await outputs.reserveFolder(sessionId: "s1"),
      command: command,
      workingDirectory: project.path,
      timeout: timeout,
      stop: stop ?? Completer<void>().future,
    );
  }

  test("reports the exit code and keeps each stream in its own file in an owner-only folder", () async {
    final result = await run(command: "pwd; echo 'two words' >&2; exit 3");

    switch (result) {
      case ScheduledCommandExited(:final exitCode, :final stdout, :final stderr):
        expect(exitCode, 3);
        expect(stdout.text?.trim(), project.resolveSymbolicLinksSync());
        expect(stderr.text, "two words\n");
        expect(stderr.wordCount, 2);
        final stdoutPath = stdout.path ?? fail("stdout was not saved");
        expect(p.isWithin(p.join(root.path, "output", "s1"), stdoutPath), isTrue);
        expect(File(stderr.path ?? fail("stderr was not saved")).readAsStringSync(), "two words\n");
        expect(Directory(p.dirname(stdoutPath)).statSync().mode & 0x3F, 0, reason: "group and others have no access");
      case final other:
        fail("ran as $other");
    }
  });

  test("a long stream keeps only its count and last lines in memory", () async {
    final result = await run(command: r"i=0; while [ $i -lt 5000 ]; do echo line $i; i=$((i+1)); done");

    switch (result) {
      case ScheduledCommandExited(:final stdout):
        expect(stdout.text, isNull);
        expect(stdout.wordCount, 10000);
        expect(stdout.lastLines, hasLength(20));
        expect(stdout.lastLines.last, "line 4999");
        expect(File(stdout.path ?? fail("stdout was not saved")).readAsLinesSync(), hasLength(5000));
      case final other:
        fail("ran as $other");
    }
  });

  test("a command past its timeout is killed", () async {
    final started = DateTime.now();
    final result = await run(command: "echo started; exec sleep 30", timeout: const Duration(milliseconds: 500));

    expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 10)));
    expect(
      result,
      isA<ScheduledCommandTimedOut>().having((timedOut) => timedOut.stdout.text, "stdout", "started\n"),
    );
  });

  test("a stop kills a running command", () async {
    final stop = Completer<void>();
    final result = run(command: "echo started; exec sleep 30", stop: stop.future);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    stop.complete();

    expect(
      await result.timeout(const Duration(seconds: 10)),
      isA<ScheduledCommandStopped>().having((stopped) => stopped.stdout.text, "stdout", "started\n"),
    );
  });

  test("a stop kills the processes the command started too", () async {
    final pidFile = p.join(root.path, "child.pid");
    final stop = Completer<void>();
    final result = run(command: "sleep 30 & echo \$! > '$pidFile'; wait", stop: stop.future);
    while (!File(pidFile).existsSync() || File(pidFile).readAsStringSync().trim().isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final child = File(pidFile).readAsStringSync().trim();
    stop.complete();

    expect(await result.timeout(const Duration(seconds: 10)), isA<ScheduledCommandStopped>());
    var alive = true;
    for (var attempt = 0; alive && attempt < 50; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      alive = Process.runSync("kill", ["-0", child]).exitCode == 0;
    }
    expect(alive, isFalse);
  });

  test("a stream whose file cannot be written is still counted", () async {
    final result = await commands.run(
      folder: p.join(root.path, "missing"),
      command: "echo hello",
      workingDirectory: project.path,
      timeout: const Duration(seconds: 30),
      stop: Completer<void>().future,
    );

    expect(
      result,
      isA<ScheduledCommandExited>().having(
        (exited) => exited.stdout,
        "stdout",
        isA<CommandStreamOutput>()
            .having((stdout) => stdout.path, "path", isNull)
            .having((stdout) => stdout.text, "text", "hello\n"),
      ),
    );
  });

  test("a missing working directory could not start", () async {
    final result = await commands.run(
      folder: await outputs.reserveFolder(sessionId: "s1"),
      command: "true",
      workingDirectory: p.join(root.path, "gone"),
      timeout: const Duration(seconds: 30),
      stop: Completer<void>().future,
    );

    expect(result, isA<ScheduledCommandCouldNotStart>());
  });

  test("a command that reads stdin does not wait for it", () async {
    expect(await run(command: "cat"), isA<ScheduledCommandExited>().having((exited) => exited.exitCode, "exitCode", 0));
  });
}
