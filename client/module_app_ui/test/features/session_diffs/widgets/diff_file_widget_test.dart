import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_diffs/models/diff_file_view_model.dart";
import "package:sesori_app_ui/src/features/session_diffs/widgets/diff_file_widget.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  DiffFileViewModel buildVM({
    String fileName = "main.dart",
    int additions = 5,
    int deletions = 2,
    FileDiffStatus? status,
  }) {
    return DiffFileViewModel(
      fileDiff: FileDiff.content(
        file: "lib/$fileName",
        before: "",
        after: "",
        additions: additions,
        deletions: deletions,
        status: status,
      ),
      fileName: fileName,
      hunks: const [],
      additions: additions,
      deletions: deletions,
      status: status,
    );
  }

  Widget buildTestWidget(DiffFileViewModel viewModel) {
    return MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.light),
      home: Scaffold(
        body: DiffFileWidget(
          viewModel: viewModel,
          isExpanded: true,
          onToggle: () {},
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

    testWidgets("header shows +N and −M stats", (tester) async {
      final vm = buildVM(additions: 12, deletions: 3);
      await tester.pumpWidget(buildTestWidget(vm));
      expect(find.text("+12"), findsOneWidget);
      expect(find.text("−3"), findsOneWidget);
    });

    testWidgets("header leaves out a zero count", (tester) async {
      await tester.pumpWidget(buildTestWidget(buildVM(additions: 7, deletions: 0)));
      expect(find.text("+7"), findsOneWidget);
      expect(find.textContaining("0"), findsNothing);

      await tester.pumpWidget(buildTestWidget(buildVM(additions: 0, deletions: 4)));
      expect(find.text("−4"), findsOneWidget);
      expect(find.textContaining("+"), findsNothing);
    });

    testWidgets('status badge shows "A" for added', (tester) async {
      final vm = buildVM(status: FileDiffStatus.added);
      await tester.pumpWidget(buildTestWidget(vm));
      expect(find.text("A"), findsOneWidget);
    });

    testWidgets("status letter is plain text in its status colour", (tester) async {
      await tester.pumpWidget(buildTestWidget(buildVM(status: FileDiffStatus.deleted)));
      final colors = tester.element(find.byType(DiffFileWidget)).prego.colors;
      expect(tester.widget<Text>(find.text("D")).style?.color, colors.textErrorPrimary);
      // Only the header's own background: no badge box around the letter.
      expect(find.ancestor(of: find.text("D"), matching: find.byType(DecoratedBox)), findsOneWidget);
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
  });
}
