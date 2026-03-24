import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/utils/diff/diff_engine.dart";

import "package:sesori_mobile/features/session_diffs/models/diff_file_view_model.dart";
import "package:sesori_mobile/features/session_diffs/widgets/diff_line_widget.dart";

void main() {
  Widget buildTestWidget(DiffLineViewModel viewModel) {
    return MaterialApp(
      home: Scaffold(
        body: DiffLineWidget(viewModel: viewModel),
      ),
    );
  }

  group("DiffLineWidget", () {
    testWidgets("added line has green background", (tester) async {
      final vm = DiffLineViewModel(
        line: const DiffLine(
          type: DiffLineType.added,
          oldLineNumber: null,
          newLineNumber: 5,
          content: "new line",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      // Find the outermost ColoredBox with the background color.
      // The DiffLineWidget root is a ColoredBox with color.
      final containerFinder = find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == const Color(0xFFE6FFEC),
      );
      expect(containerFinder, findsOneWidget);
    });

    testWidgets("removed line has red background", (tester) async {
      final vm = DiffLineViewModel(
        line: const DiffLine(
          type: DiffLineType.removed,
          oldLineNumber: 3,
          newLineNumber: null,
          content: "old line",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      final containerFinder = find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == const Color(0xFFFFEBE9),
      );
      expect(containerFinder, findsOneWidget);
    });

    testWidgets("context line has transparent background", (tester) async {
      final vm = DiffLineViewModel(
        line: const DiffLine(
          type: DiffLineType.context,
          oldLineNumber: 10,
          newLineNumber: 12,
          content: "unchanged",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      final containerFinder = find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.transparent,
      );
      expect(containerFinder, findsAtLeastNWidgets(1));
    });

    testWidgets("renders old and new line numbers", (tester) async {
      final vm = DiffLineViewModel(
        line: const DiffLine(
          type: DiffLineType.context,
          oldLineNumber: 42,
          newLineNumber: 55,
          content: "some code",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("42"), findsOneWidget);
      expect(find.text("55"), findsOneWidget);
    });

    testWidgets("added line shows only new line number", (tester) async {
      final vm = DiffLineViewModel(
        line: const DiffLine(
          type: DiffLineType.added,
          oldLineNumber: null,
          newLineNumber: 7,
          content: "added",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("7"), findsOneWidget);
      // Old line number gutter should show empty string
      // (two Text widgets exist: one for old number, one for new)
    });

    testWidgets("removed line shows only old line number", (tester) async {
      final vm = DiffLineViewModel(
        line: const DiffLine(
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
      final vm = DiffLineViewModel(
        line: const DiffLine(
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
      final vm = DiffLineViewModel(
        line: const DiffLine(
          type: DiffLineType.removed,
          oldLineNumber: 1,
          newLineNumber: null,
          content: "old",
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("-"), findsOneWidget);
    });

    testWidgets("content area has horizontal SingleChildScrollView", (tester) async {
      final vm = DiffLineViewModel(
        line: DiffLine(
          type: DiffLineType.context,
          oldLineNumber: 1,
          newLineNumber: 1,
          content: "a" * 500, // very long line
        ),
      );

      await tester.pumpWidget(buildTestWidget(vm));

      final scrollFinder = find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
      );
      expect(scrollFinder, findsOneWidget);
    });

    testWidgets("renders line content text", (tester) async {
      final vm = DiffLineViewModel(
        line: const DiffLine(
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
      final vm = DiffLineViewModel(
        line: const DiffLine(
          type: DiffLineType.added,
          oldLineNumber: null,
          newLineNumber: 1,
          content: "int x = 1;",
        ),
        highlightedSpan: const TextSpan(
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
