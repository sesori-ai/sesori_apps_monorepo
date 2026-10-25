import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
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
  const project = ProjectSummary(id: "p1", name: "Project One", path: "/p1", time: null);

  AllSessionsState state({
    required String query,
    required List<AllSessionsFailure> failures,
    required List<AllSessionsRow> rows,
    SessionListChipCounts counts = const SessionListChipCounts(all: 0, running: 0, unread: 0),
  }) => AllSessionsState(
    projectId: null,
    query: query,
    quickFilter: SessionListQuickFilter.all,
    rows: rows,
    counts: counts,
    failures: failures,
    isLoading: false,
    defaultProjectId: null,
  );

  AllSessionsRow row({
    required String title,
    required DateTime updatedAt,
    required DateTime? archivedAt,
    required bool isRunning,
  }) => AllSessionsRow(
    session: testSession(
      id: title,
      title: title,
      updatedAt: updatedAt.millisecondsSinceEpoch,
      archivedAt: archivedAt,
    ),
    project: project,
    isRunning: isRunning,
    isUnseen: false,
    isAwaitingInput: false,
    isRetrying: false,
    backgroundTaskCount: 0,
  );

  late _MockProjectListCubit projects;

  Future<_MockAllSessionsCubit> pumpList(
    WidgetTester tester, {
    required AllSessionsState initial,
    AllSessionsMode mode = AllSessionsMode.archived,
    ProjectListState projectList = const ProjectListState.loaded(projects: [project]),
  }) async {
    final cubit = _MockAllSessionsCubit();
    whenListen(cubit, const Stream<AllSessionsState>.empty(), initialState: initial);
    when(() => cubit.mode).thenReturn(mode);
    when(() => cubit.retry(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    when(() => cubit.setHiddenSessionIds(sessionIds: any(named: "sessionIds"))).thenReturn(null);
    projects = _MockProjectListCubit();
    whenListen(projects, const Stream<ProjectListState>.empty(), initialState: projectList);
    when(() => projects.retryLoadProjects()).thenAnswer((_) async {});
    final inventory = _MockRecentSessionInventoryService();
    when(() => inventory.state).thenAnswer((_) => BehaviorSubject.seeded(const {}));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AllSessionsCubit>.value(value: cubit),
            BlocProvider<ProjectListCubit>.value(value: projects),
            BlocProvider(
              create: (_) => PendingSessionArchiveCubit(
                cleanupService: SessionCleanupService(repository: MockSessionRepository()),
              ),
            ),
            RepositoryProvider<RecentSessionInventoryService>.value(value: inventory),
            RepositoryProvider(create: (_) => idleSessionLaunchService()),
          ],
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                AllSessionsList(
                  onSessionTap: ({required row}) {},
                  actionDispatcher: const SessionListActionDispatcher(
                    deleteConfirmation: SessionDeleteConfirmation.sheet,
                    onSessionArchived: null,
                    onSessionDeleted: null,
                    onSessionMarkedUnread: null,
                  ),
                  createActionCubit: ({required projectId, required session}) => throw StateError("no row to act on"),
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
    );
    // A running row's loader never settles.
    await tester.pump();
    return cubit;
  }

  testWidgets("a project that failed to load gets a retry row instead of the empty state", (tester) async {
    final cubit = await pumpList(
      tester,
      initial: state(
        query: "",
        failures: const [AllSessionsFailure(project: project, reason: RemoteFailureReason.networkDown)],
        rows: const [],
      ),
    );
    expect(find.text("Couldn’t load Project One"), findsOneWidget);
    expect(find.text("Nothing here"), findsNothing);
    await tester.tap(find.text("Retry"));
    verify(() => cubit.retry(projectId: "p1")).called(1);
  });

  testWidgets("a query that matches nothing says so instead of the empty state", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "zzz", failures: const [], rows: const []),
    );
    expect(find.text("Nothing here"), findsNothing);
    expect(find.text("No matches"), findsOneWidget);
  });

  testWidgets("archived rows sit under their archive date, as the archived mode sorts", (tester) async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    await pumpList(
      tester,
      initial: state(
        query: "",
        failures: const [],
        rows: [
          row(title: "Archived today", archivedAt: today, updatedAt: yesterday, isRunning: false),
          // Still running, but an archive lists it by its archive date.
          row(title: "Archived yesterday", archivedAt: yesterday, updatedAt: today, isRunning: true),
        ],
      ),
    );

    double topOf(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text("Today"), findsOneWidget);
    expect(find.text("Yesterday"), findsOneWidget);
    expect(topOf("Today"), lessThan(topOf("Archived today")));
    expect(topOf("Archived today"), lessThan(topOf("Yesterday")));
    expect(topOf("Yesterday"), lessThan(topOf("Archived yesterday")));
    // Archived has no status chips.
    expect(find.byKey(const Key("session-list-filter-all")), findsNothing);
  });

  testWidgets("with nothing to show the empty state fills the list", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "", failures: const [], rows: const []),
    );
    expect(find.text("Nothing here"), findsOneWidget);
  });

  testWidgets("Archived shows a failed project list with Retry, not the empty state", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "", failures: const [], rows: const []),
      projectList: const ProjectListState.failed(reason: RemoteFailureReason.networkDown),
    );
    expect(find.text("Failed to load projects"), findsOneWidget);
    expect(find.text("Nothing here"), findsNothing);

    await tester.tap(find.text("Retry"));
    verify(() => projects.retryLoadProjects()).called(1);
  });

  testWidgets("Archived shows the disconnected computer, not the empty state", (tester) async {
    await pumpList(
      tester,
      initial: state(query: "", failures: const [], rows: const []),
      projectList: const ProjectListState.bridgeDisconnected(hasRegisteredBridges: true),
    );
    expect(find.text("Computer offline"), findsOneWidget);
    expect(find.text("Nothing here"), findsNothing);
  });

  testWidgets("the active list adds the status chips over its rows", (tester) async {
    final now = DateTime.now();
    await pumpList(
      tester,
      mode: AllSessionsMode.active,
      initial: state(
        query: "",
        failures: const [],
        rows: [row(title: "Fix the parser", updatedAt: now, archivedAt: null, isRunning: false)],
        counts: const SessionListChipCounts(all: 1, running: 0, unread: 0),
      ),
    );
    expect(find.text("All · 1"), findsOneWidget);
    expect(find.byKey(const Key("session-list-filter-running")), findsOneWidget);
    expect(find.text("Fix the parser"), findsOneWidget);
    // Unfiltered, a row names its project.
    expect(find.text("Project One"), findsOneWidget);
  });
}
