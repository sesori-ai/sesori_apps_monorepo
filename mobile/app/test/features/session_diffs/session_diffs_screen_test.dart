import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_diffs/session_diffs_screen.dart";
import "package:sesori_mobile/features/session_diffs/widgets/diff_file_widget.dart";
import "package:sesori_shared/sesori_shared.dart";

class MockDiffCubit extends Mock implements DiffCubit {}

void main() {
  late MockDiffCubit cubit;

  Widget buildTestWidget() {
    return MaterialApp(
      home: BlocProvider<DiffCubit>.value(
        value: cubit,
        child: const SessionDiffsBody(),
      ),
    );
  }

  setUp(() {
    cubit = MockDiffCubit();
  });

  group("SessionDiffsScreen", () {
    testWidgets("shows CircularProgressIndicator when loading", (tester) async {
      when(() => cubit.state).thenReturn(const DiffState.loading());
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("shows error message and Retry button when failed", (tester) async {
      when(() => cubit.state).thenReturn(const DiffState.failed(error: "Something went wrong"));
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget());

      expect(find.textContaining("Something went wrong"), findsOneWidget);
      expect(find.text("Retry"), findsOneWidget);
    });

    testWidgets("shows 'No file changes' when loaded with empty files", (tester) async {
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(files: [], messages: [], hasNewChanges: false),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget());

      expect(find.text("No file changes in this session"), findsOneWidget);
    });

    testWidgets("renders DiffFileWidget when loaded with files", (tester) async {
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [
            FileDiff(
              file: "lib/main.dart",
              before: "old line",
              after: "new line",
              additions: 1,
              deletions: 1,
              status: FileDiffStatus.modified,
            ),
          ],
          messages: [],
          hasNewChanges: false,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget());

      // compute() runs in a real isolate — runAsync lets it complete.
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
      await tester.pump();

      expect(find.byType(DiffFileWidget), findsOneWidget);
    });

    testWidgets("AppBar shows '1 file changed' with single file", (tester) async {
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [
            FileDiff(
              file: "lib/main.dart",
              before: "a",
              after: "b",
              additions: 3,
              deletions: 2,
              status: FileDiffStatus.modified,
            ),
          ],
          messages: [],
          hasNewChanges: false,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget());

      expect(find.text("File Changes"), findsOneWidget);
      expect(find.text("1 file changed  +3 -2"), findsOneWidget);
    });

    testWidgets("AppBar shows '3 files changed +10 -5' with multiple files", (tester) async {
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [
            FileDiff(file: "a.dart", before: "", after: "x", additions: 4, deletions: 2),
            FileDiff(file: "b.dart", before: "x", after: "", additions: 3, deletions: 1),
            FileDiff(file: "c.dart", before: "x", after: "y", additions: 3, deletions: 2),
          ],
          messages: [],
          hasNewChanges: false,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget());

      expect(find.text("File Changes"), findsOneWidget);
      expect(find.text("3 files changed  +10 -5"), findsOneWidget);
    });

    testWidgets("Retry button calls cubit.refresh()", (tester) async {
      when(() => cubit.state).thenReturn(const DiffState.failed(error: "err"));
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.refresh()).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text("Retry"));
      await tester.pumpAndSettle();

      verify(() => cubit.refresh()).called(1);
    });
  });
}
