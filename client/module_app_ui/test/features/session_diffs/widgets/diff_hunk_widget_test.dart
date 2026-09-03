import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_diffs/models/diff_file_view_model.dart";
import "package:sesori_app_ui/src/features/session_diffs/widgets/diff_hunk_widget.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

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
      const vm = DiffHunkViewModel(
        hunk: DiffHunk(
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
      const vm = DiffHunkViewModel(
        hunk: DiffHunk(
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

    testWidgets("hunk metadata is outside a selection", (tester) async {
      const vm = DiffHunkViewModel(
        hunk: DiffHunk(
          oldStart: 1,
          oldCount: 1,
          newStart: 1,
          newCount: 1,
          lines: [],
        ),
        lines: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PregoReadableSelectionArea(
              child: DiffHunkWidget(viewModel: vm),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DiffHunkWidget),
          matching: find.byWidgetPredicate(
            (widget) => widget is SelectionContainer && widget.delegate == null,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets("header uses monospace font", (tester) async {
      const vm = DiffHunkViewModel(
        hunk: DiffHunk(
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
