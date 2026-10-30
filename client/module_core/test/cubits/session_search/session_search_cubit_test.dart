import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockProjectInventory() extends Mock implements ProjectInventoryService;

const _alpha = ProjectSummary(id: "alpha", name: "Alpha", path: "/alpha", time: null);
const _beta = ProjectSummary(id: "beta", name: "Beta", path: "/beta", time: null);

Session _session({required String id, required int updatedAt, required String title, String projectId = "alpha"}) =>
    testSession(id: id, updatedAt: updatedAt, title: title).copyWith(projectID: projectId);

/// 300 sessions in alpha, s000 the newest; s001 and s250 are titled
/// "Deploy …", so only s001 is in the window's first page.
List<Session> _bridgeSessions() => [
  for (var index = 0; index < 300; index++)
    _session(
      id: "s${index.toString().padLeft(3, "0")}",
      updatedAt: 1000 - index,
      title: switch (index) {
        1 => "Deploy new",
        250 => "Deploy old",
        _ => "Session $index",
      },
    ),
];

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
  late List<SessionPageRequest> requests;

  /// Answers each page request, the bridge's newest-first order applied.
  late Future<SessionPageResult> Function(SessionPageRequest request) answer;

  SessionPageResult page({required List<Session> sessions, required SessionPageRequest request}) {
    final query = request.query;
    final matching = [
      for (final session in sessions)
        if (query == null ||
            searchWords(query: query).every((word) => (session.title ?? "").toLowerCase().contains(word)))
          session,
    ];
    return SessionPageLoaded(
      page: SessionPageResponse(
        items: matching.take(request.limit).toList(),
        nextCursor: matching.length > request.limit ? "${request.limit}" : null,
        counts: SessionPageCounts(all: matching.length, running: 0, unread: 0),
      ),
    );
  }

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
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay", authToken: "t", bridgeId: "a"),
        health: HealthResponse(healthy: true, version: "1", filesystemAccessDegraded: false),
      ),
    );
    requests = [];
    final sessions = _bridgeSessions();
    answer = (request) async => page(sessions: sessions, request: request);
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(() => connection.status).thenAnswer((_) => status.stream);
    when(() => connection.currentStatus).thenAnswer((_) => status.value);
    inventory = BehaviorSubject.seeded(
      const ProjectListState.loaded(projects: [_alpha, _beta], folderProjects: [_alpha, _beta], scratchProject: null),
    );
    when(() => projectInventory.state).thenAnswer((_) => inventory.value);
    when(() => projectInventory.stateStream).thenAnswer((_) => inventory.stream);
    when(() => sessionRepository.getSessionPage(request: any(named: "request"))).thenAnswer((invocation) {
      final request = invocation.namedArguments[#request] as SessionPageRequest;
      requests.add(request);
      return answer(request);
    });
  });

  tearDown(() async {
    await events.close();
    await status.close();
    await inventory.close();
    await activity.onDispose();
    await unseen.onDispose();
    await catalog.onDispose();
  });

  SessionWindowService createWindow() => SessionWindowService(
    mode: AllSessionsMode.active,
    projectInventory: projectInventory,
    sessionRepository: sessionRepository,
    projectRepository: projectRepository,
    connectionService: connection,
    sseEventTracker: activity,
    sessionUnseenTracker: unseen,
    catalogRescanService: catalog,
  );

  List<String> ids(SessionSearchCubit cubit) => [for (final match in cubit.state.matches) match.session.id];

  /// The cubit's requests: a blank query's has no query, so they are told
  /// apart from the window's pages by their size.
  List<SessionPageRequest> searches() => [
    for (final request in requests)
      if (request.limit == SessionSearchCubit.limit) request,
  ];

  test("lists the newest loaded sessions once the window loads, with their projects", () {
    fakeAsync((async) {
      final window = createWindow();
      final cubit = SessionSearchCubit(window: window, projectInventory: projectInventory);
      expect(cubit.state.matches, isEmpty);

      async.flushMicrotasks();
      expect(ids(cubit), [for (var index = 0; index < 20; index++) "s${index.toString().padLeft(3, "0")}"]);
      expect(cubit.state.matches.first.project, _alpha);
      expect(cubit.state.isSearching, isFalse);

      unawaited(cubit.close());
      unawaited(window.dispose());
      async.flushMicrotasks();
    });
  });

  test("a blank query lists the newest sessions of every project, whatever the sidebar's key", () {
    fakeAsync((async) {
      final sessions = [
        _session(id: "b1", updatedAt: 2000, title: "Beta newest", projectId: "beta"),
        ..._bridgeSessions(),
      ];
      answer = (request) async => page(
        sessions: [
          for (final session in sessions)
            if (request.projectId == null || session.projectID == request.projectId) session,
        ],
        request: request,
      );
      final window = createWindow()..select(key: (projectId: "alpha", query: null, filter: SessionListQuickFilter.all));
      async.flushMicrotasks();
      expect((window.state.value as SessionWindowLoaded).sessions.first.id, "s000");
      requests.clear();

      final cubit = SessionSearchCubit(window: window, projectInventory: projectInventory);
      // The sidebar's rows show at once, while the bridge is asked.
      expect(ids(cubit).first, "s000");
      expect(cubit.state.isSearching, isTrue);
      final search = searches().single;
      expect(search.projectId, isNull);
      expect(search.query, isNull);
      expect(search.filter, SessionPageFilter.all);
      expect(search.cursor, isNull);

      async.flushMicrotasks();
      expect(ids(cubit), hasLength(20));
      expect(ids(cubit).take(2), ["b1", "s000"]);
      expect(cubit.state.matches.first.project, _beta);
      expect(cubit.state.isSearching, isFalse);

      // A cleared query brings the bridge's newest back at once.
      cubit.setQuery(query: "deploy");
      async.elapse(SessionSearchCubit.searchDelay);
      cubit.setQuery(query: " ");
      expect(ids(cubit).take(2), ["b1", "s000"]);

      unawaited(cubit.close());
      unawaited(window.dispose());
      async.flushMicrotasks();
    });
  });

  test("fills an empty list once the projects load after the rows", () {
    fakeAsync((async) {
      final loadedProjects = inventory.value;
      inventory.add(const ProjectListState.loading());
      final window = createWindow();
      final cubit = SessionSearchCubit(window: window, projectInventory: projectInventory);
      async.flushMicrotasks();
      expect(window.state.value, isA<SessionWindowLoaded>());
      expect(cubit.state.matches, isEmpty);

      inventory.add(loadedProjects);
      async.flushMicrotasks();
      expect(ids(cubit), hasLength(20));

      unawaited(cubit.close());
      unawaited(window.dispose());
      async.flushMicrotasks();
    });
  });

  test("shows the loaded rows' matches at once, then the bridge's 200 ms after the last keystroke", () {
    fakeAsync((async) {
      final window = createWindow();
      final cubit = SessionSearchCubit(window: window, projectInventory: projectInventory);
      async.flushMicrotasks();
      requests.clear();

      cubit.setQuery(query: "de");
      async.elapse(const Duration(milliseconds: 150));
      cubit.setQuery(query: "deploy");
      expect(ids(cubit), ["s001"]);
      expect(cubit.state.isSearching, isTrue);
      async.elapse(const Duration(milliseconds: 199));
      expect(searches(), isEmpty);

      async.elapse(const Duration(milliseconds: 1));
      expect(searches().single.query, "deploy");
      expect(ids(cubit), ["s001", "s250"]);
      expect(cubit.state.isSearching, isFalse);

      // The earlier answer's matches stay until the next one arrives.
      cubit.setQuery(query: "deploy old");
      expect(ids(cubit), ["s250"]);
      cubit.setQuery(query: "");
      expect(ids(cubit), hasLength(20));
      async.elapse(const Duration(seconds: 1));
      expect(searches(), hasLength(2));
      expect(searches().last.query, isNull);
      expect(cubit.state.isSearching, isFalse);

      unawaited(cubit.close());
      unawaited(window.dispose());
      async.flushMicrotasks();
    });
  });

  test("drops an answer for a query the user has typed past", () {
    fakeAsync((async) {
      final window = createWindow();
      final cubit = SessionSearchCubit(window: window, projectInventory: projectInventory);
      async.flushMicrotasks();
      final pending = <Completer<SessionPageResult>>[];
      answer = (_) {
        final completer = Completer<SessionPageResult>();
        pending.add(completer);
        return completer.future;
      };

      cubit.setQuery(query: "session");
      async.elapse(SessionSearchCubit.searchDelay);
      cubit.setQuery(query: "deploy");
      async.elapse(SessionSearchCubit.searchDelay);
      expect(pending, hasLength(2));

      pending[1].complete(
        SessionPageLoaded(
          page: SessionPageResponse(
            items: [_session(id: "s001", updatedAt: 999, title: "Deploy new")],
            nextCursor: null,
            counts: const SessionPageCounts(all: 1, running: 0, unread: 0),
          ),
        ),
      );
      async.flushMicrotasks();
      expect(ids(cubit), ["s001"]);
      pending[0].complete(
        SessionPageLoaded(
          page: SessionPageResponse(
            items: [_session(id: "s002", updatedAt: 998, title: "Session 2")],
            nextCursor: null,
            counts: const SessionPageCounts(all: 1, running: 0, unread: 0),
          ),
        ),
      );
      async.flushMicrotasks();
      expect(ids(cubit), ["s001"]);
      expect(cubit.state.isSearching, isFalse);

      unawaited(cubit.close());
      unawaited(window.dispose());
      async.flushMicrotasks();
    });
  });

  test("a failed search keeps the loaded rows' matches", () {
    fakeAsync((async) {
      final window = createWindow();
      final cubit = SessionSearchCubit(window: window, projectInventory: projectInventory);
      async.flushMicrotasks();
      answer = (_) async => SessionPageFailure(error: ApiError.generic());

      cubit.setQuery(query: "deploy");
      async.elapse(SessionSearchCubit.searchDelay);
      expect(ids(cubit), ["s001"]);
      expect(cubit.state.isSearching, isFalse);

      unawaited(cubit.close());
      unawaited(window.dispose());
      async.flushMicrotasks();
    });
  });

  test("on a bridge without pages, a blank query lists the newest of every project locally", () {
    fakeAsync((async) {
      answer = (_) async => const SessionPageUnsupported();
      when(() => projectRepository.listSessions(projectId: "alpha")).thenAnswer(
        (_) async => ApiResponse.success(SessionListResponse(items: _bridgeSessions())),
      );
      when(() => projectRepository.listSessions(projectId: "beta")).thenAnswer(
        (_) async => ApiResponse.success(
          SessionListResponse(
            items: [_session(id: "b1", updatedAt: 2000, title: "Beta", projectId: "beta")],
          ),
        ),
      );
      final window = createWindow();
      async.flushMicrotasks();
      window.select(key: (projectId: "alpha", query: null, filter: SessionListQuickFilter.all));
      expect((window.state.value as SessionWindowLoaded).sessions.first.id, "s000");
      requests.clear();

      final cubit = SessionSearchCubit(window: window, projectInventory: projectInventory);
      expect(ids(cubit), hasLength(20));
      expect(ids(cubit).take(2), ["b1", "s000"]);
      async.flushMicrotasks();
      expect(requests, isEmpty);
      expect(ids(cubit).take(2), ["b1", "s000"]);
      expect(cubit.state.isSearching, isFalse);

      unawaited(cubit.close());
      unawaited(window.dispose());
      async.flushMicrotasks();
    });
  });

  test("on a bridge without pages, it matches every session locally", () {
    fakeAsync((async) {
      answer = (_) async => const SessionPageUnsupported();
      when(() => projectRepository.listSessions(projectId: "alpha")).thenAnswer(
        (_) async => ApiResponse.success(SessionListResponse(items: _bridgeSessions())),
      );
      when(() => projectRepository.listSessions(projectId: "beta")).thenAnswer(
        (_) async => ApiResponse.success(
          SessionListResponse(
            items: [_session(id: "b1", updatedAt: 800, title: "Deploy beta", projectId: "beta")],
          ),
        ),
      );
      final window = createWindow();
      final cubit = SessionSearchCubit(window: window, projectInventory: projectInventory);
      async.flushMicrotasks();
      requests.clear();
      expect(ids(cubit), hasLength(20));
      expect(ids(cubit).take(2), ["s000", "s001"]);

      cubit.setQuery(query: "deploy");
      expect(ids(cubit), ["s001", "b1", "s250"]);
      expect(cubit.state.matches[1].project, _beta);
      async.elapse(SessionSearchCubit.searchDelay);
      expect(requests, isEmpty);
      expect(ids(cubit), ["s001", "b1", "s250"]);
      expect(cubit.state.isSearching, isFalse);

      unawaited(cubit.close());
      unawaited(window.dispose());
      async.flushMicrotasks();
    });
  });
}
