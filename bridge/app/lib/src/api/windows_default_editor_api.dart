import 'dart:io';

import '../bridge/foundation/process_runner.dart';
import 'default_editor_api.dart';

class WindowsDefaultEditorApi implements DefaultEditorApi {
  final ProcessRunner _processRunner;

  WindowsDefaultEditorApi({
    required ProcessRunner processRunner,
  }) : _processRunner = processRunner;

  @override
  Future<void> openFile(String filePath) async {
    // `start` is a cmd builtin, so it must run via `cmd /c`. The empty "" is the
    // mandatory window-title argument — without it `start` treats a quoted path
    // as the title and opens nothing. This deliberately differs from the OAuth
    // URL launcher, which uses `rundll32 url.dll,FileProtocolHandler` because
    // URLs carry `&` query separators that cmd would split into bogus commands.
    // A local file path is the opposite trade-off: Process.run quotes any path
    // containing spaces (so config files under C:\Users\... open correctly),
    // whereas rundll32's FileProtocolHandler is unreliable for spaced paths.
    await _openWithCommand(
      executable: 'cmd',
      arguments: ['/c', 'start', '', filePath],
      filePath: filePath,
    );
  }

  Future<void> _openWithCommand({
    required String executable,
    required List<String> arguments,
    required String filePath,
  }) async {
    final ProcessResult result = await _processRunner.run(executable, arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        'Failed to open "$filePath" (exit ${result.exitCode}): ${result.stderr}',
        result.exitCode,
      );
    }
  }
}
