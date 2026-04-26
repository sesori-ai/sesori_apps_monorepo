import '../api/default_editor_api.dart';

class DefaultEditorRepository {
  DefaultEditorRepository({required DefaultEditorApi api}) : _api = api;

  final DefaultEditorApi _api;

  Future<void> openFile(String filePath) {
    return _api.openFile(filePath);
  }
}
