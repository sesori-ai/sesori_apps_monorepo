import "dart:async";
import "dart:io";

import "package:clock/clock.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/repositories/models/scheduled_command_result.dart";
import "package:sesori_bridge/src/repositories/prompt_upload_repository.dart";
import "package:sesori_bridge/src/repositories/scheduled_command_repository.dart";
import "package:sesori_bridge/src/services/scheduled_command_result_formatter.dart";
import "package:sesori_bridge/src/services/scheduled_command_service.dart";
import "package:test/test.dart";

void main() {
  test("dispose stops a running command and waits for it", () async {
    final root = Directory.systemTemp.createTempSync("scheduled_command_service_test_");
    addTearDown(() => root.deleteSync(recursive: true));
    final commands = _StoppableCommands();
    final service = ScheduledCommandService(
      commands: commands,
      outputs: PromptUploadRepository(filesystemApi: const FilesystemApi(), uploadsRoot: p.join(root.path, "output")),
      formatter: const ScheduledCommandResultFormatter(),
      clock: const Clock(),
    );

    final result = service.run(outputKey: "s1", command: "sleep 30", workingDirectory: root.path);
    await commands.started.future;
    await service.dispose();

    expect(await result, startsWith("stopped by a bridge shutdown"));
    expect(Directory(p.join(root.path, "output", "s1")).listSync(), hasLength(1));
  });
}

/// Runs until its stop completes.
class _StoppableCommands() implements ScheduledCommandRepository {
  final Completer<void> started = Completer<void>();

  @override
  Future<ScheduledCommandResult> run({
    required String folder,
    required String command,
    required String workingDirectory,
    required Duration timeout,
    required Future<void> stop,
  }) async {
    started.complete();
    await stop;
    const empty = CommandStreamOutput(path: null, wordCount: 0, lastLines: [], text: "");
    return const ScheduledCommandStopped(stdout: empty, stderr: empty);
  }
}
