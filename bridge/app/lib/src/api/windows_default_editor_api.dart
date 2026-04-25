import 'dart:io';

import 'default_editor_api.dart';

typedef _ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

class WindowsDefaultEditorApi implements DefaultEditorApi {
  final _ProcessRunner _runProcess;

  WindowsDefaultEditorApi({
    required _ProcessRunner runProcess,
  }) : _runProcess = runProcess;

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
    try {
      final ProcessResult result = await _runProcess(executable, arguments);
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
