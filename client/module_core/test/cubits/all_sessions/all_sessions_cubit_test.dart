import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  const one = ProjectSummary(id: "one", name: "One", path: "/one", time: null);
  const two = ProjectSummary(id: "two", name: "Two", path: "/two", time: null);
  const running = SessionActivityInfo(mainAgentRunning: true, lastUserActivityAt: null, updatedAt: null);
  final sessionListService = SessionListService(
    repository: MockProjectRepository(),
    activityCalculator: const SessionActivityCalculator(),
  );
  late BehaviorSubject<Map<String, RecentSessionsEntry>> entries;
  late BehaviorSubject<ProjectListState> projects;
  late BehaviorSubject<ConnectionStatus> status;
  late ProjectListService projectListService;
  late SessionListFilterTracker tracker;
  late _MockRecentInventory recentInventory;
  late _MockProjectInventory projectInventory;

  ConnectionStatus connected({required String bridgeId}) => ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay", authToken: "t", bridgeId: bridgeId),
    health: testHealthResponse(),
  );

  setUpAll(registerAllFallbackValues);
  setUp(() {
    entries = BehaviorSubject.seeded(const {});
    projects = BehaviorSubject.seeded(
      const ProjectListState.loaded(projects: [one, two], folderProjects: [one, two], scratchProject: null),
      sync: true,
    );
    status = BehaviorSubject.seeded(connected(bridgeId: "a"));
    final connection = MockConnectionService();
    when(() => connection.status).thenAnswer((_) => status.stream);
    when(() => connection.currentStatus).thenAnswer((_) => status.value);
    projectListService = ProjectListService(
      repository: MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );
    tracker = SessionListFilterTracker(connectionService: connection, projectListService: projectListService);
    recentInventory = _MockRecentInventory();
    when(() => recentInventory.state).thenAnswer((_) => entries.stream);
    when(() => recentInventory.retry(projectId: any(named: "projectId"))).thenAnswer((_) async {});
    when(recentInventory.refresh).thenAnswer((_) async => true);
    projectInventory = _MockProjectInventory();
    when(() => projectInventory.state).thenAnswer((_) => projects.value);
    when(() => projectInventory.stateStream).thenAnswer((_) => projects.stream);
  });
  tearDown(() async {
    await tracker.dispose();
    await projectListService.dispose();
    await Future.wait([entries.close(), projects.close(), status.close()]);
  });

  AllSessionsCubit create({required AllSessionsMode mode}) {
    final cubit = AllSessionsCubit(
      mode: mode,
      recentInventory: recentInventory,
      projectInventory: projectInventory,
      filterTracker: tracker,
      sessionListService: sessionListService,
    );
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
    return cubit;
  }

  Session session({required String id, required ProjectSummary project, required int updatedAt}) =>
      testSession(id: id, updatedAt: updatedAt).copyWith(projectID: project.id);

  Session archived({required String id, required ProjectSummary project, required int archivedAt}) => testSession(
    id: id,
    updatedAt: 1,
    archivedAt: DateTime.fromMillisecondsSinceEpoch(archivedAt),
  ).copyWith(projectID: project.id);

  // The inventory's own projections, so active rows arrive running-first.
  RecentSessionsLoaded loaded({
    required List<Session> sessions,
    required Map<String, SessionActivityInfo> activity,
  }) {
    List<Session> projected({required SessionListFilter filter}) => sessionListService.visibleSessions(
      sessions: sessions,
      filter: filter,
      activityBySessionId: activity,
      listStateBySessionId: const {},
    );
    return RecentSessionsLoaded(
      sourceSessions: sessions,
      visibleSessions: projected(filter: SessionListFilter.active),
      archivedSessions: projected(filter: SessionListFilter.archived),
      activityBySessionId: activity,
      listStateBySessionId: const {},
    );
  }

  List<String> ids({required AllSessionsCubit cubit}) => [for (final row in cubit.state.rows) row.session.id];
  List<int> counts({required AllSessionsCubit cubit}) => [
    for (final filter in SessionListQuickFilter.values) cubit.state.counts.of(filter: filter),
  ];
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test("every listed project's active sessions merge newest first, without archived or unlisted ones", () {
    entries.add({
      one.id: loaded(
        sessions: [
          session(id: "a", project: one, updatedAt: 30),
          session(id: "b", project: one, updatedAt: 10),
          archived(id: "archived", project: one, archivedAt: 40),
        ],
        activity: const {},
      ),
      two.id: loaded(
        sessions: [
          session(id: "c", project: two, updatedAt: 20),
          session(id: "d", project: two, updatedAt: 5),
        ],
        activity: const {"d": running},
      ),
      "unlisted": loaded(
        sessions: [
          session(
            id: "e",
            project: const ProjectSummary(id: "unlisted", name: null, path: "/u", time: null),
            updatedAt: 50,
          ),
        ],
        activity: const {},
      ),
    });
    final cubit = create(mode: AllSessionsMode.active);

    expect(ids(cubit: cubit), ["a", "c", "b", "d"]);
    expect([for (final row in cubit.state.rows) row.project.id], [one.id, two.id, one.id, two.id]);
    expect(cubit.state.rows.last.isRunning, isTrue, reason: "running, and still placed by its update");
  });

  test("a status change never moves a row", () async {
    final sessions = [
      session(id: "a", project: one, updatedAt: 30),
      session(id: "b", project: one, updatedAt: 20),
      session(id: "c", project: one, updatedAt: 10),
    ];
    entries.add({one.id: loaded(sessions: sessions, activity: const {})});
    final cubit = create(mode: AllSessionsMode.active);
    expect(ids(cubit: cubit), ["a", "b", "c"]);

    entries.add({
      one.id: loaded(sessions: sessions, activity: const {"c": running}),
    });
    await settle();
    expect(ids(cubit: cubit), ["a", "b", "c"]);
    expect([for (final row in cubit.state.rows) row.isRunning], [false, false, true]);
  });

  test("the query narrows rows and counts, a chip only the rows, and hidden sessions leave both", () {
    entries.add({
      one.id: loaded(
        sessions: [
          testSession(id: "login", title: "Fix login", updatedAt: 40, unseen: true),
          testSession(id: "docs", title: "Docs", updatedAt: 20),
          testSession(id: "tests", title: "Fix tests", updatedAt: 10),
        ],
        activity: const {},
      ),
      two.id: loaded(
        sessions: [testSession(id: "build", title: "Fix build", updatedAt: 30).copyWith(projectID: two.id)],
        activity: const {"build": running},
      ),
    });
    final cubit = create(mode: AllSessionsMode.active)..setHiddenSessionIds(sessionIds: {"tests"});
    expect(ids(cubit: cubit), ["login", "build", "docs"]);
    expect(counts(cubit: cubit), [3, 1, 1]);

    cubit.setQuery(query: "fix");
    expect(ids(cubit: cubit), ["login", "build"]);
    expect(counts(cubit: cubit), [2, 1, 1]);

    cubit.setQuickFilter(filter: SessionListQuickFilter.running);
    expect(cubit.state.quickFilter, SessionListQuickFilter.running);
    expect(ids(cubit: cubit), ["build"]);
    expect(counts(cubit: cubit), [2, 1, 1]);

    cubit
      ..setHiddenSessionIds(sessionIds: const {})
      ..setQuickFilter(filter: SessionListQuickFilter.all);
    expect(ids(cubit: cubit), ["login", "build", "tests"]);
    expect(counts(cubit: cubit), [3, 1, 1]);
  });

  test("a selected project narrows the list until it leaves the list or the computer changes", () async {
    entries.add({
      one.id: loaded(
        sessions: [session(id: "a", project: one, updatedAt: 20)],
        activity: const {},
      ),
      two.id: loaded(
        sessions: [session(id: "b", project: two, updatedAt: 10)],
        activity: const {},
      ),
    });
    final cubit = create(mode: AllSessionsMode.active)..selectProject(projectId: two.id);
    // At once, so a list opened filtered never draws the previous filter.
    expect(cubit.state.projectId, two.id);
    expect(ids(cubit: cubit), ["b"]);

    projectListService.removeProjectAndPublish(projects: const [one, two], projectId: two.id);
    projects.add(const ProjectListState.loaded(projects: [one], folderProjects: [one], scratchProject: null));
    await settle();
    expect(cubit.state.projectId, isNull);
    expect(ids(cubit: cubit), ["a"]);

    cubit.selectProject(projectId: one.id);
    await settle();
    expect(cubit.state.projectId, one.id);
    status.add(connected(bridgeId: "b"));
    await settle();
    expect(cubit.state.projectId, isNull);
  });

  test("a selection emits once, and another list's selection still reaches this one", () async {
    final cubit = create(mode: AllSessionsMode.active);
    final other = create(mode: AllSessionsMode.archived);
    final emitted = <String?>[];
    final subscription = cubit.stream.listen((state) => emitted.add(state.projectId));
    addTearDown(subscription.cancel);

    cubit.selectProject(projectId: one.id);
    await settle();
    expect(emitted, [one.id]);

    other.selectProject(projectId: two.id);
    await settle();
    expect(emitted, [one.id, two.id]);
  });

  test("archived mode lists every project's archived sessions, most recently archived first", () {
    entries.add({
      one.id: loaded(
        sessions: [
          archived(id: "oldest", project: one, archivedAt: 10),
          archived(id: "newest", project: one, archivedAt: 30),
          session(id: "active", project: one, updatedAt: 60),
        ],
        activity: const {},
      ),
      two.id: loaded(
        sessions: [archived(id: "middle", project: two, archivedAt: 20)],
        activity: const {},
      ),
    });
    final cubit = create(mode: AllSessionsMode.archived);
    expect(ids(cubit: cubit), ["newest", "middle", "oldest"]);
    // The bridge publishes no event on archive, so opening reloads.
    verify(recentInventory.refresh).called(1);

    cubit.selectProject(projectId: one.id);
    expect(ids(cubit: cubit), ["newest", "oldest"]);
  });

  group("archived mode stays loading until its reload on open answers", () {
    late Completer<bool> reload;
    final noSessions = loaded(sessions: const [], activity: const {});

    setUp(() {
      // Archived during this run: the loaded inventory still holds it active.
      entries.add({
        one.id: loaded(
          sessions: [session(id: "a", project: one, updatedAt: 10)],
          activity: const {},
        ),
        two.id: noSessions,
      });
      reload = Completer<bool>();
      when(recentInventory.refresh).thenAnswer((_) => reload.future);
    });

    test("so a stale inventory never reads as empty", () async {
      final cubit = create(mode: AllSessionsMode.archived);
      expect(cubit.state.rows, isEmpty);
      expect(cubit.state.isLoading, isTrue);

      entries.add({
        one.id: loaded(
          sessions: [archived(id: "a", project: one, archivedAt: 20)],
          activity: const {},
        ),
        two.id: noSessions,
      });
      await settle();
      expect(ids(cubit: cubit), ["a"]);

      reload.complete(true);
      await settle();
      expect(ids(cubit: cubit), ["a"]);
      expect(cubit.state.isLoading, isFalse);
    });

    test("and reads as empty once it answers, even when it failed", () async {
      final cubit = create(mode: AllSessionsMode.archived);
      expect(cubit.state.isLoading, isTrue);

      reload.complete(false);
      await settle();
      expect(cubit.state.rows, isEmpty);
      expect(cubit.state.isLoading, isFalse, reason: "a failed reload keeps the rows already loaded");
    });
  });

  test("the default project is the filter, otherwise the newest session's, otherwise none", () async {
    final cubit = create(mode: AllSessionsMode.active);
    verifyNever(recentInventory.refresh);
    expect(cubit.state.defaultProjectId, isNull);

    entries.add({
      one.id: loaded(
        sessions: [session(id: "a", project: one, updatedAt: 10)],
        activity: const {},
      ),
      two.id: loaded(
        sessions: [session(id: "b", project: two, updatedAt: 20)],
        activity: const {},
      ),
    });
    await settle();
    expect(cubit.state.defaultProjectId, two.id);
    cubit.setQuery(query: "matches nothing");
    expect(cubit.state.defaultProjectId, two.id, reason: "the query narrows the rows, not the default");

    cubit.selectProject(projectId: one.id);
    await settle();
    expect(cubit.state.defaultProjectId, one.id);
  });

  test("without a filter the default waits until every project's sessions have loaded", () async {
    final older = loaded(
      sessions: [session(id: "a", project: one, updatedAt: 10)],
      activity: const {},
    );
    entries.add({one.id: older, two.id: RecentSessionsLoading()});
    final cubit = create(mode: AllSessionsMode.active);
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.defaultProjectId, isNull, reason: "the first project to answer is not yet the newest");

    cubit.selectProject(projectId: one.id);
    expect(cubit.state.defaultProjectId, one.id, reason: "a filter needs no sessions");
    cubit.selectProject(projectId: null);
    expect(cubit.state.defaultProjectId, isNull);

    entries.add({
      one.id: older,
      two.id: loaded(
        sessions: [session(id: "b", project: two, updatedAt: 20)],
        activity: const {},
      ),
    });
    await settle();
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.defaultProjectId, two.id);

    // A project that failed to load does not hold the default back.
    entries.add({one.id: older, two.id: const RecentSessionsFailed(reason: RemoteFailureReason.networkDown)});
    await settle();
    expect(cubit.state.defaultProjectId, one.id);
  });

  test("with No project the default is the filter, otherwise No project, even while sessions load", () async {
    const scratch = ProjectSummary(id: "scratch", name: null, path: "/scratch", time: null, kind: ProjectKind.scratch);
    projects.add(
      const ProjectListState.loaded(projects: [one, scratch], folderProjects: [one], scratchProject: scratch),
    );
    entries.add({
      one.id: loaded(
        sessions: [session(id: "a", project: one, updatedAt: 10)],
        activity: const {},
      ),
      scratch.id: RecentSessionsLoading(),
    });
    final cubit = create(mode: AllSessionsMode.active);
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.scratchProjectId, scratch.id);
    expect(cubit.state.defaultProjectId, scratch.id, reason: "the newest session's project is not the default");

    cubit.selectProject(projectId: one.id);
    expect(cubit.state.defaultProjectId, one.id);
  });

  test("a project that failed to load is a retry row beside the projects that loaded", () async {
    entries.add({
      one.id: loaded(
        sessions: [session(id: "a", project: one, updatedAt: 10)],
        activity: const {},
      ),
      two.id: const RecentSessionsFailed(reason: RemoteFailureReason.networkDown),
    });
    final cubit = create(mode: AllSessionsMode.active);
    expect(ids(cubit: cubit), ["a"]);
    expect(
      [for (final failure in cubit.state.failures) (failure.project.id, failure.reason)],
      [(two.id, RemoteFailureReason.networkDown)],
    );
    expect(cubit.state.isLoading, isFalse);
    await cubit.retry(projectId: two.id);
    verify(() => recentInventory.retry(projectId: two.id)).called(1);

    entries.add({...entries.value, two.id: RecentSessionsLoading()});
    await settle();
    expect(cubit.state.failures, isEmpty);
    expect(cubit.state.isLoading, isTrue);

    cubit.selectProject(projectId: one.id);
    await settle();
    expect(cubit.state.isLoading, isFalse, reason: "the filter leaves the loading project out");

    projects.add(const ProjectListState.loading());
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.rows, isEmpty);
  });
}

class _MockRecentInventory() extends Mock implements RecentSessionInventoryService;

class _MockProjectInventory() extends Mock implements ProjectInventoryService;
