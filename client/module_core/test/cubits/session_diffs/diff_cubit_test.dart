import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/session_diffs/diff_cubit.dart";
import "package:sesori_dart_core/src/cubits/session_diffs/diff_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("DiffCubit", () {
    late MockSessionRepository mockSessionRepository;
    late MockConnectionService mockConnectionService;
    late StreamController<SesoriSessionEvent> sessionEvents;
    const sessionId = "session-1";

    setUp(() {
      mockSessionRepository = MockSessionRepository();
      mockConnectionService = MockConnectionService();
      sessionEvents = StreamController<SesoriSessionEvent>.broadcast();
      when(() => mockConnectionService.sessionEvents(sessionId)).thenAnswer((_) => sessionEvents.stream);
    });

    tearDown(() async {
      await sessionEvents.close();
    });

    DiffCubit buildCubit() => DiffCubit(
      sessionRepository: mockSessionRepository,
      connectionService: mockConnectionService,
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
