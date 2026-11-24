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

class _MockSessionWindowService() extends Mock implements SessionWindowService;

void main() {
  const project = ProjectSummary(id: "project-1", name: "Sesori", path: "/sesori", time: null);
  late StreamController<AllSessionsState> listStates;
  late BehaviorSubject<SessionWindowState> windowState;
  late SessionLaunchRepository launches;
  late int opened;
  late SessionWindowKey windowKey;
  final now = DateTime.now().millisecondsSinceEpoch;
  final earlier = testSession(id: "earlier", title: "Earlier work", updatedAt: now - 60000);
  final created = testSession(id: "created", title: "Fix the bug", updatedAt: now);

  AllSessionsState list({
    required List<Session> sessions,
    SessionListQuickFilter quickFilter = SessionListQuickFilter.all,
  }) {
    final running = quickFilter == SessionListQuickFilter.running;
    final rows = [
      for (final session in sessions)
        AllSessionsRow(
          sending: null,
          scheduledMark: const SessionScheduledMark.none(),
          session: session,
          project: project,
          isRunning: running,
          isUnseen: false,
          isAwaitingInput: false,
          isRetrying: false,
          backgroundTaskCount: 0,
          isInterrupted: false,
        ),
    ];
    return AllSessionsState(
      projectId: null,
      query: "",
      quickFilter: quickFilter,
      rows: rows,
      counts: SessionListChipCounts(all: sessions.length, running: running ? sessions.length : 0, unread: 0),
      loadMore: null,
      awaitingAnswer: false,
      anySessionAwaitingInput: false,
      failure: null,
      isLoading: false,
      scratchProjectId: null,
      defaultProjectId: project.id,
    );
  }

  SessionWindowState loaded({required List<Session> sessions}) => SessionWindowLoaded(
    sessions: sessions,
    counts: SessionPageCounts(all: sessions.length, running: 0, unread: 0),
    nextCursor: null,
    loadMore: SessionWindowLoadMore.idle,
    awaitingAnswer: false,
  );

  /// The sessions reach the window the launching rows read and the list's
  /// rows together, as one scope's window feeds both.
  void showSessions({
    required List<Session> sessions,
    SessionListQuickFilter quickFilter = SessionListQuickFilter.all,
  }) {
    windowKey = (projectId: null, query: null, filter: quickFilter);
    windowState.add(loaded(sessions: sessions));
    listStates.add(list(sessions: sessions, quickFilter: quickFilter));
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
    windowState = BehaviorSubject.seeded(loaded(sessions: sessions));
    addTearDown(windowState.close);
    final cubit = _MockAllSessionsCubit();
    whenListen(cubit, listStates.stream, initialState: list(sessions: sessions));
    when(() => cubit.mode).thenReturn(AllSessionsMode.active);
    when(() => cubit.setHiddenSessionIds(sessionIds: any(named: "sessionIds"))).thenReturn(null);
    final projects = _MockProjectListCubit();
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [project], folderProjects: [project], scratchProject: null),
    );
    final window = _MockSessionWindowService();
    when(() => window.state).thenAnswer((_) => windowState.stream);
    windowKey = (projectId: null, query: null, filter: SessionListQuickFilter.all);
    when(() => window.key).thenAnswer((_) => windowKey);
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
                      RepositoryProvider<SessionWindowService>.value(value: window),
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
                              openSession: _openNothing,
                              createSessionSearch: _searchNothing,
                            ),
                            createActions: ({required window}) => throw StateError("no row to act on"),
                            selectedSessionId: null,
                            showsLoadFailure: true,
                            showsSearchField: true,
                            disconnectedBuilder: ({required context, required state}) =>
                                const SliverToBoxAdapter(child: Text("Computer offline")),
                            emptyState: const Text("Nothing here"),
                            header: null,
                            endClearance: 0,
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
    // A row's motion runs from the frame after its update.
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
    // Lit, as the session is already at work.
    expect(
      tester.widget<PregoBreathing>(find.descendant(of: launchRow, matching: find.byType(PregoBreathing))).active,
      isTrue,
    );
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

  testWidgets("under Running a created session shows in its launching row's stead, which it takes back on All", (
    tester,
  ) async {
    await pumpList(tester, sessions: [earlier]);
    await startLaunch(tester);
    // The reply names the session before the list has it, so its launching
    // row holds it.
    launches.promote(launchId: "launch-1", session: created);
    await settle(tester);
    expect(launchRow, findsOneWidget);

    showSessions(sessions: [created], quickFilter: SessionListQuickFilter.running);
    await settle(tester);
    expect(launchRow, findsNothing, reason: "a launching row is not running yet");
    expect(find.text("Fix the bug"), findsOneWidget, reason: "the session is running, so it is listed");

    showSessions(sessions: [created, earlier]);
    await settle(tester);
    expect(launchRow, findsNothing);
    expect(find.text("Fix the bug"), findsOneWidget, reason: "only its session, not the launching row too");
  });

  testWidgets("under Running a session that may be a waiting launch's stays out until the launch names it", (
    tester,
  ) async {
    await pumpList(tester, sessions: [earlier]);
    await startLaunch(tester);
    // It arrives before the reply that names it.
    showSessions(sessions: [created, earlier]);
    await settle(tester);
    expect(launchRow, findsOneWidget);
    expect(find.text("Fix the bug"), findsOneWidget, reason: "only the launching row");

    showSessions(sessions: [created], quickFilter: SessionListQuickFilter.running);
    await settle(tester);
    expect(find.text("Fix the bug"), findsNothing);
    expect(find.text("No sessions match this filter"), findsOneWidget);

    launches.promote(launchId: "launch-1", session: created);
    // The filter's empty note fades out first, then the row comes in.
    await settle(tester);
    await settle(tester);
    expect(find.text("Fix the bug"), findsOneWidget);
  });

  testWidgets("under Running a session All never showed stays out until its waiting launch names it", (
    tester,
  ) async {
    await pumpList(tester, sessions: [earlier]);
    await startLaunch(tester);
    showSessions(sessions: [earlier], quickFilter: SessionListQuickFilter.running);
    await settle(tester);
    expect(find.text("Earlier work"), findsOneWidget, reason: "All showed it before the launch");

    // It reaches Running before All has it, and before the reply that names
    // it.
    showSessions(sessions: [created, earlier], quickFilter: SessionListQuickFilter.running);
    await settle(tester);
    expect(find.text("Fix the bug"), findsNothing, reason: "opening it now would find no handoff");
    expect(find.text("Earlier work"), findsOneWidget);

    launches.promote(launchId: "launch-1", session: created);
    await settle(tester);
    expect(find.text("Fix the bug"), findsOneWidget, reason: "named, it lists as an ordinary row");
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

void _openNothing({required String projectId, required String projectName, required Session session}) {}

SessionSearchCubit _searchNothing({
  required SessionWindowService window,
  required ProjectInventoryService projectInventory,
  required String? excludedSessionId,
}) => throw UnimplementedError("These tests do not send sessions");
