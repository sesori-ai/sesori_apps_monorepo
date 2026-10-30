import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _MockProjectInventory() extends Mock implements ProjectInventoryService;

const _alpha = ProjectSummary(id: "alpha", name: "Alpha", path: "/alpha", time: null);
const _beta = ProjectSummary(id: "beta", name: "Beta", path: "/beta", time: null);
const _gamma = ProjectSummary(id: "gamma", name: "Gamma", path: "/gamma", time: null);

ProjectListState _inventory({required List<ProjectSummary> projects}) =>
    ProjectListState.loaded(projects: projects, folderProjects: projects, scratchProject: null);

const _health = HealthResponse(healthy: true, version: "1", filesystemAccessDegraded: false);

ConnectionStatus _connected({required String bridgeId}) => ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "relay", authToken: "t", bridgeId: bridgeId),
  health: _health,
);

Session _session({
  required String id,
  required int updatedAt,
  String projectId = "alpha",
  String? title,
  bool unseen = false,
}) => testSession(id: id, updatedAt: updatedAt, title: title ?? "Session $id", unseen: unseen).copyWith(
  projectID: projectId,
);

/// [count] sessions in alpha, from s0000, the newest, down.
List<Session> _sessions({required int count}) => [
  for (var index = 0; index < count; index++)
    _session(id: "s${index.toString().padLeft(4, "0")}", updatedAt: 1000000 - index),
];

/// A bridge serving `/sessions/page` over [sessions]: newest first, the
/// cursor being the next row's index.
class _FakeBridge() {
  List<Session> sessions = const [];
  Set<String> runningIds = const {};
  final List<SessionPageRequest> requests = [];

  /// Answers in place of the bridge, when set.
  Future<SessionPageResult> Function(SessionPageRequest request)? answer;

