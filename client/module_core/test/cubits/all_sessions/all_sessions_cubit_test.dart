import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockProjectInventory() extends Mock implements ProjectInventoryService;

const _one = ProjectSummary(id: "one", name: "One", path: "/one", time: null);
const _two = ProjectSummary(id: "two", name: "Two", path: "/two", time: null);
const _scratch = ProjectSummary(id: "scratch", name: "No project", path: "/scratch", time: null);

const _running = SessionActivityInfo(
  mainAgentRunning: true,
  isRunning: true,
  lastUserActivityAt: null,
  updatedAt: null,
);

Session _session({required String id, required int updatedAt, String projectId = "one", String? title}) =>
    testSession(id: id, updatedAt: updatedAt, title: title ?? "Session $id").copyWith(projectID: projectId);

/// [count] sessions in one, from s0000, the newest, down.
List<Session> _sessions({required int count}) => [
  for (var index = 0; index < count; index++)
    _session(id: "s${index.toString().padLeft(4, "0")}", updatedAt: 1000000 - index),
];

/// A bridge serving `/sessions/page` for one mode over [sessions], the cursor
/// being the next row's index.
class _FakeBridge() {
  List<Session> sessions = const [];
  final List<SessionPageRequest> requests = [];

  /// Answers in place of the bridge, when set.
  Future<SessionPageResult> Function(SessionPageRequest request)? answer;

  Future<SessionPageResult> serve(SessionPageRequest request) async {
    requests.add(request);
    if (answer case final answer?) return await answer(request);
    final query = request.query;
    final listed = [
      for (final session in sessions)
        if ((request.projectId == null || session.projectID == request.projectId) &&
            (query == null ||
                searchWords(query: query).every((word) => (session.title ?? "").toLowerCase().contains(word))))
          session,
    ];
    final start = int.parse(request.cursor ?? "0");
    final end = (start + request.limit).clamp(0, listed.length);
    return SessionPageLoaded(
      page: SessionPageResponse(
        items: listed.sublist(start, end),
        nextCursor: end >= listed.length ? null : "$end",
        counts: SessionPageCounts(all: listed.length, running: 0, unread: 0),
      ),
    );
  }
}

