import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('StartAbortController', () {
    test('starts unaborted', () {
      final controller = StartAbortController();
      expect(controller.isAborted, isFalse);
      expect(controller.signal.isAborted, isFalse);
    });

    test('abort flips the signal and completes whenAborted', () async {
      final controller = StartAbortController();

      controller.abort();

      expect(controller.isAborted, isTrue);
      expect(controller.signal.isAborted, isTrue);
      await expectLater(controller.signal.whenAborted, completes);
    });

    test('abort is idempotent', () {
      final controller = StartAbortController();
      controller.abort();
      expect(controller.abort, returnsNormally);
      expect(controller.isAborted, isTrue);
    });
  });

  group('StartAbortSignal.never', () {
    test('is never aborted', () {
      expect(StartAbortSignal.never.isAborted, isFalse);
    });

    test('hands out a fresh unrooted future per whenAborted call', () {
      expect(StartAbortSignal.never.whenAborted, isNot(same(StartAbortSignal.never.whenAborted)));
    });
  });

  group('PluginStartAbortedException', () {
    test('is a PluginStartException with a default message', () {
      const exception = PluginStartAbortedException();
      expect(exception, isA<PluginStartException>());
      expect(exception.toString(), 'PluginStartAbortedException: Plugin start aborted by the bridge.');
    });
  });
}
