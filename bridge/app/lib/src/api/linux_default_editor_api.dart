import '../foundation/process_runner.dart';
import 'default_editor_api.dart';

class LinuxDefaultEditorApi({
  required ProcessRunner processRunner,
}) implements DefaultEditorApi {
  final ProcessRunner _runProcess = processRunner;

  @override
  Future<void> openFile(String filePath) async {
    await _runProcess.startDetached(
      executable: 'xdg-open',
      arguments: [filePath],
    );
  }
}
