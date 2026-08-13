import '../api/default_editor_api.dart';

class DefaultEditorRepository({required final DefaultEditorApi _api}) {
  Future<void> openFile(String filePath) {
    return _api.openFile(filePath);
  }
}
