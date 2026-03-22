import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/utils/diff/diff_engine.dart";
import "package:sesori_shared/sesori_shared.dart";

import "package:sesori_mobile/features/session_diffs/models/diff_file_view_model.dart";
import "package:sesori_mobile/features/session_diffs/widgets/diff_file_widget.dart";
import "package:sesori_mobile/features/session_diffs/widgets/diff_hunk_widget.dart";

void main() {
  /// Helper to build a minimal [DiffFileViewModel] for testing.
  DiffFileViewModel buildVM({
    String fileName = "main.dart",
    int additions = 5,
    int deletions = 2,
    FileDiffStatus? status,
    bool isBinary = false,
    bool isExpanded = true,
    List<DiffHunkViewModel>? hunks,
  }) {
    return DiffFileViewModel(
      fileDiff: FileDiff(
        file: "lib/$fileName",
        before: "",
        after: "",
        additions: additions,
        deletions: deletions,
        status: status,
      ),
      fileName: fileName,
      hunks: hunks ?? [],
      additions: additions,
      deletions: deletions,
      status: status,
      isBinary: isBinary,
      isExpanded: isExpanded,
    );
  }

  Widget buildTestWidget(DiffFileViewModel viewModel) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiffFileWidget(viewModel: viewModel),
        ),
      ),
    );
  }

  group("DiffFileWidget", () {
    testWidgets("header shows file name", (tester) async {
      final vm = buildVM(fileName: "auth_service.dart");
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("auth_service.dart"), findsOneWidget);
    });

    testWidgets("header shows +N -M stats", (tester) async {
      final vm = buildVM(additions: 12, deletions: 3);
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("+12"), findsOneWidget);
      expect(find.text("-3"), findsOneWidget);
    });

    testWidgets('status badge shows "A" for added', (tester) async {
      final vm = buildVM(status: FileDiffStatus.added);
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("A"), findsOneWidget);
    });

    testWidgets('status badge shows "D" for deleted', (tester) async {
      final vm = buildVM(status: FileDiffStatus.deleted);
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("D"), findsOneWidget);
    });

    testWidgets('status badge shows "M" for modified', (tester) async {
      final vm = buildVM(status: FileDiffStatus.modified);
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("M"), findsOneWidget);
    });

    testWidgets('status badge shows "M" for null status', (tester) async {
      final vm = buildVM();
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("M"), findsOneWidget);
    });

    testWidgets("expanded by default — body visible", (tester) async {
      final hunks = [
        DiffHunkViewModel(
          hunk: const DiffHunk(
            oldStart: 1,
            oldCount: 1,
            newStart: 1,
            newCount: 2,
            lines: [],
          ),
          lines: [
            DiffLineViewModel(
              line: const DiffLine(
                type: DiffLineType.added,
                oldLineNumber: null,
                newLineNumber: 1,
                content: "new line",
              ),
            ),
          ],
        ),
      ];
      final vm = buildVM(hunks: hunks);
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.byType(DiffHunkWidget), findsOneWidget);
    });

    testWidgets("tap header collapses body", (tester) async {
      final hunks = [
        DiffHunkViewModel(
          hunk: const DiffHunk(
            oldStart: 1,
            oldCount: 1,
            newStart: 1,
            newCount: 2,
            lines: [],
          ),
          lines: [
            DiffLineViewModel(
              line: const DiffLine(
                type: DiffLineType.added,
                oldLineNumber: null,
                newLineNumber: 1,
                content: "visible line",
              ),
            ),
          ],
        ),
      ];
      final vm = buildVM(hunks: hunks);
      await tester.pumpWidget(buildTestWidget(vm));

      // Verify expanded initially
      expect(find.byType(DiffHunkWidget), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text(vm.fileName));
      await tester.pump();

      // Body should be hidden now
      expect(find.byType(DiffHunkWidget), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets("tap header twice re-expands body", (tester) async {
      final hunks = [
        DiffHunkViewModel(
          hunk: const DiffHunk(
            oldStart: 1,
            oldCount: 1,
            newStart: 1,
            newCount: 2,
            lines: [],
          ),
          lines: [],
        ),
      ];
      final vm = buildVM(hunks: hunks);
      await tester.pumpWidget(buildTestWidget(vm));

      // Collapse
      await tester.tap(find.text(vm.fileName));
      await tester.pump();
      expect(find.byType(DiffHunkWidget), findsNothing);

      // Expand again
      await tester.tap(find.text(vm.fileName));
      await tester.pump();
      expect(find.byType(DiffHunkWidget), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets("binary file shows placeholder instead of hunks", (tester) async {
      final vm = buildVM(isBinary: true);
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.text("Binary file changed"), findsOneWidget);
      expect(find.byType(DiffHunkWidget), findsNothing);
    });

    testWidgets("non-binary file renders DiffHunkWidgets", (tester) async {
      final hunks = [
        DiffHunkViewModel(
          hunk: const DiffHunk(
            oldStart: 1,
            oldCount: 2,
            newStart: 1,
            newCount: 3,
            lines: [],
          ),
          lines: [],
        ),
        DiffHunkViewModel(
          hunk: const DiffHunk(
            oldStart: 10,
            oldCount: 1,
            newStart: 12,
            newCount: 1,
            lines: [],
          ),
          lines: [],
        ),
      ];
      final vm = buildVM(hunks: hunks);
      await tester.pumpWidget(buildTestWidget(vm));

      expect(find.byType(DiffHunkWidget), findsNWidgets(2));
      expect(find.text("Binary file changed"), findsNothing);
    });
  });
}
