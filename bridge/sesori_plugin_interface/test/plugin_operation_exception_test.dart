import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('PluginOperationException', () {
    test('statusCode is optional', () {
      const exception = PluginOperationException('createSession', message: 'cli exited 1');
      expect(exception.statusCode, isNull);
      expect(exception.isNotFound, isFalse);
      expect(exception.toString(), 'PluginOperationException: createSession failed: cli exited 1');
    });

    test('notFound constructor marks the failure as not-found', () {
      const exception = PluginOperationException.notFound('deleteSession');
      expect(exception.isNotFound, isTrue);
      expect(exception.statusCode, 404);
    });
  });

  group('PluginApiException', () {
    test('is a PluginOperationException with a non-null status', () {
      final exception = PluginApiException('/session/abc', 502);
      expect(exception, isA<PluginOperationException>());
      expect(exception.statusCode, 502);
      expect(exception.operation, '/session/abc');
      expect(exception.endpoint, '/session/abc');
    });

    test('keeps its historical toString format', () {
      final exception = PluginApiException('/session/abc', 404);
      expect(exception.toString(), 'PluginApiException: /session/abc failed with status 404');
      expect(exception.isNotFound, isTrue);
    });
  });
}
