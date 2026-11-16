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

class _MockSessionActionsCubit() extends MockCubit<void> implements SessionActionsCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

void main() {
  late _MockSessionActionsCubit actions;
  late PendingSessionArchiveCubit archives;
  late List<String> archived;
  final session = testSession(id: "s1", title: "Fix the build");

  setUp(() {
    actions = _MockSessionActionsCubit();
    archived = [];
    archives = PendingSessionArchiveCubit(cleanupService: SessionCleanupService(repository: MockSessionRepository()));
  });

  Future<void> pumpArchiveButton({
    required WidgetTester tester,
    required bool running,
    bool pinned = false,
  }) async {
    final dispatcher = SessionListActionDispatcher(
      deleteConfirmation: SessionDeleteConfirmation.sheet,
      onSessionArchived: ({required context, required sessionId}) => archived.add(sessionId),
      onSessionDeleted: null,
      onSessionMarkedUnread: null,
      openSession: _openNothing,
      createSessionSearch: _searchNothing,
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
              builder: (_, _) => BlocProvider.value(
                value: archives,
                child: Material(
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => dispatcher.handleSessionArchive(
                        context: context,
                        session: session.copyWith(pinOrder: pinned ? 1 : null),
                        isRunning: running,
                      ),
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
    // The bridge stops a running session before archiving it; the alert says so.
    expect(
      find.text("“Fix the build” is still running. Archiving stops it and makes it permanently read-only."),
      findsOneWidget,
    );
    expect(archives.state.hiddenIds, isEmpty);

    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Cancel"));
    await tester.pumpAndSettle();
    expect(archives.state.hiddenIds, isEmpty);
    expect(find.byType(PregoSheetActions), findsNothing);

    await tester.tap(find.text("go"));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Archive"));
    await tester.pumpAndSettle();
    expect(archived, ["s1"]);
    expect(archives.state.hiddenIds, {"s1"});
    // Closing inside the window cancels its timer and sends nothing.
    await archives.close();
  });

  testWidgets("a pinned session is asked about first; Archive enters the Undo window", (tester) async {
    await pumpArchiveButton(tester: tester, running: false, pinned: true);
    expect(find.text("Archive a pinned session?"), findsOneWidget);
    expect(
      find.text("“Fix the build” is pinned. Archiving removes it from your lists for good and drops the pin."),
      findsOneWidget,
    );
    expect(find.text("It is still running, and archiving stops it."), findsNothing);

    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Cancel"));
    await tester.pumpAndSettle();
    expect(archives.state.hiddenIds, isEmpty);
    expect(find.byType(PregoSheetActions), findsNothing);

    await tester.tap(find.text("go"));
    await tester.pumpAndSettle();
    final archive = find.widgetWithText(PregoButtonsSolid, "Archive");
    expect(tester.widget<PregoButtonsSolid>(archive).type, PregoButtonsSolidType.destructive);
    await tester.tap(archive);
    await tester.pumpAndSettle();
    expect(archived, ["s1"]);
    expect(archives.state.hiddenIds, {"s1"});
    await archives.close();
  });

  testWidgets("a running pinned session gets one question that covers both", (tester) async {
    await pumpArchiveButton(tester: tester, running: true, pinned: true);
    expect(find.text("Archive a pinned session?"), findsOneWidget);
    expect(find.text("Archive a running session?"), findsNothing);
    expect(find.text("It is still running, and archiving stops it."), findsOneWidget);

    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Archive"));
    await tester.pumpAndSettle();
    expect(archived, ["s1"]);
    expect(find.text("Archive a running session?"), findsNothing);
    await archives.close();
  });

  group("pin", () {
    const dispatcher = SessionListActionDispatcher(
      deleteConfirmation: SessionDeleteConfirmation.alert,
      onSessionArchived: null,
      onSessionDeleted: null,
      onSessionMarkedUnread: null,
      openSession: _openNothing,
      createSessionSearch: _searchNothing,
    );

    /// The menu entries for [target], kept in [entries] once built.
    Future<List<PregoMenuItem>> menuFor({required WidgetTester tester, required shared.Session target}) async {
      late List<PregoMenuItem> entries;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: Builder(
              builder: (context) {
                entries = dispatcher
                    .sessionMenuEntries(
                      context: context,
                      actions: actions,
                      session: target,
                      isRunning: false,
                      readEntry: const SessionReadMenuNone(),
                      surfaceEntries: [
                        PregoMenuItem(
                          leadingIcon: TablerRegular.plug,
                          title: "Page action",
                          subtitle: null,
                          isSelected: false,
                          shortcutLabel: null,
                          onTap: () {},
                        ),
                      ],
                    )
                    .whereType<PregoMenuItem>()
                    .toList();
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return entries;
    }

    testWidgets("Pin or Unpin leads the menu of an unarchived top-level session only", (tester) async {
      List<String> titlesOf(List<PregoMenuItem> entries) => [for (final entry in entries) entry.title];

      expect(titlesOf(await menuFor(tester: tester, target: session)).take(3), ["Pin", "Page action", "Rename"]);
      expect(titlesOf(await menuFor(tester: tester, target: session.copyWith(pinOrder: 1))).first, "Unpin");
      final archivedSession = testSession(id: "s1", title: "Fix the build", archivedAt: DateTime(2026));
      expect(titlesOf(await menuFor(tester: tester, target: archivedSession)), isNot(contains("Pin")));
      final child = testSession(id: "c1", parentID: "s1", title: "Sub-task");
      expect(titlesOf(await menuFor(tester: tester, target: child)), isNot(contains("Pin")));
    });

    for (final (result, message) in [
      (const SessionPinUnsupported(), "Update this computer to pin sessions"),
      (SessionPinFailure(error: ApiError.generic()), "Failed to pin session"),
    ]) {
      testWidgets("a Pin the bridge cannot honour is answered: $message", (tester) async {
        when(() => actions.setPinned(sessionId: "s1", pinned: true)).thenAnswer((_) async => result);
        final entries = await menuFor(tester: tester, target: session);

        entries.first.onTap();
        await tester.pump();
        expect(find.text(message), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 5));
      });
    }
  });

  testWidgets("the row menu offers one Archive, never a keep-worktree variant", (tester) async {
    final worktreeSession = session.copyWith(hasWorktree: true);
    const dispatcher = SessionListActionDispatcher(
      deleteConfirmation: SessionDeleteConfirmation.alert,
      onSessionArchived: null,
      onSessionDeleted: null,
      onSessionMarkedUnread: null,
      openSession: _openNothing,
      createSessionSearch: _searchNothing,
    );
    late List<String> titles;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: Builder(
            builder: (context) {
              titles = dispatcher
                  .sessionMenuEntries(
                    context: context,
                    actions: actions,
                    session: worktreeSession,
                    isRunning: false,
                    readEntry: const SessionReadMenuNone(),
                    surfaceEntries: const [],
                  )
                  .whereType<PregoMenuItem>()
                  .map((entry) => entry.title)
                  .toList();
              return const SizedBox();
            },
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
    /// refuses that call, null lets it complete. Calls past the end complete.
    /// [target] belongs to the
    /// bridge's "No project" project when [noProject].
    Future<void> pumpDeleteButton({
      required WidgetTester tester,
      required shared.Session target,
      required SessionDeleteConfirmation deleteConfirmation,
      List<SessionCleanupRejection?> rejections = const [],
      bool noProject = false,
    }) async {
      final pending = [...rejections];
      final projects = _MockProjectListCubit();
      const scratch = shared.ProjectSummary(
        id: "scratch",
        name: null,
        path: "/scratch",
        time: null,
        kind: shared.ProjectKind.scratch,
      );
      const folder = shared.ProjectSummary(id: "folder", name: "Folder", path: "/folder", time: null);
      whenListen(
        projects,
        const Stream<ProjectListState>.empty(),
        initialState: const ProjectListState.loaded(
          projects: [folder, scratch],
          folderProjects: [folder],
          scratchProject: scratch,
        ),
      );
      when(
        () => actions.deleteSession(
          sessionId: any(named: "sessionId"),
          deleteWorktree: any(named: "deleteWorktree"),
          deleteSessionFolder: any(named: "deleteSessionFolder"),
          force: any(named: "force"),
        ),
      ).thenAnswer(
        (_) async => switch (pending.isEmpty ? null : pending.removeAt(0)) {
          final rejection? => SessionDeleteRejected(rejection: rejection),
          null => const SessionDeleted(outcome: SessionCleanupOutcome.completed),
        },
      );

      final dispatcher = SessionListActionDispatcher(
        deleteConfirmation: deleteConfirmation,
        onSessionArchived: null,
        onSessionDeleted: null,
        onSessionMarkedUnread: null,
        openSession: _openNothing,
        createSessionSearch: _searchNothing,
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
                    BlocProvider<ProjectListCubit>.value(value: projects),
                    BlocProvider.value(value: archives),
                  ],
                  child: Material(
                    child: Builder(
                      builder: (context) => TextButton(
                        onPressed: () => dispatcher.handleSessionDelete(
                          context: context,
                          actions: actions,
                          session: target.copyWith(projectID: noProject ? "scratch" : "folder"),
                        ),
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
        verify(
          () => actions.deleteSession(sessionId: "s1", deleteWorktree: true, deleteSessionFolder: false, force: false),
        ).called(1);
      });

      testWidgets("the ${confirmation.name} says a pinned session is pinned", (tester) async {
        await pumpDeleteButton(
          tester: tester,
          target: session.copyWith(pinOrder: 1),
          deleteConfirmation: confirmation,
        );

        expect(find.text("It is pinned."), findsOneWidget);
      });

      testWidgets("the ${confirmation.name} omits the worktree line without one", (tester) async {
        await pumpDeleteButton(tester: tester, target: session, deleteConfirmation: confirmation);

        expect(find.text("Its worktree will be deleted too. The branch is kept."), findsNothing);
        expect(find.text("Its folder and every file in it will be deleted too."), findsNothing);
        await tester.tap(find.byKey(sessionDeleteConfirmKey));
        await tester.pumpAndSettle();
        verify(
          () => actions.deleteSession(sessionId: "s1", deleteWorktree: false, deleteSessionFolder: false, force: false),
        ).called(1);
      });

      testWidgets("the ${confirmation.name} says a No project session's folder goes, and deletes it", (tester) async {
        await pumpDeleteButton(tester: tester, target: session, deleteConfirmation: confirmation, noProject: true);

        expect(find.text("Its folder and every file in it will be deleted too."), findsOneWidget);
        await tester.tap(find.byKey(sessionDeleteConfirmKey));
        await tester.pumpAndSettle();
        verify(
          () => actions.deleteSession(sessionId: "s1", deleteWorktree: false, deleteSessionFolder: true, force: false),
        ).called(1);
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
      verify(
        () => actions.deleteSession(sessionId: "s1", deleteWorktree: true, deleteSessionFolder: false, force: true),
      ).called(1);
    });

    testWidgets("an older bridge's branch mismatch refusal still offers Delete anyway", (tester) async {
      await pumpDeleteButton(
        tester: tester,
        target: worktreeSession,
        deleteConfirmation: SessionDeleteConfirmation.alert,
        rejections: const [
          SessionCleanupRejection(
            issues: [shared.CleanupIssue.branchMismatch(expected: "feat/x", actual: "main")],
          ),
        ],
      );
      await confirmDelete(tester);

      expect(find.text("Worktree is on branch 'main' instead of expected 'feat/x'"), findsOneWidget);
      await tester.tap(find.widgetWithText(PregoButtonsSolid, "Delete anyway"));
      await tester.pumpAndSettle();
      verify(
        () => actions.deleteSession(sessionId: "s1", deleteWorktree: true, deleteSessionFolder: false, force: true),
      ).called(1);
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
        () => actions.deleteSession(
          sessionId: "s1",
          deleteWorktree: any(named: "deleteWorktree"),
          deleteSessionFolder: any(named: "deleteSessionFolder"),
          force: true,
        ),
      );
    });

    testWidgets("a worktree the bridge reports kept is said so once, without asking", (tester) async {
      await pumpDeleteButton(
        tester: tester,
        target: worktreeSession,
        deleteConfirmation: SessionDeleteConfirmation.alert,
      );
      when(
        () => actions.deleteSession(sessionId: "s1", deleteWorktree: true, deleteSessionFolder: false, force: false),
      ).thenAnswer((_) async => const SessionDeleted(outcome: SessionCleanupOutcome.sharedWorktreeKept));
      await confirmDelete(tester);

      expect(find.text("Delete anyway"), findsNothing);
      verify(
        () => actions.deleteSession(sessionId: "s1", deleteWorktree: true, deleteSessionFolder: false, force: false),
      ).called(1);
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
      verifyNever(
        () => actions.deleteSession(sessionId: "s1", deleteWorktree: false, deleteSessionFolder: false, force: false),
      );
    });
  });
}

void _openNothing({required String projectId, required String projectName, required shared.Session session}) {}

SessionSearchCubit _searchNothing({
  required SessionWindowService window,
  required ProjectInventoryService projectInventory,
  required String? excludedSessionId,
}) => throw UnimplementedError("These tests do not send sessions");
