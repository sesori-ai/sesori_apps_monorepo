import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_diffs/widgets/diff_message_selector.dart";
import "package:sesori_shared/sesori_shared.dart";

class MockDiffCubit extends Mock implements DiffCubit {}

const _userMsg1 = MessageWithParts(
  info: Message(role: "user", id: "u1", sessionID: "s1"),
  parts: [],
);

const _userMsg2 = MessageWithParts(
  info: Message(role: "user", id: "u2", sessionID: "s1"),
  parts: [],
);

const _assistantMsg = MessageWithParts(
  info: Message(role: "assistant", id: "a1", sessionID: "s1"),
  parts: [],
);

void main() {
  Widget buildTestWidget(DiffCubit cubit) {
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<DiffCubit>.value(
          value: cubit,
          child: const DiffMessageSelector(),
        ),
      ),
    );
  }

  group("DiffMessageSelector", () {
    testWidgets("is not visible when state is loading", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(const DiffState.loading());
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets("is not visible when loaded with empty messages", (tester) async {
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

      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets("shows All changes + 2 message chips when loaded with 2 user messages", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [_userMsg1, _assistantMsg, _userMsg2],
          hasNewChanges: false,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      expect(find.byType(FilterChip), findsNWidgets(3));
      expect(find.text("All changes"), findsOneWidget);
      expect(find.text("Message 1"), findsOneWidget);
      expect(find.text("Message 2"), findsOneWidget);
    });

    testWidgets("All changes is selected by default (selectedId == null)", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [_userMsg1],
          hasNewChanges: false,
          // selectedMessageId is null by default
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      final allChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, "All changes"),
      );
      expect(allChip.selected, isTrue);

      final msg1Chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, "Message 1"),
      );
      expect(msg1Chip.selected, isFalse);
    });

    testWidgets("tapping message chip calls cubit.selectMessage(messageId)", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [_userMsg1, _userMsg2],
          hasNewChanges: false,
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.selectMessage(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(cubit));

      await tester.tap(find.text("Message 2"));
      await tester.pumpAndSettle();

      verify(() => cubit.selectMessage("u2")).called(1);
    });

    testWidgets("tapping All changes calls cubit.selectMessage(null)", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [_userMsg1],
          hasNewChanges: false,
          selectedMessageId: "u1",
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.selectMessage(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestWidget(cubit));

      await tester.tap(find.text("All changes"));
      await tester.pumpAndSettle();

      verify(() => cubit.selectMessage(null)).called(1);
    });

    testWidgets("when selectedMessageId is set, that chip appears selected", (tester) async {
      final cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(
        const DiffState.loaded(
          files: [],
          messages: [_userMsg1, _userMsg2],
          hasNewChanges: false,
          selectedMessageId: "u2",
        ),
      );
      when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(buildTestWidget(cubit));

      final allChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, "All changes"),
      );
      expect(allChip.selected, isFalse);

      final msg1Chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, "Message 1"),
      );
      expect(msg1Chip.selected, isFalse);

      final msg2Chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, "Message 2"),
      );
      expect(msg2Chip.selected, isTrue);
    });
  });
}
