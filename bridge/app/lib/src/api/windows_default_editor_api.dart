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
