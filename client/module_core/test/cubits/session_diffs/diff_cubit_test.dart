import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/session_diffs/diff_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_diffs/diff_state.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_preference.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/services/models/product_analytics_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("DiffCubit", () {
    late MockSessionRepository mockSessionRepository;
    late MockConnectionService mockConnectionService;
    late MockProductAnalyticsService mockProductAnalyticsService;
    late StreamController<SesoriSessionEvent> sessionEvents;
    const sessionId = "session-1";

    setUp(() {
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      mockProductAnalyticsService = stubbedProductAnalyticsService();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      when(() => mockConnectionService.sessionEvents(sessionId)).thenAnswer((_) => sessionEvents.stream);
    });

    tearDown(() async {
      await sessionEvents.close();
    });

    DiffCubit buildCubit() => DiffCubit(
      sessionRepository: mockSessionRepository,
      connectionService: mockConnectionService,
      productAnalyticsService: mockProductAnalyticsService,
      sessionId: sessionId,
    );

    FileDiff testFileDiff({String? file}) => FileDiff.content(
      file: file ?? "lib/src/foo.dart",
      before: "class Foo {}",
      after: "class Foo { int x = 0; }",
      additions: 1,
      deletions: 0,
      status: FileDiffStatus.modified,
    );

    test("reports each successful empty and non-empty diff classification once", () async {
      var diffs = const <FileDiff>[];
      when(
        () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
      ).thenAnswer((_) async => ApiResponse.success(SessionDiffsResponse(diffs: diffs)));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      diffs = [testFileDiff()];
      await cubit.refresh();
      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      final events = verify(
        () => mockProductAnalyticsService.logEvent(
          event: captureAny(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).captured.cast<ProductAnalyticsEvent>();
      expect(events, [
        const ProductAnalyticsEvent.sessionDiffViewed(changeState: AnalyticsChangeState.empty),
        const ProductAnalyticsEvent.sessionDiffViewed(changeState: AnalyticsChangeState.nonEmpty),
      ]);
    });

    test("a deferred non-empty diff consumes the cubit lifetime guard", () async {
      when(
        () => mockProductAnalyticsService.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).thenAnswer((_) async => AnalyticsDeliveryResult.deferredUntilPreference);
      when(
        () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
      ).thenAnswer((_) async => ApiResponse.success(SessionDiffsResponse(diffs: [testFileDiff()])));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionDiffViewed(
            changeState: AnalyticsChangeState.nonEmpty,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).called(1);
    });

    test("an empty diff retries when its pre-activation delivery settles after the active edge", () async {
      final analyticsStates = BehaviorSubject<ProductAnalyticsState>.seeded(ProductAnalyticsState.initial);
      addTearDown(analyticsStates.close);
      when(() => mockProductAnalyticsService.state).thenAnswer((_) => analyticsStates.value);
      when(() => mockProductAnalyticsService.stateStream).thenAnswer((_) => analyticsStates.stream);
      final firstDelivery = Completer<AnalyticsDeliveryResult>();
      var deliveryCount = 0;
      when(
        () => mockProductAnalyticsService.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).thenAnswer((_) {
        deliveryCount++;
        return deliveryCount == 1 ? firstDelivery.future : Future.value(AnalyticsDeliveryResult.acceptedBySdk);
      });
      when(
        () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
      ).thenAnswer((_) async => ApiResponse.success(const SessionDiffsResponse(diffs: <FileDiff>[])));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await untilCalled(
        () => mockProductAnalyticsService.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );

      analyticsStates.add(
        const ProductAnalyticsState(
          preference: ProductAnalyticsPreferenceKnown(
            preference: ProductAnalyticsPreference.enabled,
          ),
          synchronization: ProductAnalyticsSynchronized(),
          availability: ProductAnalyticsActive(),
        ),
      );
      firstDelivery.complete(AnalyticsDeliveryResult.failed);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockProductAnalyticsService.logEvent(
          event: const ProductAnalyticsEvent.sessionDiffViewed(
            changeState: AnalyticsChangeState.empty,
          ),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).called(2);
    });

    // -------------------------------------------------------------------------
    // 1. init → loading → loaded
    // -------------------------------------------------------------------------

    blocTest<DiffCubit, DiffState>(
      "constructor: emits DiffStateLoaded with files after successful fetch",
      build: () {
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.success(SessionDiffsResponse(diffs: [testFileDiff()])));
        return buildCubit();
      },
      expect: () => [
        isA<DiffStateLoaded>().having((s) => s.files.length, "files count", 1),
      ],
    );

    // -------------------------------------------------------------------------
    // 2. init → loading → failed (error response)
    // -------------------------------------------------------------------------

    blocTest<DiffCubit, DiffState>(
      "constructor: emits DiffStateFailed when API returns error",
      build: () {
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      expect: () => [isA<DiffStateFailed>()],
    );

    // -------------------------------------------------------------------------
    // 3. init → loading → failed (exception thrown)
    // -------------------------------------------------------------------------

    blocTest<DiffCubit, DiffState>(
      "constructor: emits DiffStateFailed when service throws",
      build: () {
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer((_) => Future.error(Exception("network error")));
        return buildCubit();
      },
      expect: () => [isA<DiffStateFailed>()],
    );

    // -------------------------------------------------------------------------
    // 4. empty diffs → loaded with empty list
    // -------------------------------------------------------------------------

    blocTest<DiffCubit, DiffState>(
      "constructor: emits DiffStateLoaded with empty list when no diffs",
      build: () {
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.success(const SessionDiffsResponse(diffs: [])));
        return buildCubit();
      },
      expect: () => [
        isA<DiffStateLoaded>().having((s) => s.files, "files", isEmpty),
      ],
    );

    // -------------------------------------------------------------------------
    // 5. refresh() → re-fetches and emits loading then loaded
    // -------------------------------------------------------------------------

    blocTest<DiffCubit, DiffState>(
      "refresh: emits loading then loaded with fresh data",
      build: () {
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.success(SessionDiffsResponse(diffs: [testFileDiff()])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionDiffsResponse(
              diffs: [
                testFileDiff(file: "lib/src/bar.dart"),
                testFileDiff(file: "lib/src/baz.dart"),
              ],
            ),
          ),
        );
        await cubit.refresh();
      },
      skip: 1, // skip initial loaded emission
      expect: () => [
        isA<DiffStateLoading>(),
        isA<DiffStateLoaded>().having((s) => s.files.length, "refreshed files count", 2),
      ],
    );

    // -------------------------------------------------------------------------
    // 6. refresh() after failure → re-fetches
    // -------------------------------------------------------------------------

    blocTest<DiffCubit, DiffState>(
      "refresh: re-fetches after failure and emits loaded on success",
      build: () {
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.success(SessionDiffsResponse(diffs: [testFileDiff()])));
        await cubit.refresh();
      },
      skip: 1, // skip initial failed emission
      expect: () => [
        isA<DiffStateLoading>(),
        isA<DiffStateLoaded>().having((s) => s.files.length, "files after retry", 1),
      ],
    );

    // -------------------------------------------------------------------------
    // 7. session.diff SSE → silent refresh
    // -------------------------------------------------------------------------

    blocTest<DiffCubit, DiffState>(
      "session.diff SSE: silently re-fetches diffs",
      build: () {
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer((_) async => ApiResponse.success(SessionDiffsResponse(diffs: [testFileDiff()])));
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockSessionRepository.getSessionDiffs(sessionId: sessionId),
        ).thenAnswer(
          (_) async => ApiResponse.success(
            SessionDiffsResponse(
              diffs: [
                testFileDiff(file: "lib/src/new.dart"),
              ],
            ),
          ),
        );
        sessionEvents.add(const SesoriSessionDiff(sessionID: sessionId));
        await Future<void>.delayed(Duration.zero);
      },
      skip: 1,
      expect: () => [
        isA<DiffStateLoaded>().having((s) => s.files.single.file, "refreshed file", "lib/src/new.dart"),
      ],
    );

    blocTest<DiffCubit, DiffState>(
      "session.diff SSE burst: serializes refreshes and keeps latest result",
      build: () {
        var requestCount = 0;
        when(() => mockSessionRepository.getSessionDiffs(sessionId: sessionId)).thenAnswer((_) async {
          requestCount++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return ApiResponse.success(
            SessionDiffsResponse(
              diffs: [
                testFileDiff(file: "lib/src/request-$requestCount.dart"),
              ],
            ),
          );
        });
        return buildCubit();
      },
      act: (cubit) async {
        await Future<void>.delayed(Duration.zero);
        sessionEvents.add(const SesoriSessionDiff(sessionID: sessionId));
        sessionEvents.add(const SesoriSessionDiff(sessionID: sessionId));
        sessionEvents.add(const SesoriSessionDiff(sessionID: sessionId));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      skip: 1,
      verify: (cubit) {
        expect(
          cubit.state,
          isA<DiffStateLoaded>().having(
            (state) => state.files.single.file,
            "latest refresh wins",
            "lib/src/request-4.dart",
          ),
        );
      },
    );
  });
}
