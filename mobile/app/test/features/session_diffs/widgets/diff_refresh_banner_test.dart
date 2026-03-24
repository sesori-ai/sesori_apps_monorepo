import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "package:sesori_mobile/features/session_diffs/widgets/diff_refresh_banner.dart";

class MockDiffCubit extends Mock implements DiffCubit {}

void main() {
  Widget buildTestWidget(DiffCubit cubit) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<DiffCubit>.value(
          value: cubit,
          child: const DiffRefreshBanner(),
        ),
      ),
    );
  }

  group("DiffRefreshBanner", () {
    testWidgets("is not visible when state is loading", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(const DiffState.loading());
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      // Banner should not be visible (SizedBox.shrink)
      expect(find.byType(Container), findsNothing);
      expect(find.text("New changes available"), findsNothing);
    });

    testWidgets("is not visible when hasNewChanges is false", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [],
          hasNewChanges: false,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      // Banner should not be visible
      expect(find.byType(Container), findsNothing);
      expect(find.text("New changes available"), findsNothing);
    });

    testWidgets("is visible when hasNewChanges is true", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [],
          hasNewChanges: true,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      // Banner should be visible with the text
      expect(find.text("New changes available"), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets("shows refresh button when hasNewChanges is true", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [],
          hasNewChanges: true,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      // Find the refresh button
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text("Refresh"), findsOneWidget);
    });

    testWidgets("calls cubit.refresh() when refresh button is tapped", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [],
          hasNewChanges: true,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(cubit.refresh).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(cubit));

      // Tap the refresh button
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      // Verify refresh was called
      verify(cubit.refresh).called(1);
    });

    testWidgets("displays refresh icon when banner is visible", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [],
          hasNewChanges: true,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      // Find the refresh icon
      final iconFinder = find.byIcon(Icons.refresh);
      expect(iconFinder, findsOneWidget);

      // Verify it's the correct size
      final icon = find.byIcon(Icons.refresh).evaluate().first.widget as Icon;
      expect(icon.size, 16);
    });
    testWidgets("is not visible when state is failed", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.failed(error: "Test error"),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      // Banner should not be visible when state is failed
      expect(find.byType(Container), findsNothing);
      expect(find.text("New changes available"), findsNothing);
    });
  });
}
