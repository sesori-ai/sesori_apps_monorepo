import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockSessionService extends Mock implements SessionService {}

class MockConnectionService extends Mock implements ConnectionService {}

void main() {
  const testSessionId = "test-session-123";

  late MockSessionService mockService;
  late MockConnectionService mockConnectionService;
  late StreamController<SesoriSessionEvent> sseController;

  const sampleDiff = FileDiff(
    file: "lib/main.dart",
    before: "",
    after: "void main() {}",
    additions: 1,
    deletions: 0,
  );

  setUp(() {
    mockService = MockSessionService();
    mockConnectionService = MockConnectionService();
    sseController = StreamController<SesoriSessionEvent>.broadcast();
    when(() => mockConnectionService.sessionEvents(any())).thenAnswer((_) => sseController.stream);
  });

  tearDown(() async {
    await sseController.close();
  });

  // ---------------------------------------------------------------------------
  // Init: loading → loaded
  // ---------------------------------------------------------------------------

  blocTest<DiffCubit, DiffState>(
    "init: emits loaded with session-level diffs",
    setUp: () {
      when(() => mockService.getSessionDiffs(testSessionId)).thenAnswer((_) async => ApiResponse.success([sampleDiff]));
    },
    build: () => DiffCubit(
      service: mockService,
      connectionService: mockConnectionService,
      sessionId: testSessionId,
    ),
    expect: () => [
      const DiffState.loaded(
        files: [sampleDiff],
        hasNewChanges: false,
      ),
    ],
    verify: (_) {
      verify(() => mockService.getSessionDiffs(testSessionId)).called(1);
    },
  );

  // ---------------------------------------------------------------------------
  // Init: loading → failed
  // ---------------------------------------------------------------------------

  blocTest<DiffCubit, DiffState>(
    "init: emits failed when getSessionDiffs returns ErrorResponse",
    setUp: () {
      when(
        () => mockService.getSessionDiffs(testSessionId),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    },
    build: () => DiffCubit(
      service: mockService,
      connectionService: mockConnectionService,
      sessionId: testSessionId,
    ),
    expect: () => [isA<DiffStateFailed>()],
  );

  blocTest<DiffCubit, DiffState>(
    "init: emits failed when getSessionDiffs throws",
    setUp: () {
      when(() => mockService.getSessionDiffs(testSessionId)).thenAnswer(
        (_) => Future<ApiResponse<List<FileDiff>>>.error(Exception("Network error")),
      );
    },
    build: () => DiffCubit(
      service: mockService,
      connectionService: mockConnectionService,
      sessionId: testSessionId,
    ),
    expect: () => [isA<DiffStateFailed>()],
  );

  // ---------------------------------------------------------------------------
  // SSE events
  // ---------------------------------------------------------------------------

  test("SSE sessionDiff event sets hasNewChanges to true", () async {
    when(() => mockService.getSessionDiffs(testSessionId)).thenAnswer((_) async => ApiResponse.success([sampleDiff]));

    final cubit = DiffCubit(
      service: mockService,
      connectionService: mockConnectionService,
      sessionId: testSessionId,
    );

    // Wait for async _init() to complete.
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<DiffStateLoaded>());
    expect((cubit.state as DiffStateLoaded).hasNewChanges, isFalse);

    // Fire a sessionDiff SSE event.
    sseController.add(
      const SesoriSseEvent.sessionDiff(sessionID: testSessionId, diff: []) as SesoriSessionDiff,
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<DiffStateLoaded>());
    expect((cubit.state as DiffStateLoaded).hasNewChanges, isTrue);

    await cubit.close();
  });

  // ---------------------------------------------------------------------------
  // refresh()
  // ---------------------------------------------------------------------------

  test("refresh() re-fetches diffs and clears hasNewChanges", () async {
    const updatedDiff = FileDiff(
      file: "lib/main.dart",
      before: "",
      after: "updated content",
      additions: 2,
      deletions: 0,
    );

    when(() => mockService.getSessionDiffs(testSessionId)).thenAnswer((_) async => ApiResponse.success([sampleDiff]));

    final cubit = DiffCubit(
      service: mockService,
      connectionService: mockConnectionService,
      sessionId: testSessionId,
    );

    await Future<void>.delayed(Duration.zero);

    // Set hasNewChanges via SSE event.
    sseController.add(
      const SesoriSseEvent.sessionDiff(sessionID: testSessionId, diff: []) as SesoriSessionDiff,
    );
    await Future<void>.delayed(Duration.zero);
    expect((cubit.state as DiffStateLoaded).hasNewChanges, isTrue);

    // Stub a fresh response for the refresh call.
    when(() => mockService.getSessionDiffs(testSessionId)).thenAnswer((_) async => ApiResponse.success([updatedDiff]));

    await cubit.refresh();

    final loaded = cubit.state as DiffStateLoaded;
    expect(loaded.hasNewChanges, isFalse);
    expect(loaded.files, [updatedDiff]);

    await cubit.close();
  });

  blocTest<DiffCubit, DiffState>(
    "refresh() from failed state re-initializes and loads successfully",
    setUp: () {
      var getSessionDiffsCallCount = 0;
      when(() => mockService.getSessionDiffs(testSessionId)).thenAnswer((_) async {
        getSessionDiffsCallCount += 1;
        if (getSessionDiffsCallCount == 1) {
          return ApiResponse.error(ApiError.generic());
        }
        return ApiResponse.success([sampleDiff]);
      });
    },
    build: () => DiffCubit(
      service: mockService,
      connectionService: mockConnectionService,
      sessionId: testSessionId,
    ),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      await cubit.refresh();
    },
    expect: () => [
      isA<DiffStateFailed>(),
      const DiffState.loading(),
      const DiffState.loaded(
        files: [sampleDiff],
        hasNewChanges: false,
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // close()
  // ---------------------------------------------------------------------------

  test("close() cancels SSE subscription", () async {
    when(() => mockService.getSessionDiffs(testSessionId)).thenAnswer((_) async => ApiResponse.success([sampleDiff]));

    final cubit = DiffCubit(
      service: mockService,
      connectionService: mockConnectionService,
      sessionId: testSessionId,
    );

    await Future<void>.delayed(Duration.zero);

    await cubit.close();

    // After close, the stream should have no listener (subscription cancelled).
    expect(sseController.hasListener, isFalse);
  });
}
