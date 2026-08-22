import '../foundation/process_runner.dart';
import 'default_editor_api.dart';

class MacosDefaultEditorApi({
  required final ProcessRunner _processRunner,
}) implements DefaultEditorApi {
  @override
  Future<void> openFile(String filePath) async {
    await _processRunner.startDetached(
      executable: 'open',
      arguments: [filePath],
    );
  }
}
