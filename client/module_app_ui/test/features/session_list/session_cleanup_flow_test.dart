import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit;

void main() {
  late _MockSessionListCubit cubit;
  late List<Session> archived;
  final session = testSession(id: "s1", title: "Fix the build");

  setUp(() {
    cubit = _MockSessionListCubit();
    archived = [];
    when(() => cubit.retainActionScope()).thenReturn(() {});
  });

  Future<void> pumpArchiveButton({
    required WidgetTester tester,
    required SessionCleanupFlow cleanupFlow,
    required bool running,
  }) async {
    when(() => cubit.state).thenReturn(
      SessionListState.loaded(
        sessions: [session],
        filter: SessionListFilter.active,
        activeSessionIds: {
          if (running)
            "s1": const SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null),
        },
        baseBranch: null,
        repoSlug: null,
      ),
    );
    final dispatcher = SessionListActionDispatcher(
      cleanupFlow: cleanupFlow,
      onSessionDeleted: null,
      onSessionMarkedUnread: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SessionListCubit>.value(
          value: cubit,
          child: Material(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => dispatcher.handleSessionArchive(context: context, session: session),
                child: const Text("go"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("go"));
    await tester.pumpAndSettle();
  }

  SessionCleanupImmediate immediate() => SessionCleanupImmediate(
    onArchive: ({required context, required session, required deleteWorktree}) => archived.add(session),
  );

  testWidgets("the sheets flow still asks in the archive sheet", (tester) async {
    await pumpArchiveButton(tester: tester, cleanupFlow: const SessionCleanupSheets(), running: false);
    expect(find.text("Archive session?"), findsOneWidget);
  });

  testWidgets("the immediate flow archives an idle session without asking", (tester) async {
    await pumpArchiveButton(tester: tester, cleanupFlow: immediate(), running: false);
    expect(archived, [session]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets("the immediate flow asks first for a running session, and Cancel archives nothing", (tester) async {
    await pumpArchiveButton(tester: tester, cleanupFlow: immediate(), running: true);
    expect(find.text("Archive a running session?"), findsOneWidget);
    expect(archived, isEmpty);

    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();
    expect(archived, isEmpty);

    await tester.tap(find.text("go"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, "Archive"));
    await tester.pumpAndSettle();
    expect(archived, [session]);
  });
}
