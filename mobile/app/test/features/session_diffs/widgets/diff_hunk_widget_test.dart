import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/utils/diff/diff_engine.dart";

import "package:sesori_mobile/features/session_diffs/models/diff_file_view_model.dart";
import "package:sesori_mobile/features/session_diffs/widgets/diff_hunk_widget.dart";
import "package:sesori_mobile/features/session_diffs/widgets/diff_line_widget.dart";

void main() {
  Widget buildTestWidget(DiffHunkViewModel viewModel) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiffHunkWidget(viewModel: viewModel),
        ),
      ),
    );
  }

  group("DiffHunkWidget", () {
    testWidgets("shows hunk header with @@ text", (tester) async {
      final vm = DiffHunkViewModel(
        hunk: const DiffHunk(
          oldStart: 10,
          oldCount: 5,
          newStart: 12,
          newCount: 7,
          lines: [],
        ),
        lines: [],
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("@@ -10,5 +12,7 @@"), findsOneWidget);
    });

    testWidgets("hunk header has light blue background", (tester) async {
      final vm = DiffHunkViewModel(
        hunk: const DiffHunk(
          oldStart: 1,
          oldCount: 3,
          newStart: 1,
          newCount: 3,
          lines: [],
        ),
        lines: [],
      );

      await tester.pumpWidget(buildTestWidget(vm));

      final headerContainer = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == const Color(0xFFF1F8FF),
      );
      expect(headerContainer, findsOneWidget);
    });

    testWidgets("renders all diff lines", (tester) async {
      final lines = [
        DiffLineViewModel(
          line: const DiffLine(
            type: DiffLineType.context,
            oldLineNumber: 1,
            newLineNumber: 1,
            content: "unchanged line",
          ),
        ),
        DiffLineViewModel(
          line: const DiffLine(
            type: DiffLineType.removed,
            oldLineNumber: 2,
            newLineNumber: null,
            content: "old code",
          ),
        ),
        DiffLineViewModel(
          line: const DiffLine(
            type: DiffLineType.added,
            oldLineNumber: null,
            newLineNumber: 2,
            content: "new code",
          ),
        ),
      ];

      final vm = DiffHunkViewModel(
        hunk: const DiffHunk(
          oldStart: 1,
          oldCount: 2,
          newStart: 1,
          newCount: 2,
          lines: [],
        ),
        lines: lines,
      );

      await tester.pumpWidget(buildTestWidget(vm));

      // All 3 DiffLineWidgets should be rendered
      expect(find.byType(DiffLineWidget), findsNWidgets(3));
    });

    testWidgets("renders line content within hunk", (tester) async {
      final lines = [
        DiffLineViewModel(
          line: const DiffLine(
            type: DiffLineType.added,
            oldLineNumber: null,
            newLineNumber: 1,
            content: "print('hello');",
          ),
        ),
      ];

      final vm = DiffHunkViewModel(
        hunk: const DiffHunk(
          oldStart: 0,
          oldCount: 0,
          newStart: 1,
          newCount: 1,
          lines: [],
        ),
        lines: lines,
      );

      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("print('hello');"), findsOneWidget);
    });

    testWidgets("header uses monospace font", (tester) async {
      final vm = DiffHunkViewModel(
        hunk: const DiffHunk(
          oldStart: 1,
          oldCount: 1,
          newStart: 1,
          newCount: 1,
          lines: [],
        ),
        lines: [],
      );

      await tester.pumpWidget(buildTestWidget(vm));

      final headerText = tester.widget<Text>(
        find.text("@@ -1,1 +1,1 @@"),
      );
      expect(headerText.style?.fontFamily, "monospace");
    });
  });
}
