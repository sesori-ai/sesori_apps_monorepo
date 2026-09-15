import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  late MockProjectRepository repository;
  late MockConnectionService connection;
  late MockSseEventTracker activity;
  late FakeSessionUnseenTracker unseen;
  late FakeCatalogRescanService catalog;
  late StreamController<SseEvent> events;
  late RecentSessionsCubit cubit;
  const projectId = "project-1";

  setUpAll(registerAllFallbackValues);
  setUp(() {
    repository = MockProjectRepository();
    connection = MockConnectionService();
    activity = MockSseEventTracker();
    unseen = FakeSessionUnseenTracker();
    catalog = FakeCatalogRescanService();
    events = StreamController.broadcast(sync: true);
    when(() => connection.events).thenAnswer((_) => events.stream);
    when(() => repository.listSessions(projectId: any(named: "projectId"), waitForPrData: false))
        .thenAnswer((_) async => ApiResponse.success(const SessionListResponse(items: [])));
    cubit = RecentSessionsCubit(
      sessionListService: SessionListService(
        repository: repository,
        activityCalculator: const SessionActivityCalculator(),
      ),
      connectionService: connection,
      sseEventTracker: activity,
      sessionUnseenTracker: unseen,
      catalogRescanService: catalog,
    );
  });
  tearDown(() async {
    await cubit.close();
    await events.close();
    await activity.onDispose();
    await unseen.onDispose();
    await catalog.onDispose();
  });

  RecentSessionsLoaded loaded() => cubit.state[projectId]! as RecentSessionsLoaded;
  void stubSessions({required List<Session> sessions}) {
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
        .thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: sessions)));
  }

  test("lazy reads deduplicate, use active ordering, and pin the open row only once", () async {
    expect(cubit.state, isEmpty);
    final reply = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
    final pending = cubit.ensureLoaded(projectId: projectId);
    await cubit.ensureLoaded(projectId: projectId);
    expect(cubit.state[projectId], isA<RecentSessionsLoading>());
    reply.complete(
      ApiResponse.success(
        SessionListResponse(
          items: [
            for (var index = 1; index <= 4; index++) testSession(id: "$index", updatedAt: index),
            testSession(id: "archived", updatedAt: 5, archivedAt: DateTime.utc(2026)),
          ],
        ),
      ),
    );
    await pending;
    await cubit.ensureLoaded(projectId: projectId);
    expect(loaded().visibleSessions.map((session) => session.id), ["4", "3", "2", "1"]);
    expect(loaded().rows(selectedSessionId: "1").map((session) => session.id), ["4", "3", "2", "1"]);
    expect(loaded().rows(selectedSessionId: "4").length, 3);
    expect(loaded().rows(selectedSessionId: "archived").last.id, "archived");
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(1);
  });

  test("live running/unseen state reorders locally without touching an unrelated entry", () async {
    final old = testSession(id: "old", updatedAt: 1, unseen: true);
    stubSessions(
      sessions: [
        old,
        testSession(id: "new", updatedAt: 2),
      ],
    );
    await cubit.ensureLoaded(projectId: projectId);
    await cubit.ensureLoaded(projectId: "other");
    final other = cubit.state["other"];
    unseen.applyLocalSessionUnseen(projectId: projectId, sessionId: "old", unseen: false);
    await Future<void>.delayed(Duration.zero);
    expect(loaded().isUnseen(session: old), isFalse);
    activity.emitSessionActivity({
      projectId: {"old": const SessionActivityInfo(backgroundTaskCount: 1, lastUserActivityAt: null, updatedAt: null)},
    });
    await Future<void>.delayed(Duration.zero);
    expect(loaded().visibleSessions.first.id, "old");
    expect(loaded().isRunning(session: old), isTrue);
    expect(identical(cubit.state["other"], other), isTrue);
    verify(() => repository.listSessions(projectId: any(named: "projectId"), waitForPrData: false)).called(2);
  });

  test("root create/update/archive/delete mutate inventory without refetching", () async {
    await cubit.ensureLoaded(projectId: projectId);
    final session = testSession(id: "created", title: "First");
    events.add(SseEvent(data: SesoriSseEvent.sessionCreated(info: session)));
    events.add(
      SseEvent(
        data: SesoriSseEvent.sessionCreated(
          info: session.copyWith(id: "child", parentID: "created"),
        ),
      ),
    );
    events.add(
      SseEvent(
        data: SesoriSseEvent.sessionCreated(info: session.copyWith(projectID: "other")),
      ),
    );
    expect(loaded().visibleSessions.single.id, "created");
    events.add(
      SseEvent(
        data: SesoriSseEvent.sessionUpdated(info: session.copyWith(title: "Renamed")),
      ),
    );
    expect(loaded().visibleSessions.single.title, "Renamed");
    events.add(
      SseEvent(
        data: SesoriSseEvent.sessionUpdated(info: session.copyWith(time: session.time!.copyWith(archived: 1))),
      ),
    );
    expect(loaded().visibleSessions, isEmpty);
    expect(loaded().sourceSessions, hasLength(1));
    events.add(SseEvent(data: SesoriSseEvent.sessionDeleted(info: session)));
    expect(loaded().sourceSessions, isEmpty);
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(1);
  });

  test("catalog invalidation replaces in-flight reads; old results cannot seed unseen state", () async {
    final old = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => old.future);
    final pending = cubit.ensureLoaded(projectId: projectId);
    stubSessions(sessions: [testSession(id: "fresh")]);
    catalog.emitCatalogChanged();
    await cubit.stream.firstWhere((state) => state[projectId] is RecentSessionsLoaded);
    old.complete(ApiResponse.success(SessionListResponse(items: [testSession(id: "stale", unseen: true)])));
    await pending;
    expect(loaded().sourceSessions.single.id, "fresh");
    expect(unseen.seededSessions, hasLength(1));
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(2);
  });

  test("failed entries retry on reconnect and project invalidation refreshes only known projects", () async {
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    await cubit.ensureLoaded(projectId: projectId);
    expect(cubit.state[projectId], isA<RecentSessionsFailed>());
    stubSessions(sessions: [testSession()]);
    connection.emitDataMayBeStale();
    await cubit.stream.firstWhere((state) => state[projectId] is RecentSessionsLoaded);
    events.add(SseEvent(data: const SesoriSseEvent.sessionsUpdated(projectID: "other")));
    events.add(SseEvent(data: const SesoriSseEvent.sessionsUpdated(projectID: projectId)));
    await cubit.stream.firstWhere((state) => state[projectId] is RecentSessionsLoaded);
    await cubit.retry(projectId: projectId);
    verify(() => repository.listSessions(projectId: any(named: "projectId"), waitForPrData: false)).called(4);
  });

  test("close cancels listeners and late reads cannot seed shared unseen state", () async {
    final reply = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
    final pending = cubit.ensureLoaded(projectId: projectId);
    await cubit.close();
    expect(events.hasListener, isFalse);
    reply.complete(ApiResponse.success(SessionListResponse(items: [testSession()])));
    await pending;
    expect(unseen.seededSessions, isEmpty);
  });
}
