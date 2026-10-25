import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockAllSessionsCubit() extends MockCubit<AllSessionsState> implements AllSessionsCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

class _MockRecentSessionInventoryService() extends Mock implements RecentSessionInventoryService;

void main() {
  const project = ProjectSummary(id: "project-1", name: "Sesori", path: "/sesori", time: null);
  late StreamController<AllSessionsState> listStates;
  late BehaviorSubject<Map<String, RecentSessionsEntry>> entries;
  late SessionLaunchRepository launches;
  late int opened;
  final now = DateTime.now().millisecondsSinceEpoch;
  final earlier = testSession(id: "earlier", title: "Earlier work", updatedAt: now - 60000);
  final created = testSession(id: "created", title: "Fix the bug", updatedAt: now);

  AllSessionsState list({required List<Session> sessions}) => AllSessionsState(
    projectId: null,
    query: "",
    quickFilter: SessionListQuickFilter.all,
    rows: [
      for (final session in sessions)
        AllSessionsRow(
          session: session,
          project: project,
          isRunning: false,
          isUnseen: false,
          isAwaitingInput: false,
          isRetrying: false,
          backgroundTaskCount: 0,
        ),
    ],
    counts: SessionListChipCounts(all: sessions.length, running: 0, unread: 0),
    failures: const [],
    isLoading: false,
    defaultProjectId: project.id,
  );

  RecentSessionsEntry loaded({required List<Session> sessions}) => RecentSessionsLoaded(
    sourceSessions: sessions,
    visibleSessions: sessions,
    archivedSessions: const [],
    activityBySessionId: const {},
    listStateBySessionId: const {},
  );

  /// The project's sessions reach the inventory the launching rows read and the
  /// list's rows together, as one scope's inventory feeds both.
  void showSessions({required List<Session> sessions}) {
    entries.add({project.id: loaded(sessions: sessions)});
    listStates.add(list(sessions: sessions));
  }

  Future<void> pumpList(
    WidgetTester tester, {
    required List<Session> sessions,
    PregoInteractionMode mode = PregoInteractionMode.touch,
    double textScale = 1,
    bool reduceMotion = false,
  }) async {
    listStates = StreamController<AllSessionsState>();
    addTearDown(listStates.close);
    entries = BehaviorSubject.seeded({project.id: loaded(sessions: sessions)});
    addTearDown(entries.close);
    final cubit = _MockAllSessionsCubit();
    whenListen(cubit, listStates.stream, initialState: list(sessions: sessions));
    when(() => cubit.mode).thenReturn(AllSessionsMode.active);
    when(() => cubit.setHiddenSessionIds(sessionIds: any(named: "sessionIds"))).thenReturn(null);
    final projects = _MockProjectListCubit();
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [project]),
    );
    final inventory = _MockRecentSessionInventoryService();
    when(() => inventory.state).thenAnswer((_) => entries);
    launches = inMemorySessionLaunchRepository();
    opened = 0;
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: "/",
              builder: (context, _) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
                child: PregoInteractionScope(
                  mode: mode,
                  child: MultiBlocProvider(
                    providers: [
                      BlocProvider<AllSessionsCubit>.value(value: cubit),
                      BlocProvider<ProjectListCubit>.value(value: projects),
                      BlocProvider(
                        create: (_) => PendingSessionArchiveCubit(
                          cleanupService: SessionCleanupService(repository: MockSessionRepository()),
                        ),
                      ),
                      RepositoryProvider<RecentSessionInventoryService>.value(value: inventory),
                      RepositoryProvider(
                        create: (_) => inMemorySessionLaunchService(launchRepository: launches),
                      ),
                    ],
                    child: Scaffold(
                      body: CustomScrollView(
                        slivers: [
                          AllSessionsList(
                            onSessionTap: ({required row}) => opened++,
                            actionDispatcher: const SessionListActionDispatcher(
                              deleteConfirmation: SessionDeleteConfirmation.sheet,
                              onSessionArchived: null,
                              onSessionDeleted: null,
                              onSessionMarkedUnread: null,
                            ),
                            createActionCubit: ({required projectId, required session}) =>
                                throw StateError("no row to act on"),
                            selectedSessionId: null,
                            disconnectedBuilder: ({required context, required state}) =>
                                const SliverToBoxAdapter(child: Text("Computer offline")),
                            emptyState: const Text("Nothing here"),
                            header: null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  // The launching row's sparkle never settles, so this pumps fixed frames: one
  // for the updates in flight to build, one for the transitions they start to
  // take their first tick, then past those transitions.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> startLaunch(WidgetTester tester) async {
    launches.start(
      launchId: "launch-1",
      projectId: project.id,
      pluginId: "claude",
      startedAt: DateTime.now(),
      projectName: "Sesori",
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Fix the bug\nin the parser"),
        attachments: const [],
      ),
    );
    await settle(tester);
  }

  final launchRow = find.byType(PendingSessionLaunchTile);
  double rowBelowTop(WidgetTester tester) => tester.getTopLeft(find.text("Earlier work")).dy;

  testWidgets("a launch leads the list as one row, then settles in place into its session", (tester) async {
    await pumpList(tester, sessions: [earlier]);
    final belowBefore = rowBelowTop(tester);

    await startLaunch(tester);
    expect(launchRow, findsOneWidget);
    expect(find.text("Fix the bug"), findsOneWidget);
    expect(find.textContaining("Creating…"), findsOneWidget);
    expect(find.descendant(of: launchRow, matching: find.byType(PregoBrandLogo)), findsOneWidget);
    final below = rowBelowTop(tester);
    expect(below, greaterThan(tester.getBottomLeft(launchRow).dy - 1), reason: "the launch row leads");
    expect(below, greaterThan(belowBefore));

    // The reply names the session before the list has it: still one row.
    launches.promote(launchId: "launch-1", session: created);
    await tester.pump();
    expect(launchRow, findsOneWidget);

    showSessions(sessions: [created, earlier]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(rowBelowTop(tester), below, reason: "the row below never moves while the row swaps");

    await settle(tester);
    expect(launchRow, findsNothing);
    expect(find.text("Fix the bug"), findsOneWidget, reason: "only its session, not the launching row too");
    expect(rowBelowTop(tester), below);
  });

  testWidgets("with reduced motion the launching row becomes its session at once", (tester) async {
    await pumpList(tester, sessions: [earlier], reduceMotion: true);
    await startLaunch(tester);
    launches.promote(launchId: "launch-1", session: created);
    showSessions(sessions: [created, earlier]);
    await tester.pump();
    await tester.pump();

    expect(launchRow, findsNothing);
    expect(find.text("Fix the bug"), findsOneWidget);
  });

  testWidgets("tapping a launching row explains it is not ready and opens nothing", (tester) async {
    await pumpList(tester, sessions: [earlier]);
    await startLaunch(tester);

    await tester.tap(launchRow);
    await settle(tester);

    expect(find.text("This session is still being created. You can open it once it's ready."), findsOneWidget);
    expect(opened, 0);
  });

  for (final mode in PregoInteractionMode.values) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets("a launching row is as tall as a session row (${mode.name}, text x$textScale)", (tester) async {
        await pumpList(tester, sessions: [earlier], mode: mode, textScale: textScale);
        await startLaunch(tester);

        expect(tester.getSize(launchRow).height, tester.getSize(find.byType(SessionTile)).height);
      });
    }
  }
}
