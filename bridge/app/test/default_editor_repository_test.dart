import 'package:sesori_bridge/src/api/default_editor_api.dart';
import 'package:sesori_bridge/src/repositories/default_editor_repository.dart';
import 'package:test/test.dart';

class _FakeDefaultEditorApi implements DefaultEditorApi {
  String? openedPath;

  @override
  Future<void> openFile(String filePath) async {
    openedPath = filePath;
  }
}

void main() {
  group('DefaultEditorRepository', () {
    test('openFile delegates to DefaultEditorApi', () async {
      final api = _FakeDefaultEditorApi();
      final repository = DefaultEditorRepository(api: api);

      await repository.openFile('/tmp/example.txt');

      expect(api.openedPath, equals('/tmp/example.txt'));
    });
  });
}
