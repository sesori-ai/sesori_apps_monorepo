import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_diffs/models/diff_file_view_model.dart";
import "package:sesori_mobile/features/session_diffs/widgets/diff_file_widget.dart";
import "package:sesori_shared/sesori_shared.dart";

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
  });
}
