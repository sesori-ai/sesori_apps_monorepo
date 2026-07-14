import '../bridge/foundation/process_runner.dart';
import 'default_editor_api.dart';

class LinuxDefaultEditorApi implements DefaultEditorApi {
  final ProcessRunner _runProcess;

  LinuxDefaultEditorApi({
    required ProcessRunner processRunner,
  }) : _runProcess = processRunner;

  @override
  Future<void> openFile(String filePath) async {
    await _runProcess.startDetached(
      executable: 'xdg-open',
      arguments: [filePath],
    );
  }
}
