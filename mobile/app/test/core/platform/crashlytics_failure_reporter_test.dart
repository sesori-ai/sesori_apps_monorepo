import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sesori_mobile/core/platform/crashlytics_failure_reporter.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockFirebaseCrashlytics mockCrashlytics;
  late CrashlyticsFailureReporter reporter;

  setUp(() {
    mockCrashlytics = MockFirebaseCrashlytics();
    reporter = CrashlyticsFailureReporter(mockCrashlytics);

    // Stub the methods that will be called
    when(
      () => mockCrashlytics.recordError(
        any<dynamic>(),
        any<StackTrace?>(),
        reason: any<dynamic>(named: 'reason'),
        information: any<List<Object>>(named: 'information'),
        fatal: any<bool>(named: 'fatal'),
      ),
    ).thenAnswer((_) async {});

    when(() => mockCrashlytics.setCustomKey(any<String>(), any<Object>())).thenAnswer((_) async {});
    when(() => mockCrashlytics.log(any<String>())).thenAnswer((_) async {});
  });

  group('Delegation tests', () {
    test('setGlobalKey delegates to setCustomKey', () {
      reporter.setGlobalKey(key: 'endpoint', value: '/api/orders');

      verify(() => mockCrashlytics.setCustomKey('endpoint', '/api/orders')).called(1);
    });

    test('log delegates to Crashlytics log', () {
      reporter.log(message: 'test');

      verify(() => mockCrashlytics.log('test')).called(1);
    });

    test('recordFailure non-fatal records to Crashlytics', () async {
      await reporter.recordFailure(
        error: Exception('test error'),
        stackTrace: StackTrace.current,
        uniqueIdentifier: 'test-1',
        fatal: false,
        reason: null,
        information: const [],
      );

      verify(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: null,
          information: [],
          fatal: false,
        ),
      ).called(1);
    });
  });

  group('Deduplication tests', () {
    test('recordFailure non-fatal duplicate is skipped', () async {
      final error = Exception('test error');
      final stackTrace = StackTrace.current;

      // First call should record
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'test-1',
        fatal: false,
        reason: null,
        information: const [],
      );

      // Second call with same ID should be skipped
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'test-1',
        fatal: false,
        reason: null,
        information: const [],
      );

      verify(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any<dynamic>(named: 'reason'),
          information: any<List<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).called(1);
    });

    test('recordFailure non-fatal different IDs both recorded', () async {
      final error = Exception('test error');
      final stackTrace = StackTrace.current;

      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'test-1',
        fatal: false,
        reason: null,
        information: const [],
      );

      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'test-2',
        fatal: false,
        reason: null,
        information: const [],
      );

      verify(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any<dynamic>(named: 'reason'),
          information: any<List<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).called(2);
    });
  });

  group('Fatal error tests', () {
    test('recordFailure fatal always records', () async {
      await reporter.recordFailure(
        error: Exception('fatal error'),
        stackTrace: StackTrace.current,
        uniqueIdentifier: 'fatal-1',
        fatal: true,
        reason: null,
        information: const [],
      );

      verify(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: null,
          information: [],
          fatal: true,
        ),
      ).called(1);
    });

    test('recordFailure fatal bypasses dedup', () async {
      final error = Exception('fatal error');
      final stackTrace = StackTrace.current;

      // First fatal call
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'same-id',
        fatal: true,
        reason: null,
        information: const [],
      );

      // Second fatal call with same ID should still record
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'same-id',
        fatal: true,
        reason: null,
        information: const [],
      );

      verify(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any<dynamic>(named: 'reason'),
          information: any<List<Object>>(named: 'information'),
          fatal: true,
        ),
      ).called(2);
    });

    test('recordFailure fatal does not pollute non-fatal dedup set', () async {
      final error = Exception('test error');
      final stackTrace = StackTrace.current;

      // First: fatal with ID 'test-id'
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'test-id',
        fatal: true,
        reason: null,
        information: const [],
      );

      // Second: non-fatal with same ID 'test-id' should still record
      // because fatal errors don't add to the non-fatal dedup set
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'test-id',
        fatal: false,
        reason: null,
        information: const [],
      );

      verify(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any<dynamic>(named: 'reason'),
          information: any<List<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).called(2);
    });
  });

  group('Bounded dedup set', () {
    test('evicts oldest entry when max capacity is exceeded', () async {
      final error = Exception('test');
      final stackTrace = StackTrace.current;

      // Fill the dedup set to max capacity
      for (var i = 0; i < CrashlyticsFailureReporter.maxNonFatalDedupEntries; i++) {
        await reporter.recordFailure(
          error: error,
          stackTrace: stackTrace,
          uniqueIdentifier: 'id-$i',
          fatal: false,
          reason: null,
          information: const [],
        );
      }

      // Add one more to trigger eviction of id-0
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'overflow-id',
        fatal: false,
        reason: null,
        information: const [],
      );

      // Reset the mock call count
      reset(mockCrashlytics);
      when(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any<dynamic>(named: 'reason'),
          information: any<List<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});

      // The oldest entry (id-0) should have been evicted,
      // so reporting it again should succeed
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'id-0',
        fatal: false,
        reason: null,
        information: const [],
      );

      verify(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any<dynamic>(named: 'reason'),
          information: any<List<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).called(1);
    });

    test('recent entries are retained when oldest is evicted', () async {
      final error = Exception('test');
      final stackTrace = StackTrace.current;

      // Fill to capacity
      for (var i = 0; i < CrashlyticsFailureReporter.maxNonFatalDedupEntries; i++) {
        await reporter.recordFailure(
          error: error,
          stackTrace: stackTrace,
          uniqueIdentifier: 'id-$i',
          fatal: false,
          reason: null,
          information: const [],
        );
      }

      // Add one more to trigger eviction of id-0
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'new-id',
        fatal: false,
        reason: null,
        information: const [],
      );

      // Reset mock
      reset(mockCrashlytics);
      when(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any<dynamic>(named: 'reason'),
          information: any<List<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});

      // id-1 should still be in the set (not evicted), so this should be skipped
      await reporter.recordFailure(
        error: error,
        stackTrace: stackTrace,
        uniqueIdentifier: 'id-1',
        fatal: false,
        reason: null,
        information: const [],
      );

      verifyNever(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any<dynamic>(named: 'reason'),
          information: any<List<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      );
    });
  });
}
