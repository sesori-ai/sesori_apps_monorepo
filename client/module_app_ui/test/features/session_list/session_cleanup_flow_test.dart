import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit;

void main() {
  late _MockSessionListCubit cubit;
  late PendingSessionArchiveCubit archives;
  late List<String> archived;
  final session = testSession(id: "s1", title: "Fix the build");

  setUp(() {
    cubit = _MockSessionListCubit();
    archived = [];
    archives = PendingSessionArchiveCubit(repository: MockSessionRepository());
    when(() => cubit.retainActionScope()).thenReturn(() {});
  });

  Future<void> pumpArchiveButton({
    required WidgetTester tester,
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
      deleteConfirmation: SessionDeleteConfirmation.sheet,
      onSessionArchived: ({required context, required sessionId}) => archived.add(sessionId),
      onSessionDeleted: null,
      onSessionMarkedUnread: null,
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The alerts close themselves through the router, as in the app.
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: "/",
              builder: (_, _) => MultiBlocProvider(
                providers: [
                  BlocProvider<SessionListCubit>.value(value: cubit),
                  BlocProvider.value(value: archives),
                ],
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
          ],
        ),
      ),
    );
    await tester.tap(find.text("go"));
    await tester.pumpAndSettle();
  }

  testWidgets("an idle session enters the Undo window without being asked about", (tester) async {
    await pumpArchiveButton(tester: tester, running: false);
    expect(archived, ["s1"]);
    expect(archives.state.hiddenIds, {"s1"});
    // Closing inside the window cancels its timer and sends nothing.
    await archives.close();
    expect(find.text("Archive a running session?"), findsNothing);
  });

  testWidgets("a running session is asked about first, and Cancel archives nothing", (tester) async {
    await pumpArchiveButton(tester: tester, running: true);
    expect(find.text("Archive a running session?"), findsOneWidget);
    expect(archives.state.hiddenIds, isEmpty);

    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();
    expect(archives.state.hiddenIds, isEmpty);

    await tester.tap(find.text("go"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Archive"));
    await tester.pumpAndSettle();
    expect(archived, ["s1"]);
    expect(archives.state.hiddenIds, {"s1"});
    // Closing inside the window cancels its timer and sends nothing.
    await archives.close();
  });

  testWidgets("the row menu offers one Archive, never a keep-worktree variant", (tester) async {
    final worktreeSession = session.copyWith(hasWorktree: true);
    when(() => cubit.state).thenReturn(
      SessionListState.loaded(sessions: [worktreeSession], baseBranch: null, repoSlug: null),
    );
    const dispatcher = SessionListActionDispatcher(
      deleteConfirmation: SessionDeleteConfirmation.alert,
      onSessionArchived: null,
      onSessionDeleted: null,
      onSessionMarkedUnread: null,
    );
    late List<String> titles;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SessionListCubit>.value(
          value: cubit,
          child: Material(
            child: Builder(
              builder: (context) {
                titles = dispatcher
                    .sessionMenuEntries(
                      context: context,
                      cubit: cubit,
                      session: worktreeSession,
                      readEntry: SessionReadMenuEntry.none,
                    )
                    .whereType<PregoMenuItem>()
                    .map((entry) => entry.title)
                    .toList();
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(titles.where((title) => title == "Archive"), hasLength(1));
    expect(titles, isNot(contains("Archive, keep worktree")));
  });

  group("delete", () {
    /// Renders a button that deletes [target] through [deleteConfirmation].
    ///
    /// Each entry of [rejections] answers one `deleteSession` call: a rejection
    /// fails that call and is published as the cubit's last rejection, null lets
    /// it succeed. Calls past the end succeed.
    Future<void> pumpDeleteButton({
      required WidgetTester tester,
      required shared.Session target,
      required SessionDeleteConfirmation deleteConfirmation,
      List<SessionCleanupRejection?> rejections = const [],
    }) async {
      final pending = [...rejections];
      SessionCleanupRejection? lastRejection;
      when(() => cubit.state).thenReturn(
        SessionListState.loaded(sessions: [target], baseBranch: null, repoSlug: null),
      );
      when(() => cubit.lastCleanupRejection).thenAnswer((_) => lastRejection);
      when(
        () => cubit.deleteSession(
          sessionId: any(named: "sessionId"),
          deleteWorktree: any(named: "deleteWorktree"),
          force: any(named: "force"),
        ),
      ).thenAnswer((_) async {
        lastRejection = pending.isEmpty ? null : pending.removeAt(0);
        return lastRejection == null;
      });

      final dispatcher = SessionListActionDispatcher(
        deleteConfirmation: deleteConfirmation,
        onSessionArchived: null,
        onSessionDeleted: null,
        onSessionMarkedUnread: null,
      );
      await tester.pumpWidget(
        MaterialApp.router(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: "/",
                builder: (_, _) => MultiBlocProvider(
                  providers: [
                    BlocProvider<SessionListCubit>.value(value: cubit),
                    BlocProvider.value(value: archives),
                  ],
                  child: Material(
                    child: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => dispatcher.handleSessionDelete(context: context, session: target),
                        child: const Text("go"),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text("go"));
      await tester.pumpAndSettle();
    }

    final worktreeSession = testSession(id: "s1", title: "Fix the build").copyWith(hasWorktree: true);

    for (final confirmation in SessionDeleteConfirmation.values) {
      testWidgets("the ${confirmation.name} says the worktree goes and never offers to keep it", (tester) async {
        await pumpDeleteButton(tester: tester, target: worktreeSession, deleteConfirmation: confirmation);

        expect(find.text("Its worktree will be deleted too. The branch is kept."), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNothing);

        await tester.tap(find.byKey(sessionDeleteConfirmKey));
        await tester.pumpAndSettle();
        verify(() => cubit.deleteSession(sessionId: "s1", deleteWorktree: true, force: false)).called(1);
      });

      testWidgets("the ${confirmation.name} omits the worktree line without one", (tester) async {
        await pumpDeleteButton(tester: tester, target: session, deleteConfirmation: confirmation);

        expect(find.text("Its worktree will be deleted too. The branch is kept."), findsNothing);
        await tester.tap(find.byKey(sessionDeleteConfirmKey));
        await tester.pumpAndSettle();
        verify(() => cubit.deleteSession(sessionId: "s1", deleteWorktree: false, force: false)).called(1);
      });
    }

    Future<void> confirmDelete(WidgetTester tester) async {
      await tester.tap(find.byKey(sessionDeleteConfirmKey));
      await tester.pumpAndSettle();
    }

    testWidgets("a refusal over the user's own work offers Cancel or a destructive Delete anyway", (tester) async {
      await pumpDeleteButton(
        tester: tester,
        target: worktreeSession,
        deleteConfirmation: SessionDeleteConfirmation.alert,
        rejections: const [
          SessionCleanupRejection(issues: [shared.CleanupIssue.unstagedChanges()]),
        ],
      );
      await confirmDelete(tester);

      expect(find.text("Worktree has unstaged changes"), findsOneWidget);
      final anyway = find.widgetWithText(PregoButtonsSolid, "Delete anyway");
      expect(tester.widget<PregoButtonsSolid>(anyway).type, PregoButtonsSolidType.destructive);
      expect(find.widgetWithText(PregoButtonsSolid, "Cancel"), findsOneWidget);
      // Exactly two ways out, so no third "keep the worktree" escape remains.
      expect(find.byType(PregoButtonsSolid), findsNWidgets(2));

      await tester.tap(anyway);
      await tester.pumpAndSettle();
      verify(() => cubit.deleteSession(sessionId: "s1", deleteWorktree: true, force: true)).called(1);
    });

    testWidgets("Cancel on that refusal deletes nothing more", (tester) async {
      await pumpDeleteButton(
        tester: tester,
        target: worktreeSession,
        deleteConfirmation: SessionDeleteConfirmation.alert,
        rejections: const [
          SessionCleanupRejection(issues: [shared.CleanupIssue.unstagedChanges()]),
        ],
      );
      await confirmDelete(tester);

      await tester.tap(find.widgetWithText(PregoButtonsSolid, "Cancel"));
      await tester.pumpAndSettle();
      verifyNever(
        () => cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: any(named: "deleteWorktree"),
          force: true,
        ),
      );
    });

    testWidgets("a worktree another session shares is kept without asking, and said so once", (tester) async {
      await pumpDeleteButton(
        tester: tester,
        target: worktreeSession,
        deleteConfirmation: SessionDeleteConfirmation.alert,
        rejections: const [
          SessionCleanupRejection(issues: [shared.CleanupIssue.sharedWorktree()]),
        ],
      );
      await confirmDelete(tester);

      // No modal, no force: the session goes, the other session's worktree stays.
      expect(find.text("Delete anyway"), findsNothing);
      verifyInOrder([
        () => cubit.deleteSession(sessionId: "s1", deleteWorktree: true, force: false),
        () => cubit.deleteSession(sessionId: "s1", deleteWorktree: false, force: false),
      ]);
      verifyNever(
        () => cubit.deleteSession(
          sessionId: "s1",
          deleteWorktree: any(named: "deleteWorktree"),
          force: true,
        ),
      );
      expect(find.text("Session deleted"), findsOneWidget);
      expect(find.text("Another session is still using the worktree, so it was left in place."), findsOneWidget);
    });

    testWidgets("a shared worktree alongside the user's own work still asks", (tester) async {
      await pumpDeleteButton(
        tester: tester,
        target: worktreeSession,
        deleteConfirmation: SessionDeleteConfirmation.alert,
        rejections: const [
          SessionCleanupRejection(
            issues: [shared.CleanupIssue.sharedWorktree(), shared.CleanupIssue.unstagedChanges()],
          ),
        ],
      );
      await confirmDelete(tester);

      expect(find.text("Another active session uses this worktree"), findsOneWidget);
      expect(find.text("Worktree has unstaged changes"), findsOneWidget);
      expect(find.widgetWithText(PregoButtonsSolid, "Delete anyway"), findsOneWidget);
      verifyNever(() => cubit.deleteSession(sessionId: "s1", deleteWorktree: false, force: false));
    });
  });
}
