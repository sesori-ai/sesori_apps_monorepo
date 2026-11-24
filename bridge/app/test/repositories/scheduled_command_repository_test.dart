@TestOn("!windows")
library;

import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/api/shell_command_api.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:sesori_bridge/src/repositories/prompt_upload_repository.dart";
import "package:sesori_bridge/src/repositories/scheduled_command_repository.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:test/test.dart";

void main() {
  late Directory root;
  late Directory project;
  late ScheduledCommandRepository commands;

  setUp(() {
    root = Directory.systemTemp.createTempSync("scheduled_command_test_");
    addTearDown(() => root.deleteSync(recursive: true));
    project = Directory(p.join(root.path, "project"))..createSync();
    commands = ScheduledCommandRepository(
      shell: ShellCommandApi.forPlatform(
        platform: PlatformOs.linux,
        runner: const StreamingProcessRunner(),
        filesystem: const FilesystemApi(),
        environment: const {"SHELL": "/bin/sh"},
      ),
      outputs: PromptUploadRepository(filesystemApi: const FilesystemApi(), uploadsRoot: p.join(root.path, "output")),
    );
  });

  Future<ShellCommandResult> run({required String command, Duration timeout = const Duration(seconds: 30)}) {
    return commands.run(outputKey: "s1", command: command, workingDirectory: project.path, timeout: timeout);
  }

  test("reports the exit code and keeps each stream in its own owner-only file", () async {
    final result = await run(command: "pwd; echo 'two words' >&2; exit 3");

    switch (result) {
      case ShellCommandExited(:final exitCode, :final stdout, :final stderr):
        expect(exitCode, 3);
        expect(stdout.text?.trim(), project.resolveSymbolicLinksSync());
        expect(stderr.text, "two words\n");
        expect(stderr.wordCount, 2);
        expect(p.isWithin(p.join(root.path, "output", "s1"), stdout.path), isTrue);
        expect(File(stderr.path).readAsStringSync(), "two words\n");
        expect(File(stdout.path).statSync().mode & 0x3F, 0, reason: "group and others have no access");
      case final other:
        fail("ran as $other");
    }
  });

  test("a long stream keeps only its count and last lines in memory", () async {
    final result = await run(command: r"i=0; while [ $i -lt 5000 ]; do echo line $i; i=$((i+1)); done");

    switch (result) {
      case ShellCommandExited(:final stdout):
        expect(stdout.text, isNull);
        expect(stdout.wordCount, 10000);
        expect(stdout.lastLines, hasLength(20));
        expect(stdout.lastLines.last, "line 4999");
        expect(File(stdout.path).readAsLinesSync(), hasLength(5000));
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
      isA<ShellCommandTimedOut>().having((timedOut) => timedOut.stdout.text, "stdout", "started\n"),
    );
  });

  test("a missing working directory could not start", () async {
    final result = await commands.run(
      outputKey: "s1",
      command: "true",
      workingDirectory: p.join(root.path, "gone"),
      timeout: const Duration(seconds: 30),
    );

    expect(result, isA<ShellCommandCouldNotStart>());
  });

  test("a command that reads stdin does not wait for it", () async {
    expect(await run(command: "cat"), isA<ShellCommandExited>().having((exited) => exited.exitCode, "exitCode", 0));
  });
}
