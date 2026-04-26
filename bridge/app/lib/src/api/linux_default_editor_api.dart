import 'dart:io';

import '../bridge/foundation/process_runner.dart';
import 'default_editor_api.dart';

class LinuxDefaultEditorApi implements DefaultEditorApi {
  final ProcessRunner _runProcess;

  LinuxDefaultEditorApi({
    required ProcessRunner processRunner,
  }) : _runProcess = processRunner;

  @override
  Future<void> openFile(String filePath) async {
    await _openWithCommand(
      executable: 'xdg-open',
      arguments: [filePath],
      filePath: filePath,
    );
  }

  Future<void> _openWithCommand({
    required String executable,
    required List<String> arguments,
    required String filePath,
  }) async {
    final ProcessResult result = await _runProcess.run(executable, arguments);
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
