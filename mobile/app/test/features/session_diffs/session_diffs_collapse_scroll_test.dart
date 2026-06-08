import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart" show ApiResponse;
import "package:sesori_dart_core/sesori_dart_core.dart" show SessionRepository;
import "package:sesori_mobile/features/session_diffs/session_diffs_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../helpers/test_helpers.dart";

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
    MaterialApp(
      theme: ThemeData(extensions: [ZyraDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SessionDiffsScreen(projectId: "project-1", sessionId: "session-1"),
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
    "collapsing an expanded file jumps the viewport so the next file's header sits at the top",
    (tester) async {
      // Three files: a large one (aaa) whose body we'll scroll into, a small
      // one (bbb) that should become the new top after the collapse, and a
      // trailing one (ccc) to ensure we don't accidentally land past the
      // end of the list.
      when(() => mockRepo.getSessionDiffs(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => ApiResponse.success(
          SessionDiffsResponse(diffs: [
            _makeDiff("aaa.dart", lineCount: 10),
            _makeDiff("bbb.dart", lineCount: 2),
            _makeDiff("ccc.dart", lineCount: 10),
          ]),
        ),
      );

      await _pumpLoadedScreen(tester);

      final scrollFinder = find.byType(CustomScrollView);
      expect(scrollFinder, findsOneWidget);

      // Scroll a little into the first file's body so bbb's header is no
      // longer at the very top of the viewport.
      await tester.drag(scrollFinder, const Offset(0, -50));
      await tester.pumpAndSettle();

      final bbbHeader = find.text("bbb.dart");
      expect(bbbHeader, findsOneWidget);

      final scrollRectBefore = tester.getRect(scrollFinder);
      final bbbRectBefore = tester.getRect(bbbHeader);
      expect(
        bbbRectBefore.top,
        greaterThan(scrollRectBefore.top + 10),
        reason: "precondition: bbb's header should be below the viewport top before the collapse",
      );

      // Collapse the first file by tapping its header.
      await tester.tap(find.text("aaa.dart"));
      await tester.pumpAndSettle();

      final scrollRectAfter = tester.getRect(scrollFinder);
      final bbbRectAfter = tester.getRect(bbbHeader);
      // The [DiffFileWidget] has `EdgeInsets.symmetric(vertical: 6)` so the
      // file-name text sits a few pixels below the header's top edge. The
      // 10px tolerance covers that padding plus any sub-pixel rounding from
      // the SliverPersistentHeader layout.
      expect(
        bbbRectAfter.top,
        closeTo(scrollRectAfter.top, 10.0),
        reason: "bbb's header should be aligned to the top of the scroll viewport after the collapse",
      );
    },
  );

  testWidgets(
    "collapsing the last file leaves the viewport anchored to the end of the list",
    (tester) async {
      when(() => mockRepo.getSessionDiffs(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => ApiResponse.success(
          SessionDiffsResponse(diffs: [
            _makeDiff("aaa.dart", lineCount: 10),
            _makeDiff("bbb.dart", lineCount: 2),
          ]),
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
    },
  );
}
