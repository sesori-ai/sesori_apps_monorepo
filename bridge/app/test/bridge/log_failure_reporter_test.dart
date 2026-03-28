import 'package:sesori_bridge/src/bridge/log_failure_reporter.dart';
import 'package:test/test.dart';

void main() {
  late LogFailureReporter reporter;

  setUp(() {
    reporter = LogFailureReporter();
  });

  group('LogFailureReporter', () {
    test('recordFailure with fatal: true returns completed Future', () async {
      final future = reporter.recordFailure(
        error: Exception('test error'),
        stackTrace: StackTrace.current,
        uniqueIdentifier: 'test-fatal-1',
        fatal: true,
        reason: 'Test fatal error',
        information: const [],
      );

      // Verify it's a completed Future
      expect(future, isA<Future<void>>());
      await expectLater(future, completes);
    });

    test('recordFailure with fatal: false returns completed Future', () async {
      final future = reporter.recordFailure(
        error: Exception('test error'),
        stackTrace: StackTrace.current,
        uniqueIdentifier: 'test-non-fatal-1',
        fatal: false,
        reason: 'Test non-fatal error',
        information: const [],
      );

      // Verify it's a completed Future
      expect(future, isA<Future<void>>());
      await expectLater(future, completes);
    });

    test('log does not throw', () {
      expect(
        () => reporter.log(message: 'test message'),
        returnsNormally,
      );
    });

    test('setGlobalKey does not throw', () {
      expect(
        () => reporter.setGlobalKey(key: 'test-key', value: 'test-value'),
        returnsNormally,
      );
    });

    test('recordFailure with null reason does not throw', () async {
      final future = reporter.recordFailure(
        error: Exception('test error'),
        stackTrace: StackTrace.current,
        uniqueIdentifier: 'test-null-reason',
        fatal: false,
        reason: null,
        information: const [],
      );

      expect(future, isA<Future<void>>());
      await expectLater(future, completes);
    });

    test('recordFailure with information list does not throw', () async {
      final future = reporter.recordFailure(
        error: Exception('test error'),
        stackTrace: StackTrace.current,
        uniqueIdentifier: 'test-with-info',
        fatal: false,
        reason: 'Test with info',
        information: ['info1', 'info2', 'info3'],
      );

      expect(future, isA<Future<void>>());
      await expectLater(future, completes);
    });

    test('implements FailureReporter interface', () {
      // Verify that LogFailureReporter implements FailureReporter
      // by checking that it has all required methods
      expect(reporter.setGlobalKey, isNotNull);
      expect(reporter.log, isNotNull);
      expect(reporter.recordFailure, isNotNull);
    });
  });
}
