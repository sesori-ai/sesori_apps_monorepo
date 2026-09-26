import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_diffs/widgets/diff_line_widget.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockDiffCubit() extends MockCubit<DiffState> implements DiffCubit;

void main() {
  testWidgets("loaded source lines share one selection area while gutters stay isolated", (tester) async {
    final cubit = _MockDiffCubit();
    whenListen(
      cubit,
      const Stream<DiffState>.empty(),
      initialState: const DiffState.loaded(
        files: <FileDiff>[
          FileDiff.content(
            file: "notes.txt",
            before: "old source",
            after: "first source\nsecond source",
            additions: 2,
            deletions: 1,
            status: FileDiffStatus.modified,
          ),
        ],
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<DiffCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SessionDiffsView(chrome: SessionDiffsGlassBar(onBack: null, banner: null)),
        ),
      ),
    );

    // Diff view models are built on a real compute isolate, so alternate real
    // event-loop time with test-frame pumps until the loaded lines mount.
    for (var attempt = 0; attempt < 20 && find.text("second source").evaluate().isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    final firstSource = find.text("first source");
    final secondSource = find.text("second source");
    expect(firstSource, findsOneWidget);
    expect(secondSource, findsOneWidget);

    final firstSelectionArea = find.ancestor(of: firstSource, matching: find.byType(SelectionArea)).evaluate().single;
    final secondSelectionArea = find.ancestor(of: secondSource, matching: find.byType(SelectionArea)).evaluate().single;
    expect(identical(firstSelectionArea, secondSelectionArea), isTrue);

    final selectionDisabled = find.byWidgetPredicate(
      (widget) => widget is SelectionContainer && widget.delegate == null,
    );
    final titleElements = find.text("File changes").evaluate().toList(growable: false);
    expect(titleElements, isNotEmpty);
    for (final titleElement in titleElements) {
      expect(
        find.ancestor(
          of: find.byElementPredicate((element) => identical(element, titleElement)),
          matching: selectionDisabled,
        ),
        findsOneWidget,
        reason: "every rendered navigation title should stay outside copied source",
      );
    }
    expect(
      find.ancestor(of: find.text("notes.txt"), matching: selectionDisabled),
      findsOneWidget,
      reason: "per-file header metadata should stay outside copied source",
    );

    final firstLine = find.ancestor(of: firstSource, matching: find.byType(DiffLineWidget));
    expect(firstLine, findsOneWidget);
    expect(
      find.descendant(
        of: firstLine,
        matching: selectionDisabled,
      ),
      findsNWidgets(2),
      reason: "line-number and +/- gutters should each disable selection",
    );
  });
  testWidgets("the split shows the selected file's diff beside the list", (tester) async {
    final cubit = _MockDiffCubit();
    whenListen(
      cubit,
      const Stream<DiffState>.empty(),
      // A decoded response's list, like the cubit's: freezed rewraps a plain
      // list on every read, which the view would take for new files.
      initialState: DiffState.loaded(
        files: const SessionDiffsResponse(
          diffs: <FileDiff>[
            FileDiff.content(
              file: "docs/a.txt",
              before: "",
              after: "alpha line",
              additions: 1,
              deletions: 0,
              status: FileDiffStatus.added,
            ),
            FileDiff.content(
              file: "docs/b.txt",
              before: "",
              after: "beta line",
              additions: 1,
              deletions: 0,
              status: FileDiffStatus.added,
            ),
          ],
        ).diffs,
      ),
    );
    addTearDown(cubit.close);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BlocProvider<DiffCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SessionDiffsView(
            chrome: SessionDiffsSplit(
              headerBuilder: ({required context, required title, required summary}) => Text("$title | $summary"),
            ),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 20 && find.text("alpha line").evaluate().isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(find.text("File changes | 2 files changed  +2"), findsOneWidget);
    expect(find.text("alpha line"), findsOneWidget);
    expect(find.text("beta line"), findsNothing);

    await tester.tap(find.byKey(const ValueKey("diff-file-list-1")));
    await tester.pump();

    expect(find.text("alpha line"), findsNothing);
    expect(find.text("beta line"), findsOneWidget);
    expect(find.text("docs/b.txt"), findsOneWidget);
  });
}
