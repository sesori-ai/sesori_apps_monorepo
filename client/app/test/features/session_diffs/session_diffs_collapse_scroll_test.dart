import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart" show ApiResponse;
import "package:sesori_dart_core/sesori_dart_core.dart" show ConnectionOverlayCubit, DiffCubit, DiffState;
import "package:sesori_dart_core/sesori_dart_core.dart" show SessionRepository;
import "package:sesori_mobile/features/session_diffs/session_diffs_body.dart";
import "package:sesori_mobile/features/session_diffs/session_diffs_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class _MockDiffCubit extends MockCubit<DiffState> implements DiffCubit {}

class _MockSessionRepository extends Mock implements SessionRepository {}

FileDiff _makeDiff(String file, {required int lineCount}) {
  final before = List<String>.filled(lineCount, "old line").join("\n");
  final after = List<String>.filled(lineCount, "new line").join("\n");
  return FileDiff.content(
    file: "lib/$file",
    before: before,
    after: after,
    additions: lineCount,
    deletions: lineCount,
    status: FileDiffStatus.modified,
  );
}

/// Builds the screen and waits for the async cubit load + the
/// [DiffViewModelBuilder] compute() isolate to complete.
///
/// `DiffViewModelBuilder.build()` uses `compute()`, which spawns a real
/// isolate that the test clock does not control. We therefore run the
/// initial-load wait inside [WidgetTester.runAsync] so the isolate can
/// finish, then pump a series of frames so the widget rebuilds with the
/// computed view models. We avoid [WidgetTester.pumpAndSettle] here
/// because the isolate communication leaves a pending microtask that the
/// fake-async clock can never resolve on its own.
Future<void> _pumpLoadedScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    BlocProvider<ConnectionOverlayCubit>(
      create: (_) => StubConnectionOverlayCubit(),
      child: MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SessionDiffsScreen(projectId: "project-1", sessionId: "session-1"),
      ),
    ),
  );

  // Let the cubit's async fetch and the view-model builder's compute()
  // isolate complete in real time. We alternate between runAsync (to let
  // the isolate's real-time message round-trip happen) and pump (to let
  // the fake-async clock process the resulting setState rebuild).
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  // Sanity: the diff viewer should have rendered a CustomScrollView by now.
  expect(find.byType(CustomScrollView), findsOneWidget, reason: "diff viewer did not finish loading");
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  late _MockSessionRepository mockRepo;

  setUp(() async {
    final getIt = GetIt.instance;
    await getIt.reset();
    mockRepo = _MockSessionRepository();
    getIt.registerSingleton<SessionRepository>(mockRepo);
  });

  testWidgets(
    "collapsing an expanded file whose header is pinned at the top keeps that header pinned",
    (tester) async {
      // Three files: a large one (aaa) whose body we'll scroll into, a small
      // one (bbb), and a trailing one (ccc) to ensure we don't accidentally
      // land past the end of the list. After collapsing aaa while its header
      // is pinned, aaa's header should stay at the top so both aaa and bbb
      // remain visible.
      when(() => mockRepo.getSessionDiffs(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => ApiResponse.success(
          SessionDiffsResponse(
            diffs: [
              _makeDiff("aaa.dart", lineCount: 10),
              _makeDiff("bbb.dart", lineCount: 2),
              _makeDiff("ccc.dart", lineCount: 10),
            ],
          ),
        ),
      );

      await _pumpLoadedScreen(tester);

      final scrollFinder = find.byType(CustomScrollView);
      expect(scrollFinder, findsOneWidget);

      // Scroll a little into the first file's body so aaa's header is
      // pinned at the top of the viewport (we've scrolled past its natural
      // position) and bbb's header is below it. PregoGlassScaffold adds a
      // collapsing large title (~80px) above the file list, so the drag must
      // clear that before it reaches aaa's body — pinned headers then clamp at
      // the viewport top regardless of any extra scroll.
      await tester.drag(scrollFinder, const Offset(0, -130));
      await tester.pumpAndSettle();

      final aaaHeader = find.text("aaa.dart");
      expect(aaaHeader, findsOneWidget);

      final scrollRectBefore = tester.getRect(scrollFinder);
      final aaaRectBefore = tester.getRect(aaaHeader);
      expect(
        aaaRectBefore.top,
        closeTo(scrollRectBefore.top, 10.0),
        reason: "precondition: aaa's header should be pinned at the top of the viewport before the collapse",
      );

      final bbbHeader = find.text("bbb.dart");
      final bbbRectBefore = tester.getRect(bbbHeader);
      expect(
        bbbRectBefore.top,
        greaterThan(scrollRectBefore.top + 10),
        reason: "precondition: bbb's header should be below the viewport top before the collapse",
      );

      // Collapse the first file by tapping its header.
      await tester.tap(aaaHeader);
      await tester.pumpAndSettle();

      final scrollRectAfter = tester.getRect(scrollFinder);
      final aaaRectAfter = tester.getRect(aaaHeader);
      // The [DiffFileWidget] has `EdgeInsets.symmetric(vertical: 6)` so the
      // file-name text sits a few pixels below the header's top edge. The
      // 10px tolerance covers that padding plus any sub-pixel rounding from
      // the SliverPersistentHeader layout.
      expect(
        aaaRectAfter.top,
        closeTo(scrollRectAfter.top, 10.0),
        reason: "aaa's header should stay pinned at the top of the scroll viewport after the collapse",
      );
    },
  );

  testWidgets(
    "collapsing a file whose header is NOT pinned at the top does not jump the viewport",
    (tester) async {
      // aaa is large enough that we can scroll past it; bbb is also large
      // so that scrolling deep into the list pushes aaa's header off the
      // pinned position and bbb's header takes over.
      when(() => mockRepo.getSessionDiffs(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => ApiResponse.success(
          SessionDiffsResponse(diffs: [
            _makeDiff("aaa.dart", lineCount: 30),
            _makeDiff("bbb.dart", lineCount: 30),
            _makeDiff("ccc.dart", lineCount: 10),
          ]),
        ),
      );

      await _pumpLoadedScreen(tester);

      final scrollFinder = find.byType(CustomScrollView);
      // Scroll deep into the list so that aaa's header is above the
      // viewport and bbb's header is pinned at the top instead.
      await tester.drag(scrollFinder, const Offset(0, -700));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      final positionBefore = scrollable.position.pixels;

      // Collapse aaa — its header is NOT pinned at the top, so the viewport
      // should not jump to a new file's header.
      await tester.tap(find.text("aaa.dart"));
      await tester.pumpAndSettle();

      final positionAfter = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
      // The viewport should not have scrolled forward to align with a new
      // file's header. It may have clamped down (if collapsing aaa's body
      // reduced the total content height and the old offset exceeded the
      // new maxScrollExtent), but it should never have increased.
      expect(
        positionAfter,
        lessThanOrEqualTo(positionBefore),
        reason: "collapsing a non-pinned header must not scroll the viewport forward",
      );
    },
  );

  testWidgets("collapsing the last file leaves the viewport anchored to the end of the list", (tester) async {
    when(() => mockRepo.getSessionDiffs(sessionId: any(named: "sessionId"))).thenAnswer(
      (_) async => ApiResponse.success(
        SessionDiffsResponse(
          diffs: [
            _makeDiff("aaa.dart", lineCount: 10),
            _makeDiff("bbb.dart", lineCount: 2),
          ],
        ),
      ),
    );

    await _pumpLoadedScreen(tester);

    final scrollFinder = find.byType(CustomScrollView);
    // Scroll past aaa.dart so bbb.dart's header is in the viewport.
    await tester.drag(scrollFinder, const Offset(0, -200));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final positionBefore = scrollable.position.pixels;

    // Collapse the LAST file — there is no "next file" to anchor to, so
    // the scroll offset should not jump to a new file's header.
    await tester.tap(find.text("bbb.dart"));
    await tester.pumpAndSettle();

    final positionAfter = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    // Collapsing the last file removes content above the viewport. The
    // viewport may either stay at the same pixel offset or clamp to the
    // new maxScrollExtent — both are acceptable as long as we did not
    // jump to a new file's header.
    expect(positionAfter, lessThanOrEqualTo(positionBefore));
  });

  testWidgets(
    "theme brightness change recomputes diff view models",
    (tester) async {
      final mockCubit = _MockDiffCubit();
      when(() => mockCubit.state).thenReturn(
        DiffState.loaded(files: [_makeDiff("aaa.dart", lineCount: 2)]),
      );
      when(() => mockCubit.stream).thenAnswer(
        (_) => Stream.value(DiffState.loaded(files: [_makeDiff("aaa.dart", lineCount: 2)])),
      );

      final bodyKey = GlobalKey();

      await tester.pumpWidget(
        BlocProvider<ConnectionOverlayCubit>(
          create: (_) => StubConnectionOverlayCubit(),
          child: MaterialApp(
            theme: ThemeData(
              brightness: tester.platformDispatcher.platformBrightness,
              extensions: [PregoDesignSystem.light],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<DiffCubit>.value(
              value: mockCubit,
              child: SessionDiffsBody(key: bodyKey),
            ),
          ),
        ),
      );

      // Wait for the initial microtask-based computation to start and finish.
      // DiffViewModelBuilder.build uses compute() which spawns a real isolate,
      // so we alternate runAsync (real time) and pump (fake-async rebuild).
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
      }

      // Sanity: the diff viewer should have rendered after initial compute.
      expect(find.byType(CustomScrollView), findsOneWidget);

      final stateBefore = tester.state(find.byType(SessionDiffsBody));
      final initialRecomputeCount = (stateBefore as dynamic).recomputeCount as int;

      // Change platform brightness — this triggers didChangeDependencies on
      // any widget that read Theme.of(context).brightness.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();

      final stateAfter = tester.state(find.byType(SessionDiffsBody));
      final recomputeAfter = (stateAfter as dynamic).recomputeCount as int;

      // Restore brightness so the change does not leak to other tests.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;

      // With the fix, brightness mismatch triggers recomputation (new token).
      // Without the fix, _didInit blocks didChangeDependencies from calling
      // _maybeComputeViewModels, so the token stays the same.
      expect(recomputeAfter, greaterThan(initialRecomputeCount));
    },
  );
}
