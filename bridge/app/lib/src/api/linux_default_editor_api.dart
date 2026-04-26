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
    try {
      final ProcessResult result = await _runProcess.run(executable, arguments);
      if (result.exitCode != 0) {
        stderr.writeln(
          'Warning: failed to open "$filePath" with $executable (exit ${result.exitCode}): ${result.stderr}',
        );
      }
    } on Object catch (error, stackTrace) {
      stderr.writeln('Warning: failed to open "$filePath" with $executable: $error\n$stackTrace');
    }
  }
}