void main() {
  late MockSessionRepository sessionRepository;
  late MockProjectRepository projectRepository;
  late MockConnectionService connection;
  late MockSseEventTracker activity;
  late FakeSessionUnseenTracker unseen;
  late FakeCatalogRescanService catalog;
  late _MockProjectInventory projectInventory;
  late BehaviorSubject<ProjectListState> inventory;
  late StreamController<SseEvent> events;
  late BehaviorSubject<ConnectionStatus> status;
  late ProjectListService projectListService;
  late SessionListFilterTracker filterTracker;
  late _FakeBridge bridge;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      const SessionPageRequest(
        mode: SessionPageMode.active,
        projectId: null,
        query: null,
        filter: SessionPageFilter.all,
        cursor: null,
        limit: 0,
      ),
    );
  });

  setUp(() {
    sessionRepository = MockSessionRepository();
    projectRepository = MockProjectRepository();
    connection = MockConnectionService();
    activity = MockSseEventTracker();
    unseen = FakeSessionUnseenTracker();
    catalog = FakeCatalogRescanService();
    projectInventory = _MockProjectInventory();
    events = StreamController.broadcast(sync: true);
    status = BehaviorSubject.seeded(
      ConnectionStatus.connected(
        config: const ServerConnectionConfig(relayHost: "relay", authToken: "t", bridgeId: "a"),
        health: testHealthResponse(),
      ),
    );
    bridge = _FakeBridge();
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(() => connection.status).thenAnswer((_) => status.stream);
    when(() => connection.currentStatus).thenAnswer((_) => status.value);
    inventory = BehaviorSubject.seeded(
      const ProjectListState.loaded(
        projects: [_one, _two, _scratch],
        folderProjects: [_one, _two],
        scratchProject: _scratch,
      ),
    );
    when(() => projectInventory.state).thenAnswer((_) => inventory.value);
    when(() => projectInventory.stateStream).thenAnswer((_) => inventory.stream);
    when(
      () => sessionRepository.getSessionPage(request: any(named: "request")),
    ).thenAnswer((invocation) => bridge.serve(invocation.namedArguments[#request] as SessionPageRequest));
    projectListService = ProjectListService(repository: MockProjectRepository());
    filterTracker = SessionListFilterTracker(connectionService: connection, projectListService: projectListService);
  });

  tearDown(() async {
    await filterTracker.dispose();
    await projectListService.dispose();
    await events.close();
    await status.close();
    await inventory.close();
    await activity.onDispose();
    await unseen.onDispose();
    await catalog.onDispose();
  });

  /// Runs [body] in fake time over a cubit on a new [mode] window, then
  /// disposes both there.
  void withCubit(
    void Function(AllSessionsCubit cubit, FakeAsync async) body, {
    AllSessionsMode mode = AllSessionsMode.active,
  }) => fakeAsync((async) {
    final window = SessionWindowService(
      mode: mode,
      projectInventory: projectInventory,
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      connectionService: connection,
      sseEventTracker: activity,
      sessionUnseenTracker: unseen,
      catalogRescanService: catalog,
    );
    final cubit = AllSessionsCubit(
      window: window,
      projectInventory: projectInventory,
      filterTracker: filterTracker,
      sseEventTracker: activity,
      sessionUnseenTracker: unseen,
    );
    async.flushMicrotasks();
    // Live changes reach the list a timer later.
    async.elapse(Duration.zero);
    body(cubit, async);
    unawaited(cubit.close());
    unawaited(window.dispose());
    async.flushMicrotasks();
  });

  List<String> ids(AllSessionsCubit cubit) => [for (final row in cubit.state.rows) row.session.id];

  test("the rows are the window's first page, each with its project and live state", () {
    bridge.sessions = [
      _session(id: "b", updatedAt: 3, projectId: "two"),
      _session(id: "a", updatedAt: 2),
      // A project the inventory does not list has nothing to name.
      _session(id: "stray", updatedAt: 1, projectId: "gone"),
    ];
    activity.emitSessionActivity({
      "one": {"a": _running},
    });
    withCubit((cubit, async) {
      expect(ids(cubit), ["b", "a"]);
      expect(cubit.state.rows.first.project, _two);
      expect(cubit.state.rows.last.isRunning, isTrue);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.loadMore, isNull);
      expect(cubit.state.counts, const SessionListChipCounts(all: 3, running: 0, unread: 0));

      activity.emitSessionActivity(const {});
      async.elapse(Duration.zero);
      expect(cubit.state.rows.last.isRunning, isFalse);
    });
  });

  test("near the end a page is appended, and the loader row leaves with the last one", () {
    bridge.sessions = _sessions(count: 250);
    withCubit((cubit, async) {
      expect(ids(cubit), hasLength(200));
      expect(cubit.state.loadMore, SessionWindowLoadMore.idle);

      unawaited(cubit.loadMore());
      async.elapse(Duration.zero);
      expect(ids(cubit), hasLength(250));
      expect(ids(cubit).take(200), [for (final session in bridge.sessions.take(200)) session.id]);
      expect(cubit.state.loadMore, isNull);
    });
  });

  test("hidden sessions leave the rows, and stay counted until the bridge says otherwise", () {
    bridge.sessions = [_session(id: "a", updatedAt: 2), _session(id: "b", updatedAt: 1)];
    withCubit((cubit, async) {
      cubit.setHiddenSessionIds(sessionIds: {"a"});
      expect(ids(cubit), ["b"]);
      expect(cubit.state.counts.all, 2);
    });
  });

  test("a query narrows the loaded rows at once, then the bridge's answer replaces them", () {
    bridge.sessions = [
      ..._sessions(count: 200),
      _session(id: "old", updatedAt: 1, title: "Deploy old"),
    ];
    withCubit((cubit, async) {
      cubit.setQuery(query: "deploy");
      expect(cubit.state.query, "deploy");
      expect(ids(cubit), isEmpty);
      expect(cubit.state.awaitingAnswer, isTrue);

      async.elapse(SessionWindowService.queryDelay);
      expect(bridge.requests.last.query, "deploy");
      expect(ids(cubit), ["old"]);
      expect(cubit.state.awaitingAnswer, isFalse);

      // A cleared query asks at once.
      cubit.setQuery(query: " ");
      async.elapse(Duration.zero);
      expect(bridge.requests.last.query, isNull);
      expect(ids(cubit), hasLength(200));
    });
  });

  test("a chip and a project filter are the window's key", () {
    bridge.sessions = [_session(id: "b", updatedAt: 2, projectId: "two"), _session(id: "a", updatedAt: 1)];
    withCubit((cubit, async) {
      cubit.selectProject(projectId: "two");
      expect(ids(cubit), ["b"]);
      cubit.setQuickFilter(filter: SessionListQuickFilter.running);
      async.elapse(Duration.zero);
      expect(bridge.requests.last.projectId, "two");
      expect(bridge.requests.last.filter, SessionPageFilter.running);
    });
  });

  test("the default project is the filter, otherwise No project, otherwise the newest session's", () {
    const noScratch = ProjectListState.loaded(
      projects: [_one, _two],
      folderProjects: [_one, _two],
      scratchProject: null,
    );
    inventory.add(noScratch);
    bridge.sessions = [
      _session(id: "b", updatedAt: 2, projectId: "two", title: "Beta"),
      _session(id: "a", updatedAt: 1, title: "Alpha"),
    ];
    withCubit((cubit, async) {
      expect(cubit.state.defaultProjectId, "two");

      // A search keeps the newest session read before it.
      cubit.setQuery(query: "alpha");
      async.elapse(SessionWindowService.queryDelay);
      expect(ids(cubit), ["a"]);
      expect(cubit.state.defaultProjectId, "two");

      cubit.selectProject(projectId: "one");
      expect(cubit.state.defaultProjectId, "one");

      inventory.add(
        const ProjectListState.loaded(
          projects: [_one, _two, _scratch],
          folderProjects: [_one, _two],
          scratchProject: _scratch,
        ),
      );
      cubit.selectProject(projectId: null);
      async.elapse(Duration.zero);
      expect(cubit.state.defaultProjectId, "scratch");
    });
  });

  test("the newest session of a project the inventory lacks is never the default", () {
    inventory.add(const ProjectListState.loaded(projects: [_one], folderProjects: [_one], scratchProject: null));
    bridge.sessions = [
      _session(id: "b", updatedAt: 2, projectId: "gone"),
      _session(id: "a", updatedAt: 1),
    ];
    withCubit((cubit, async) {
      expect(ids(cubit), ["a"]);
      expect(cubit.state.defaultProjectId, "one");
    });
  });

  test("a failed load is the list's failure, and Retry loads while it asks again", () {
    var fail = true;
    bridge.sessions = [_session(id: "a", updatedAt: 1)];
    bridge.answer = (request) async => fail
        ? SessionPageFailure(error: ApiError.generic())
        : await (_FakeBridge()..sessions = bridge.sessions).serve(request);
    withCubit((cubit, async) {
      expect(cubit.state.failure, isNotNull);
      expect(cubit.state.isLoading, isFalse);

      fail = false;
      unawaited(cubit.retry());
      expect(cubit.state.failure, isNull);
      expect(cubit.state.isLoading, isTrue);
      async.elapse(Duration.zero);
      expect(cubit.state.isLoading, isFalse);
      expect(ids(cubit), ["a"]);
    });
  });

  test("an archived list pages its own archived window", () {
    bridge.sessions = [
      testSession(id: "x", updatedAt: 1, archivedAt: DateTime(2026, 2)).copyWith(projectID: "one"),
    ];
    withCubit(mode: AllSessionsMode.archived, (cubit, async) {
      expect(cubit.mode, AllSessionsMode.archived);
      expect(bridge.requests.single.mode, SessionPageMode.archived);
      expect(ids(cubit), ["x"]);
    });
  });

  test("on a bridge without pages every project's sessions are listed", () {
    bridge.answer = (_) async => const SessionPageUnsupported();
    for (final (projectId, sessions) in [
      ("one", [_session(id: "a", updatedAt: 1)]),
      ("two", [_session(id: "b", updatedAt: 2, projectId: "two")]),
      ("scratch", <Session>[]),
    ]) {
      when(
        () => projectRepository.listSessions(projectId: projectId),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: sessions)));
    }
    withCubit((cubit, async) {
      expect(ids(cubit), ["b", "a"]);
      expect(cubit.state.loadMore, isNull);
      expect(cubit.state.counts.all, 2);

      // A typed query narrows once typing pauses; until then the rows stay
      // the same list.
      final rows = cubit.state.rows;
      cubit.setQuery(query: "Session a");
      expect(cubit.state.query, "Session a");
      expect(cubit.state.rows, same(rows));
      async.elapse(SessionWindowService.queryDelay);
      expect(ids(cubit), ["a"]);
    });
  });

  test("on a bridge without pages a project that fails to list is the list's failure, and Retry lists it", () {
    bridge.answer = (_) async => const SessionPageUnsupported();
    var fail = true;
    when(
      () => projectRepository.listSessions(projectId: "one"),
    ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [_session(id: "a", updatedAt: 1)])));
    when(() => projectRepository.listSessions(projectId: "two")).thenAnswer(
      (_) async => fail
          ? ApiResponse.error(ApiError.generic())
          : ApiResponse.success(
              SessionListResponse(
                items: [_session(id: "b", updatedAt: 2, projectId: "two")],
              ),
            ),
    );
    when(
      () => projectRepository.listSessions(projectId: "scratch"),
    ).thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: [])));
    withCubit((cubit, async) {
      expect(ids(cubit), ["a"]);
      expect(cubit.state.failure, isNotNull);

      fail = false;
      unawaited(cubit.retry());
      async.elapse(Duration.zero);
      expect(ids(cubit), ["b", "a"]);
      expect(cubit.state.failure, isNull);
    });
  });

  test("an unchanged resolve emits nothing", () {
    bridge.sessions = [_session(id: "a", updatedAt: 1)];
    withCubit((cubit, async) {
      final emitted = <AllSessionsState>[];
      final subscription = cubit.stream.listen(emitted.add);
      activity.emitSessionActivity(const {"two": {}});
      async.elapse(Duration.zero);
      expect(emitted, isEmpty);
      unawaited(subscription.cancel());
    });
  });
}
