import 'dart:io';

import '../bridge/foundation/process_runner.dart';
import 'default_editor_api.dart';

class MacosDefaultEditorApi implements DefaultEditorApi {
  final ProcessRunner _processRunner;

  MacosDefaultEditorApi({
    required ProcessRunner processRunner,
  }) : _processRunner = processRunner;

  @override
  Future<void> openFile(String filePath) async {
    await _openWithCommand(
      executable: 'open',
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
      final ProcessResult result = await _processRunner.run(executable, arguments);
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
