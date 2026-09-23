import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_diffs/models/diff_file_view_model.dart";
import "package:sesori_app_ui/src/features/session_diffs/widgets/diff_line_widget.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Widget buildTestWidget(DiffLineViewModel viewModel) {
    return MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.light),
      home: Scaffold(
        body: DiffLineWidget(viewModel: viewModel),
      ),
    );
  }

  group("DiffLineWidget", () {
    for (final brightness in Brightness.values) {
      testWidgets("rows take a 10% status tint and a 2pt status bar in ${brightness.name}", (tester) async {
        final colors = buildPregoThemeData(brightness: brightness).extension<PregoDesignSystem>()?.colors;
        if (colors == null) fail("Prego design system missing");

        for (final (type, tint, bar) in [
          (DiffLineType.added, colors.fgSuccessPrimary.withValues(alpha: 0.1), colors.fgSuccessPrimary),
          (DiffLineType.removed, colors.fgErrorPrimary.withValues(alpha: 0.1), colors.fgErrorPrimary),
          (DiffLineType.context, Colors.transparent, Colors.transparent),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildPregoThemeData(brightness: brightness),
              home: Scaffold(
                body: DiffLineWidget(
                  viewModel: DiffLineViewModel(
                    line: DiffLine(type: type, oldLineNumber: 1, newLineNumber: 1, content: "line"),
                  ),
                ),
              ),
            ),
          );

          final decoration = tester
              .widget<DecoratedBox>(
                find.descendant(of: find.byType(DiffLineWidget), matching: find.byType(DecoratedBox)).first,
              )
              .decoration;
          expect(decoration, isA<BoxDecoration>(), reason: type.name);
          if (decoration is! BoxDecoration) return;
          expect(decoration.color, tint, reason: type.name);
          expect(
            decoration.border,
            BorderDirectional(start: BorderSide(color: bar, width: 2)),
            reason: type.name,
          );
        }
      });
    }

    testWidgets("renders single line number for context line", (tester) async {
      const vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.context,
          oldLineNumber: 42,
          newLineNumber: 55,
          content: "some code",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("42"), findsNothing);
      expect(find.text("55"), findsOneWidget);
    });

    testWidgets("added line shows only new line number", (tester) async {
      const vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.added,
          oldLineNumber: null,
          newLineNumber: 7,
          content: "added",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("7"), findsOneWidget);
    });

    testWidgets("removed line shows only old line number", (tester) async {
      const vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.removed,
          oldLineNumber: 3,
          newLineNumber: null,
          content: "removed",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("3"), findsOneWidget);
    });

    testWidgets("shows + prefix for added line", (tester) async {
      const vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.added,
          oldLineNumber: null,
          newLineNumber: 1,
          content: "new",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("+"), findsOneWidget);
    });

    testWidgets("shows - prefix for removed line", (tester) async {
      const vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.removed,
          oldLineNumber: 1,
          newLineNumber: null,
          content: "old",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("-"), findsOneWidget);
    });

    testWidgets("long content wraps instead of scrolling horizontally", (tester) async {
      final vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.context,
          oldLineNumber: 1,
          newLineNumber: 1,
          content: "a" * 500,
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      final scrollFinder = find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
      );
      expect(scrollFinder, findsNothing);
    });

    testWidgets("does not isolate content in a per-line selection area", (tester) async {
      const vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.context,
          oldLineNumber: 1,
          newLineNumber: 1,
          content: "selectable source",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(
        find.ancestor(of: find.text("selectable source"), matching: find.byType(SelectionArea)),
        findsNothing,
      );
    });

    testWidgets("renders line content text", (tester) async {
      const vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.context,
          oldLineNumber: 1,
          newLineNumber: 1,
          content: "final x = 42;",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("final x = 42;"), findsOneWidget);
    });

    testWidgets("renders highlightedSpan when provided", (tester) async {
      const vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.added,
          oldLineNumber: null,
          newLineNumber: 1,
          content: "int x = 1;",
        ),
        highlightedSpan: TextSpan(
          children: [
            TextSpan(
              text: "int",
              style: TextStyle(color: Colors.blue),
            ),
            TextSpan(text: " x = 1;"),
          ],
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      // Text.rich is used instead of plain Text
      final richTextFinder = find.byWidgetPredicate(
        (widget) => widget is RichText,
      );
      expect(richTextFinder, findsAtLeastNWidgets(1));
    });
  });
}