  Future<SessionPageResult> serve(SessionPageRequest request) async {
    requests.add(request);
    if (answer case final answer?) return await answer(request);
    final query = request.query;
    final counted = [
      for (final session in sessions)
        if ((request.projectId == null || session.projectID == request.projectId) &&
            (query == null ||
                searchWords(query: query).every(
                  (word) =>
                      (session.title ?? "").toLowerCase().contains(word) ||
                      session.projectID.toLowerCase().contains(word),
                )))
          session,
    ]..sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));
    final listed = counted
        .where(
          (session) => switch (request.filter) {
            SessionPageFilter.all => true,
            SessionPageFilter.running => runningIds.contains(session.id),
            SessionPageFilter.unread => session.unseen,
          },
        )
        .toList();
    final start = int.parse(request.cursor ?? "0");
    final end = (start + request.limit).clamp(0, listed.length);
    return SessionPageLoaded(
      page: SessionPageResponse(
        items: request.limit == 0 ? const [] : listed.sublist(start, end),
        nextCursor: request.limit == 0 || end >= listed.length ? null : "$end",
        counts: SessionPageCounts(
          all: counted.length,
          running: counted.where((session) => runningIds.contains(session.id)).length,
          unread: counted.where((session) => session.unseen).length,
        ),
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
    status = BehaviorSubject.seeded(_connected(bridgeId: "a"));
    bridge = _FakeBridge();
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(() => connection.status).thenAnswer((_) => status.stream);
    when(() => connection.currentStatus).thenAnswer((_) => status.value);
    inventory = BehaviorSubject.seeded(_inventory(projects: [_alpha, _beta]));
    when(() => projectInventory.state).thenAnswer((_) => inventory.value);
    when(() => projectInventory.stateStream).thenAnswer((_) => inventory.stream);
    when(
      () => sessionRepository.getSessionPage(request: any(named: "request")),
    ).thenAnswer((invocation) => bridge.serve(invocation.namedArguments[#request] as SessionPageRequest));
  });

  tearDown(() async {
    await events.close();
    await status.close();
    await inventory.close();
    await activity.onDispose();
    await unseen.onDispose();
    await catalog.onDispose();
  });

  SessionWindowService create({AllSessionsMode mode = AllSessionsMode.active}) => SessionWindowService(
    mode: mode,
    projectInventory: projectInventory,
    sessionRepository: sessionRepository,
    projectRepository: projectRepository,
    connectionService: connection,
    sseEventTracker: activity,
    sessionUnseenTracker: unseen,
    catalogRescanService: catalog,
  );

  SessionWindowLoaded loaded(SessionWindowService window) => switch (window.state.value) {
    final SessionWindowLoaded loaded => loaded,
    final other => throw StateError("Expected a loaded window, got $other"),
  };

  List<String> ids(SessionWindowService window) => [for (final session in loaded(window).sessions) session.id];

  void emit(SesoriSseEvent data) => events.add(SseEvent(data: data));

  /// Runs [body] in fake time, then disposes [window] there.
  void inFakeTime(void Function(FakeAsync async) body) => fakeAsync((async) {
    body(async);
    async.flushMicrotasks();
  });

  group("paging", () {
    test("loads the newest page once connected, seeding unseen per project", () {
      inFakeTime((async) {
        bridge.sessions = [
          ..._sessions(count: 250),
          _session(id: "b1", updatedAt: 2000000, projectId: "beta", unseen: true),
        ];
        final window = create();
        expect(window.state.value, isA<SessionWindowLoading>());
        async.flushMicrotasks();

        expect(
          bridge.requests.single,
          const SessionPageRequest(
            mode: SessionPageMode.active,
            projectId: null,
            query: null,
            filter: SessionPageFilter.all,
            cursor: null,
            limit: SessionWindowService.pageSize,
          ),
        );
        expect(ids(window), hasLength(200));
        expect(ids(window).first, "b1");
        expect(loaded(window).nextCursor, "200");
        expect(loaded(window).counts, const SessionPageCounts(all: 251, running: 0, unread: 1));
        expect(unseen.currentSessionUnseen["beta"], {"b1": (unseen: true, lastUserActivityAt: null)});
        expect(unseen.currentSessionUnseen["alpha"], hasLength(199));
        unawaited(window.dispose());
      });
    });

    test("loadMore appends the next page without duplicates and stops at the end", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 250);
        final window = create();
        async.flushMicrotasks();
        // The bridge repeats a row the window already holds.
        final repeated = bridge.sessions[199];
        bridge.answer = (request) async {
          final result = await (_FakeBridge()..sessions = bridge.sessions).serve(request);
          return switch (result) {
            SessionPageLoaded(:final page) => SessionPageLoaded(
              page: SessionPageResponse(
                items: [repeated, ...page.items],
                nextCursor: page.nextCursor,
                counts: page.counts,
              ),
            ),
            _ => result,
          };
        };

        unawaited(window.loadMore());
        expect(loaded(window).loadMore, SessionWindowLoadMore.loading);
        async.flushMicrotasks();

        expect(bridge.requests.last.cursor, "200");
        expect(ids(window), hasLength(250));
        expect(ids(window).toSet(), hasLength(250));
        expect(loaded(window).nextCursor, isNull);
        expect(loaded(window).loadMore, SessionWindowLoadMore.idle);

        unawaited(window.loadMore());
        async.flushMicrotasks();
        expect(bridge.requests, hasLength(2));
        unawaited(window.dispose());
      });
    });

    test("a failed page keeps the rows and marks loadMore failed; the next call retries", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 250);
        final window = create();
        async.flushMicrotasks();
        bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());

        unawaited(window.loadMore());
        async.flushMicrotasks();
        expect(ids(window), hasLength(200));
        expect(loaded(window).loadMore, SessionWindowLoadMore.failed);

        bridge.answer = null;
        unawaited(window.loadMore());
        async.flushMicrotasks();
        expect(ids(window), hasLength(250));
        unawaited(window.dispose());
      });
    });

    test("a failed reload in place of a page offers Retry rather than asking again", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 250);
        final window = create();
        async.flushMicrotasks();
        // A failed reload leaves the rows outdated, so the next page reloads them.
        bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());
        unawaited(window.reload());
        async.flushMicrotasks();
        expect(loaded(window).loadMore, SessionWindowLoadMore.idle);

        bridge.requests.clear();
        unawaited(window.loadMore());
        async.flushMicrotasks();
        expect(bridge.requests, hasLength(1));
        expect(loaded(window).loadMore, SessionWindowLoadMore.failed);
        bridge.answer = null;
        unawaited(window.dispose());
      });
    });

    test("a page asked for while the bridge is away fails at once, and the reconnect loads it once", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 250);
        final window = create();
        async.flushMicrotasks();
        bridge.requests.clear();

        status.add(const ConnectionStatus.disconnected());
        async.flushMicrotasks();
        unawaited(window.loadMore());
        expect(loaded(window).loadMore, SessionWindowLoadMore.failed);
        unawaited(window.loadMore());
        async.flushMicrotasks();
        expect(bridge.requests, isEmpty);

        status.add(_connected(bridgeId: "a"));
        async.flushMicrotasks();
        expect([for (final request in bridge.requests) request.cursor], ["200"]);
        expect(ids(window), hasLength(250));
        expect(loaded(window).loadMore, SessionWindowLoadMore.idle);
        unawaited(window.dispose());
      });
    });

    test("a page on its way when the bridge leaves offers Retry at once, and the reconnect asks again", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 250);
        final window = create();
        async.flushMicrotasks();
        final lost = Completer<SessionPageResult>();
        bridge.answer = (_) => lost.future;
        unawaited(window.loadMore());
        async.flushMicrotasks();
        expect(loaded(window).loadMore, SessionWindowLoadMore.loading);

        status.add(const ConnectionStatus.disconnected());
        async.flushMicrotasks();
        expect(loaded(window).loadMore, SessionWindowLoadMore.failed);

        bridge.answer = null;
        bridge.requests.clear();
        status.add(_connected(bridgeId: "a"));
        async.flushMicrotasks();
        expect([for (final request in bridge.requests) request.cursor], ["200"]);
        expect(ids(window), hasLength(250));

        // The abandoned request's late answer changes nothing.
        lost.complete(SessionPageFailure(error: ApiError.generic()));
        async.flushMicrotasks();
        expect(loaded(window).loadMore, SessionWindowLoadMore.idle);
        unawaited(window.dispose());
      });
    });

    test("a reload on its way when the bridge leaves, even over a page, runs again on reconnect", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 250);
        final window = create();
        async.flushMicrotasks();
        final lost = Completer<SessionPageResult>();
        bridge.answer = (_) => lost.future;
        unawaited(window.loadMore());
        connection.emitDataMayBeStale();
        async.flushMicrotasks();

        status.add(const ConnectionStatus.disconnected());
        async.flushMicrotasks();
        expect(loaded(window).loadMore, SessionWindowLoadMore.failed);

        bridge.answer = null;
        bridge.sessions = [_session(id: "new", updatedAt: 2000000), ...bridge.sessions];
        bridge.requests.clear();
        status.add(_connected(bridgeId: "a"));
        async.flushMicrotasks();
        expect(
          [for (final request in bridge.requests) (request.cursor, request.limit)],
          [(null, SessionWindowService.pageSize)],
        );
        expect(ids(window).first, "new");

        // The abandoned requests' late answers change nothing.
        lost.complete(SessionPageFailure(error: ApiError.generic()));
        async.flushMicrotasks();
        expect(ids(window).first, "new");
        expect(loaded(window).loadMore, SessionWindowLoadMore.idle);
        unawaited(window.dispose());
      });
    });

    test("a key narrowed to no rows whose answer fails shows the failure", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 3);
        final window = create();
        async.flushMicrotasks();
        bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());
        window.select(key: (projectId: null, query: "nothing", filter: SessionListQuickFilter.all));
        expect(ids(window), isEmpty);
        async.elapse(SessionWindowService.queryDelay);
        expect(window.state.value, isA<SessionWindowFailed>());
        bridge.answer = null;
        unawaited(window.dispose());
      });
    });
  });

  group("reload", () {
    test("refetches 1,500 loaded rows in two requests and swaps them in once", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 1500);
        final window = create();
        async.flushMicrotasks();
        for (var page = 0; page < 7; page++) {
          unawaited(window.loadMore());
          async.flushMicrotasks();
        }
        expect(ids(window), hasLength(1500));
        bridge.requests.clear();
        bridge.sessions = [_session(id: "new", updatedAt: 2000000), ...bridge.sessions];
        final emitted = <SessionWindowState>[];
        final subscription = window.state.skip(1).listen(emitted.add);
        async.flushMicrotasks();

        bool? succeeded;
        unawaited(window.reload().then((value) => succeeded = value));
        async.flushMicrotasks();

        expect(
          [for (final request in bridge.requests) (request.cursor, request.limit)],
          [
            (null, 1000),
            ("1000", 500),
          ],
        );
        expect(succeeded, isTrue);
        expect(emitted, hasLength(1));
        expect(ids(window).first, "new");
        expect(ids(window), hasLength(1500));
        expect(loaded(window).nextCursor, "1500");
        unawaited(subscription.cancel());
        unawaited(window.dispose());
      });
    });

    test("catalog changes and stale data reload; a failed reload keeps the rows", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 3);
        final window = create();
        async.flushMicrotasks();

        catalog.emitCatalogChanged();
        async.flushMicrotasks();
        connection.emitDataMayBeStale();
        async.flushMicrotasks();
        expect(bridge.requests, hasLength(3));

        bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());
        bool? succeeded;
        unawaited(window.reload().then((value) => succeeded = value));
        async.flushMicrotasks();
        expect(succeeded, isFalse);
        expect(ids(window), hasLength(3));
        unawaited(window.dispose());
      });
    });

    test("a reload that failed while disconnected runs again on reconnect", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 1);
        final window = create();
        async.flushMicrotasks();

        status.add(const ConnectionStatus.disconnected());
        bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());
        connection.emitDataMayBeStale();
        async.flushMicrotasks();
        expect(ids(window), ["s0000"]);

        bridge.answer = null;
        bridge.sessions = _sessions(count: 2);
        status.add(_connected(bridgeId: "a"));
        async.flushMicrotasks();
        expect(ids(window), ["s0000", "s0001"]);

        // A plain reconnect after a successful load relies on the replayed events.
        bridge.requests.clear();
        status.add(const ConnectionStatus.disconnected());
        status.add(_connected(bridgeId: "a"));
        async.flushMicrotasks();
        expect(bridge.requests, isEmpty);
        unawaited(window.dispose());
      });
    });

    test("after a failed key change, loadMore reloads from the head instead of the old cursor", () {
      inFakeTime((async) {
        bridge.sessions = [
          ..._sessions(count: 250),
          _session(id: "b1", updatedAt: 1, projectId: "beta"),
        ];
        final window = create();
        async.flushMicrotasks();
        window.select(key: (projectId: "alpha", query: null, filter: SessionListQuickFilter.all));
        async.flushMicrotasks();
        expect(loaded(window).nextCursor, isNotNull);

        bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());
        window.select(key: (projectId: null, query: null, filter: SessionListQuickFilter.all));
        async.flushMicrotasks();
        bridge.answer = null;
        bridge.requests.clear();

        unawaited(window.loadMore());
        async.flushMicrotasks();
        expect(bridge.requests.first.cursor, isNull);
        expect(bridge.requests.first.projectId, isNull);
        expect(loaded(window).loadMore, SessionWindowLoadMore.idle);
        unawaited(window.dispose());
      });
    });

    test("a changed project set reloads the pages", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 1);
        final window = create();
        async.flushMicrotasks();
        bridge.requests.clear();

        inventory.add(_inventory(projects: [_alpha, _beta]));
        async.flushMicrotasks();
        expect(bridge.requests, isEmpty);
        inventory.add(_inventory(projects: [_alpha]));
        async.flushMicrotasks();
        expect(bridge.requests.single.cursor, isNull);
        unawaited(window.dispose());
      });
    });

    test("a first load that fails shows the failure, and a reconnect retries", () {
      inFakeTime((async) {
        bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());
        final window = create();
        async.flushMicrotasks();
        expect(window.state.value, isA<SessionWindowFailed>());

        bridge.answer = null;
        bridge.sessions = _sessions(count: 1);
        status.add(const ConnectionStatus.disconnected());
        async.flushMicrotasks();
        status.add(_connected(bridgeId: "a"));
        async.flushMicrotasks();
        expect(ids(window), ["s0000"]);
        unawaited(window.dispose());
      });
    });
  });

  group("key", () {
    test("narrows the loaded rows at once, and asks the bridge 250 ms after typing stops", () {
      inFakeTime((async) {
        bridge.sessions = [
          _session(id: "fix", updatedAt: 3, title: "Fix the header"),
          _session(id: "add", updatedAt: 2, title: "Add a footer"),
          _session(id: "beta-fix", updatedAt: 1, title: "Fix beta", projectId: "beta"),
        ];
        final window = create();
        async.flushMicrotasks();
        bridge.requests.clear();

        window.select(key: (projectId: null, query: "fi", filter: SessionListQuickFilter.all));
        window.select(key: (projectId: null, query: "fix", filter: SessionListQuickFilter.all));
        expect(ids(window), ["fix", "beta-fix"]);
        // The project's own name matches too.
        window.select(key: (projectId: null, query: "fix beta", filter: SessionListQuickFilter.all));
        expect(ids(window), ["beta-fix"]);
        expect(loaded(window).awaitingAnswer, isTrue);
        async.elapse(const Duration(milliseconds: 249));
        expect(bridge.requests, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(bridge.requests.single.query, "fix beta");
        expect(ids(window), ["beta-fix"]);
        expect(loaded(window).awaitingAnswer, isFalse);

        // A failed answer leaves the narrowed rows as all there is.
        bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());
        window.select(key: (projectId: null, query: "beta", filter: SessionListQuickFilter.all));
        async.elapse(SessionWindowService.queryDelay);
        expect(ids(window), ["beta-fix"]);
        expect(loaded(window).awaitingAnswer, isFalse);
        bridge.answer = null;

        bridge.requests.clear();
        window.select(key: (projectId: null, query: null, filter: SessionListQuickFilter.all));
        async.flushMicrotasks();
        expect(bridge.requests.single.query, isNull);
        expect(ids(window), ["fix", "add", "beta-fix"]);
        unawaited(window.dispose());
      });
    });

    test("a project or chip change asks at once, narrowing by the trackers first", () {
      inFakeTime((async) {
        bridge.sessions = [
          _session(id: "running", updatedAt: 3),
          _session(id: "unread", updatedAt: 2, unseen: true),
          _session(id: "beta", updatedAt: 1, projectId: "beta"),
        ];
        bridge.runningIds = {"running"};
        activity.emitSessionActivity({
          "alpha": {"running": const SessionActivityInfo(isRunning: true, lastUserActivityAt: null, updatedAt: null)},
        });
        final window = create();
        async.flushMicrotasks();
        bridge.requests.clear();
        final completer = Completer<SessionPageResult>();
        bridge.answer = (_) => completer.future;

        window.select(key: (projectId: null, query: null, filter: SessionListQuickFilter.running));
        expect(ids(window), ["running"]);
        expect(bridge.requests.single.filter, SessionPageFilter.running);
        window.select(key: (projectId: "alpha", query: null, filter: SessionListQuickFilter.unread));
        expect(ids(window), isEmpty);
        expect(bridge.requests.last.projectId, "alpha");
        expect(bridge.requests, hasLength(2));
        unawaited(window.dispose());
      });
    });

    test("drops the answer for a key the user has moved past", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 2);
        final window = create();
        async.flushMicrotasks();
        final stale = Completer<SessionPageResult>();
        bridge.answer = (_) => stale.future;
        window.select(key: (projectId: "beta", query: null, filter: SessionListQuickFilter.all));
        bridge.answer = null;
        window.select(key: (projectId: "alpha", query: null, filter: SessionListQuickFilter.all));
        async.flushMicrotasks();
        expect(ids(window), ["s0000", "s0001"]);

        stale.complete(
          SessionPageLoaded(
            page: SessionPageResponse(
              items: [_session(id: "beta-only", updatedAt: 1, projectId: "beta")],
              nextCursor: null,
              counts: const SessionPageCounts(all: 1, running: 0, unread: 0),
            ),
          ),
        );
        async.flushMicrotasks();
        expect(ids(window), ["s0000", "s0001"]);
        unawaited(window.dispose());
      });
    });
  });

  group("live updates", () {
    test("fresh user activity makes a loaded session the newest", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 3);
        final window = create();
        async.flushMicrotasks();
        expect(ids(window), ["s0000", "s0001", "s0002"]);

        unseen.emitSessionUnseen({
          "alpha": {"s0002": (unseen: false, lastUserActivityAt: 2000000)},
        });
        async.flushMicrotasks();
        expect(ids(window), ["s0002", "s0000", "s0001"]);
        expect(loaded(window).sessions.first.time?.updated, 2000000);
        unawaited(window.dispose());
      });
    });
    test("insert in range, skip rows beyond it, and remove what stops matching", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 250);
        final window = create();
        async.flushMicrotasks();

        emit(SesoriSseEvent.sessionCreated(info: _session(id: "newest", updatedAt: 2000000)));
        expect(ids(window).first, "newest");
        // Older than every loaded row while more pages exist: a later page brings it.
        emit(SesoriSseEvent.sessionCreated(info: _session(id: "ancient", updatedAt: 1)));
        expect(ids(window), isNot(contains("ancient")));
        // Children never list.
        emit(
          SesoriSseEvent.sessionCreated(
            info: testSession(id: "child", parentID: "newest", updatedAt: 3000000).copyWith(projectID: "alpha"),
          ),
        );
        expect(ids(window), isNot(contains("child")));

        window.select(key: (projectId: null, query: "session", filter: SessionListQuickFilter.all));
        async.elapse(SessionWindowService.queryDelay);
        expect(ids(window), contains("s0001"));
        emit(
          SesoriSseEvent.sessionUpdated(
            info: _session(id: "s0001", updatedAt: 999999, title: "Renamed"),
          ),
        );
        expect(ids(window), isNot(contains("s0001")));
        emit(SesoriSseEvent.sessionDeleted(info: bridge.sessions.first));
        expect(ids(window), isNot(contains("s0000")));
        unawaited(window.dispose());
      });
    });

    test("an update keeps the last loaded row while more pages exist", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 250);
        final window = create();
        async.flushMicrotasks();
        final last = bridge.sessions[199];

        emit(SesoriSseEvent.sessionUpdated(info: last.copyWith(title: "Renamed")));
        expect(ids(window), hasLength(200));
        expect(loaded(window).sessions.last.title, "Renamed");
        unawaited(window.dispose());
      });
    });

    test("anything that matches is in range once no page follows", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 2);
        final window = create();
        async.flushMicrotasks();

        emit(SesoriSseEvent.sessionCreated(info: _session(id: "older", updatedAt: 1)));
        expect(ids(window), ["s0000", "s0001", "older"]);
        unawaited(window.dispose());
      });
    });

    test("events during a load are re-applied over its answer", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 2);
        final window = create();
        async.flushMicrotasks();
        final answer = Completer<SessionPageResult>();
        bridge.answer = (_) => answer.future;
        unawaited(window.reload());

        emit(SesoriSseEvent.sessionDeleted(info: bridge.sessions.first));
        emit(SesoriSseEvent.sessionCreated(info: _session(id: "created", updatedAt: 2000000)));
        // The answer was read before both events.
        answer.complete(_snapshot(bridge.sessions));
        async.flushMicrotasks();

        expect(ids(window), ["created", "s0001"]);
        unawaited(window.dispose());
      });
    });

    test("activity on a chip reloads its rows, and every change refreshes the counts, after a second", () {
      inFakeTime((async) {
        bridge.sessions = _sessions(count: 2);
        final window = create();
        async.flushMicrotasks();
        bridge.requests.clear();

        emit(SesoriSseEvent.sessionCreated(info: _session(id: "a", updatedAt: 2000000)));
        emit(SesoriSseEvent.sessionCreated(info: _session(id: "b", updatedAt: 2000001)));
        async.elapse(const Duration(milliseconds: 999));
        expect(bridge.requests, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        expect(bridge.requests.single.limit, 0);

        window.select(key: (projectId: null, query: null, filter: SessionListQuickFilter.running));
        async.flushMicrotasks();
        bridge.requests.clear();
        activity.emitSessionActivity({
          "alpha": {"s0000": const SessionActivityInfo(isRunning: true, lastUserActivityAt: null, updatedAt: null)},
        });
        emit(
          const SesoriSseEvent.sessionUnseenChanged(
            projectID: "alpha",
            sessionId: "s0001",
            unseen: true,
            projectHasUnseenChanges: true,
            lastUserActivityAt: null,
          ),
        );
        async.elapse(SessionWindowService.liveRefreshDelay);
        expect([for (final request in bridge.requests) request.limit], [SessionWindowService.pageSize]);
        unawaited(window.dispose());
      });
    });
  });

  group("older bridges", () {
    void stubCompleteBridge({required Map<String, List<Session>> sessionsByProject}) {
      bridge.answer = (_) async => const SessionPageUnsupported();
      for (final MapEntry(key: projectId, value: sessions) in sessionsByProject.entries) {
        when(
          () => projectRepository.listSessions(projectId: projectId),
        ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: sessions)));
      }
    }

    test("an unsupported page lists every project, and answers keys and counts locally", () {
      inFakeTime((async) {
        stubCompleteBridge(
          sessionsByProject: {
            "alpha": [
              _session(id: "a1", updatedAt: 3, title: "Fix header"),
              testSession(id: "archived", updatedAt: 9, archivedAt: DateTime(2026)).copyWith(projectID: "alpha"),
            ],
            "beta": [_session(id: "b1", updatedAt: 4, projectId: "beta", unseen: true)],
          },
        );
        final window = create();
        async.flushMicrotasks();

        expect(ids(window), ["b1", "a1"]);
        expect(loaded(window).nextCursor, isNull);
        expect(loaded(window).counts, const SessionPageCounts(all: 2, running: 0, unread: 1));
        bridge.requests.clear();

        // Each narrowing reads every session, so a typed query waits for
        // typing to pause.
        window.select(key: (projectId: null, query: "f", filter: SessionListQuickFilter.all));
        async.elapse(SessionWindowService.queryDelay - const Duration(milliseconds: 1));
        window.select(key: (projectId: null, query: "fix", filter: SessionListQuickFilter.all));
        async.elapse(SessionWindowService.queryDelay - const Duration(milliseconds: 1));
        // A live change meanwhile waits for the query too.
        emit(SesoriSseEvent.sessionCreated(info: _session(id: "a0", updatedAt: 1, title: "Fix footer")));
        expect(ids(window), ["b1", "a1"]);
        async.elapse(const Duration(milliseconds: 1));
        expect(ids(window), ["a1", "a0"]);
        emit(SesoriSseEvent.sessionDeleted(info: _session(id: "a0", updatedAt: 1, title: "Fix footer")));
        expect(ids(window), ["a1"]);
        window.select(key: (projectId: null, query: null, filter: SessionListQuickFilter.unread));
        expect(ids(window), ["b1"]);
        expect(loaded(window).counts, const SessionPageCounts(all: 2, running: 0, unread: 1));
        activity.emitSessionActivity({
          "alpha": {"a1": const SessionActivityInfo(isRunning: true, lastUserActivityAt: null, updatedAt: null)},
        });
        async.flushMicrotasks();
        expect(loaded(window).counts.running, 1);
        emit(SesoriSseEvent.sessionCreated(info: _session(id: "a2", updatedAt: 5, unseen: true)));
        expect(ids(window), ["a2", "b1"]);
        async.elapse(const Duration(seconds: 5));
        expect(bridge.requests, isEmpty);

        expect(
          window.search(query: "header", limit: 20),
          completion(isA<SessionWindowSearchMatches>().having((result) => result.sessions.single.id, "id", "a1")),
        );
        async.flushMicrotasks();
        expect(bridge.requests, isEmpty);
        unawaited(window.dispose());
      });
    });

    test("follows the inventory's projects: waits for them, adds and removes, and never lists its own", () {
      inFakeTime((async) {
        stubCompleteBridge(
          sessionsByProject: {
            "alpha": [_session(id: "a1", updatedAt: 1)],
            "beta": [_session(id: "b1", updatedAt: 2, projectId: "beta")],
            "gamma": [_session(id: "g1", updatedAt: 3, projectId: "gamma")],
          },
        );
        inventory.add(const ProjectListState.loading());
        final window = create();
        async.flushMicrotasks();
        expect(window.state.value, isA<SessionWindowLoading>());

        inventory.add(_inventory(projects: [_alpha, _beta]));
        async.flushMicrotasks();
        expect(ids(window), ["b1", "a1"]);

        inventory.add(_inventory(projects: [_alpha, _gamma]));
        async.flushMicrotasks();
        expect(ids(window), ["g1", "a1"]);
        verify(() => projectRepository.listSessions(projectId: "gamma")).called(1);
        verify(() => projectRepository.listSessions(projectId: "alpha")).called(1);
        verifyNever(() => projectRepository.listProjects());

        inventory.add(const ProjectListState.failed(reason: RemoteFailureReason.networkDown));
        unawaited(window.reload());
        async.flushMicrotasks();
        expect(ids(window), ["g1", "a1"]);
        unawaited(window.dispose());
      });
    });

    test("a reconnect asks for pages again", () {
      inFakeTime((async) {
        stubCompleteBridge(
          sessionsByProject: {
            "alpha": [_session(id: "a1", updatedAt: 1)],
            "beta": [],
          },
        );
        final window = create();
        async.flushMicrotasks();
        expect(bridge.requests, hasLength(1));

        bridge.answer = null;
        bridge.sessions = [_session(id: "paged", updatedAt: 1)];
        status.add(const ConnectionStatus.disconnected());
        status.add(_connected(bridgeId: "a"));
        async.flushMicrotasks();
        expect(bridge.requests, hasLength(2));
        expect(ids(window), ["paged"]);
        unawaited(window.dispose());
      });
    });
  });

  test("switching computers clears the rows, drops late answers, and loads the new computer", () {
    inFakeTime((async) {
      bridge.sessions = _sessions(count: 1);
      final window = create();
      async.flushMicrotasks();
      final lateAnswer = Completer<SessionPageResult>();
      bridge.answer = (_) => lateAnswer.future;
      unawaited(window.reload());

      status.add(
        const ConnectionStatus.reconnecting(
          config: ServerConnectionConfig(relayHost: "relay", authToken: "t", bridgeId: "b"),
        ),
      );
      async.flushMicrotasks();
      expect(window.state.value, isA<SessionWindowLoading>());
      lateAnswer.complete(_snapshot(_sessions(count: 3)));
      async.flushMicrotasks();
      expect(window.state.value, isA<SessionWindowLoading>());

      bridge.answer = null;
      bridge.sessions = [_session(id: "other", updatedAt: 1)];
      status.add(_connected(bridgeId: "b"));
      async.flushMicrotasks();
      expect(ids(window), ["other"]);
      unawaited(window.dispose());
    });
  });

  test("search asks the bridge across every project, whatever the key", () {
    inFakeTime((async) {
      bridge.sessions = [
        _session(id: "a", updatedAt: 2, title: "Deploy"),
        _session(id: "b", updatedAt: 1, title: "Deploy", projectId: "beta"),
      ];
      final window = create();
      async.flushMicrotasks();
      window.select(key: (projectId: "alpha", query: null, filter: SessionListQuickFilter.running));
      async.flushMicrotasks();
      bridge.requests.clear();

      SessionWindowSearchResult? result;
      unawaited(window.search(query: "deploy", limit: 20).then((value) => result = value));
      async.flushMicrotasks();
      expect(
        bridge.requests.single,
        const SessionPageRequest(
          mode: SessionPageMode.active,
          projectId: null,
          query: "deploy",
          filter: SessionPageFilter.all,
          cursor: null,
          limit: 20,
        ),
      );
      expect(result, isA<SessionWindowSearchMatches>().having((matches) => matches.sessions.length, "length", 2));

      // A blank query lists every session, without the query the bridge
      // would reject.
      unawaited(window.search(query: "  ", limit: 20).then((value) => result = value));
      async.flushMicrotasks();
      expect(
        bridge.requests.last,
        const SessionPageRequest(
          mode: SessionPageMode.active,
          projectId: null,
          query: null,
          filter: SessionPageFilter.all,
          cursor: null,
          limit: 20,
        ),
      );
      expect(result, isA<SessionWindowSearchMatches>().having((matches) => matches.sessions.length, "length", 2));

      bridge.answer = (_) async => SessionPageFailure(error: ApiError.generic());
      unawaited(window.search(query: "deploy", limit: 20).then((value) => result = value));
      async.flushMicrotasks();
      expect(
        result,
        isA<SessionWindowSearchFailure>().having((failure) => failure.reason, "reason", RemoteFailureReason.unknown),
      );
      unawaited(window.dispose());
    });
  });

  test("the archived window asks for archived pages", () {
    inFakeTime((async) {
      final window = create(mode: AllSessionsMode.archived);
      async.flushMicrotasks();
      expect(bridge.requests.single.mode, SessionPageMode.archived);
      unawaited(window.dispose());
    });
  });
}

/// The whole of [sessions] as one page.
SessionPageResult _snapshot(List<Session> sessions) => SessionPageLoaded(
  page: SessionPageResponse(
    items: sessions,
    nextCursor: null,
    counts: SessionPageCounts(all: sessions.length, running: 0, unread: 0),
  ),
);
