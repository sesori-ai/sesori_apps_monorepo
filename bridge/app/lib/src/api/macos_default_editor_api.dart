import '../bridge/foundation/process_runner.dart';
import 'default_editor_api.dart';

class MacosDefaultEditorApi({
    required ProcessRunner processRunner,
  }) implements DefaultEditorApi {
  final ProcessRunner _processRunner;

  this : _processRunner = processRunner;

  @override
  Future<void> openFile(String filePath) async {
    await _processRunner.startDetached(
      executable: 'open',
      arguments: [filePath],
    );
  }
}
