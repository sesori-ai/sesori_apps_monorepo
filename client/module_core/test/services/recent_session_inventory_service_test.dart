import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late MockProjectRepository repository;
  late MockConnectionService connection;
  late MockSseEventTracker activity;
  late FakeSessionUnseenTracker unseen;
  late FakeCatalogRescanService catalog;
  late StreamController<SseEvent> events;
  late ProjectListService projectListService;
  late RecentSessionInventoryService inventory;
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
    projectListService = ProjectListService(
      repository: repository,
      activityCalculator: const SessionActivityCalculator(),
    );
    inventory = RecentSessionInventoryService(
      sessionListService: SessionListService(
        repository: repository,
        activityCalculator: const SessionActivityCalculator(),
      ),
      projectListService: projectListService,
      connectionService: connection,
      sseEventTracker: activity,
      sessionUnseenTracker: unseen,
      catalogRescanService: catalog,
    );
  });
  tearDown(() async {
    await inventory.dispose();
    await projectListService.dispose();
    await events.close();
    await activity.onDispose();
    await unseen.onDispose();
    await catalog.onDispose();
  });

  RecentSessionsLoaded loaded() => inventory.state.value[projectId]! as RecentSessionsLoaded;
  void stubSessions({required List<Session> sessions}) {
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
        .thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: sessions)));
  }

  test("successful project snapshots admit every project without duplicate reads", () async {
    const projects = Projects(
      data: [
        ProjectSummary(id: "project-1", name: "One", path: "/one", time: null),
        ProjectSummary(id: "project-2", name: "Two", path: "/two", time: null),
      ],
    );
    when(() => repository.listProjects()).thenAnswer((_) async => ApiResponse.success(projects));

    await projectListService.listProjects();
    await inventory.state.skip(1).firstWhere((state) => state.length == 2);
    await projectListService.listProjects();
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.listSessions(projectId: "project-1", waitForPrData: false)).called(1);
    verify(() => repository.listSessions(projectId: "project-2", waitForPrData: false)).called(1);
  });

  test("winning snapshots remove absent projects and fence their pending reads", () async {
    const current = ProjectSummary(id: "current", name: "Current", path: "/current", time: null);
    const removed = ProjectSummary(id: "removed", name: "Removed", path: "/removed", time: null);
    const stale = ProjectSummary(id: "stale", name: "Stale", path: "/stale", time: null);
    final staleProjects = Completer<ApiResponse<Projects>>();
    final removedSessions = Completer<ApiResponse<SessionListResponse>>();
    var projectRead = 0;
    when(() => repository.listProjects()).thenAnswer((_) {
      projectRead++;
      return switch (projectRead) {
        1 => staleProjects.future,
        2 => Future.value(ApiResponse.success(const Projects(data: [current, removed]))),
        _ => Future.value(ApiResponse.success(const Projects(data: [current]))),
      };
    });
    when(() => repository.listSessions(projectId: removed.id, waitForPrData: false))
        .thenAnswer((_) => removedSessions.future);
    final staleRead = projectListService.listProjects();
    await projectListService.listProjects();
    if (inventory.state.value.length != 2) await inventory.state.skip(1).firstWhere((state) => state.length == 2);

    await projectListService.listProjects();
    expect(inventory.state.value.keys.toSet(), {current.id});
    removedSessions.complete(ApiResponse.success(const SessionListResponse(items: [])));
    staleProjects.complete(ApiResponse.success(const Projects(data: [stale])));
    await staleRead;
    await Future<void>.delayed(Duration.zero);
    expect(inventory.state.value.keys.toSet(), {current.id});
    final previousCurrent = inventory.state.value[current.id];
    connection.emitDataMayBeStale();
    await inventory.state.skip(1).firstWhere((state) => !identical(state[current.id], previousCurrent));
    verify(() => repository.listSessions(projectId: current.id, waitForPrData: false)).called(2);
    verify(() => repository.listSessions(projectId: removed.id, waitForPrData: false)).called(1);
    verifyNever(() => repository.listSessions(projectId: stale.id, waitForPrData: false));
  });

  test("accepted local project removal evicts its entry and fences its pending read", () async {
    const kept = ProjectSummary(id: "kept", name: "Kept", path: "/kept", time: null);
    const hidden = ProjectSummary(id: "hidden", name: "Hidden", path: "/hidden", time: null);
    final hiddenSessions = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(const Projects(data: [kept, hidden])),
    );
    when(() => repository.listSessions(projectId: hidden.id, waitForPrData: false))
        .thenAnswer((_) => hiddenSessions.future);

    await projectListService.listProjects();
    if (inventory.state.value.length != 2) await inventory.state.skip(1).firstWhere((state) => state.length == 2);
    projectListService.removeProjectAndPublish(projects: const [kept, hidden], projectId: hidden.id);
    expect(inventory.state.value.keys, [kept.id]);

    hiddenSessions.complete(ApiResponse.success(const SessionListResponse(items: [])));
    await Future<void>.delayed(Duration.zero);
    expect(inventory.state.value.keys, [kept.id]);
    connection.emitDataMayBeStale();
    await Future<void>.delayed(Duration.zero);
    verify(() => repository.listSessions(projectId: kept.id, waitForPrData: false)).called(2);
    verify(() => repository.listSessions(projectId: hidden.id, waitForPrData: false)).called(1);
  });

  test("lazy reads deduplicate, use active ordering, and pin the open row only once", () async {
    expect(inventory.state.value, isEmpty);
    final reply = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
    final pending = inventory.ensureLoaded(projectId: projectId);
    final refresh = inventory.refresh();
    await inventory.ensureLoaded(projectId: projectId);
    expect(inventory.state.value[projectId], isA<RecentSessionsLoading>());
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
    expect(await refresh, isTrue);
    await inventory.ensureLoaded(projectId: projectId);
    expect(loaded().visibleSessions.map((session) => session.id), ["4", "3", "2", "1"]);
    expect(
      loaded().rows(selectedSessionId: "1", excludingSessionIds: const {}).map((session) => session.id),
      ["4", "3", "2", "1"],
    );
    expect(loaded().rows(selectedSessionId: "4", excludingSessionIds: const {}).length, 3);
    expect(
      loaded().rows(selectedSessionId: "archived", excludingSessionIds: const {}).map((session) => session.id),
      ["4", "3", "2"],
    );
    expect(() => loaded().sourceSessions.clear(), throwsUnsupportedError);
    expect(() => loaded().visibleSessions.clear(), throwsUnsupportedError);
    expect(() => loaded().activityBySessionId.clear(), throwsUnsupportedError);
    expect(() => loaded().listStateBySessionId.clear(), throwsUnsupportedError);
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
    await inventory.ensureLoaded(projectId: projectId);
    await inventory.ensureLoaded(projectId: "other");
    final other = inventory.state.value["other"];
    unseen.applyLocalSessionUnseen(projectId: projectId, sessionId: "old", unseen: false);
    await Future<void>.delayed(Duration.zero);
    expect(loaded().isUnseen(session: old), isFalse);
    activity.emitSessionActivity({
      projectId: {"old": const SessionActivityInfo(backgroundTaskCount: 1, lastUserActivityAt: null, updatedAt: null)},
    });
    await Future<void>.delayed(Duration.zero);
    expect(loaded().visibleSessions.first.id, "old");
    expect(loaded().isRunning(session: old), isTrue);
    expect(identical(inventory.state.value["other"], other), isTrue);
    verify(() => repository.listSessions(projectId: any(named: "projectId"), waitForPrData: false)).called(2);
  });

  test("root create/update/archive/delete mutate inventory without refetching", () async {
    await inventory.ensureLoaded(projectId: projectId);
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
    expect(loaded().rows(selectedSessionId: "created", excludingSessionIds: const {}), isEmpty);
    expect(loaded().sourceSessions, hasLength(1));
    events.add(SseEvent(data: SesoriSseEvent.sessionDeleted(info: session)));
    expect(loaded().sourceSessions, isEmpty);
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(1);
  });

  test("lifecycle events during a read coalesce into a fresh snapshot", () async {
    final old = testSession(id: "deleted");
    final created = testSession(id: "created");
    final reply = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
    final pending = inventory.ensureLoaded(projectId: projectId);
    events.add(SseEvent(data: SesoriSseEvent.sessionDeleted(info: old)));
    events.add(SseEvent(data: SesoriSseEvent.sessionCreated(info: created)));
    events.add(
      SseEvent(
        data: SesoriSseEvent.sessionUpdated(info: created.copyWith(title: "Current")),
      ),
    );
    stubSessions(sessions: [created.copyWith(title: "Current")]);
    reply.complete(ApiResponse.success(SessionListResponse(items: [old])));
    await pending;
    expect(loaded().sourceSessions.single.id, "created");
    expect(loaded().sourceSessions.single.title, "Current");
    expect(unseen.seededSessions, hasLength(1));
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(2);
  });

  test("catalog invalidation replaces in-flight reads; old results cannot seed unseen state", () async {
    final old = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => old.future);
    final pending = inventory.ensureLoaded(projectId: projectId);
    stubSessions(sessions: [testSession(id: "fresh")]);
    catalog.emitCatalogChanged();
    await inventory.state.skip(1).firstWhere((state) => state[projectId] is RecentSessionsLoaded);
    old.complete(ApiResponse.success(SessionListResponse(items: [testSession(id: "stale", unseen: true)])));
    await pending;
    expect(loaded().sourceSessions.single.id, "fresh");
    expect(unseen.seededSessions, hasLength(1));
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(2);
  });

  test("failed entries retry on reconnect and project invalidation refreshes only known projects", () async {
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    await inventory.ensureLoaded(projectId: projectId);
    expect(inventory.state.value[projectId], isA<RecentSessionsFailed>());
    stubSessions(sessions: [testSession()]);
    connection.emitDataMayBeStale();
    await inventory.state.skip(1).firstWhere((state) => state[projectId] is RecentSessionsLoaded);
    events.add(SseEvent(data: const SesoriSseEvent.sessionsUpdated(projectID: "other")));
    events.add(SseEvent(data: const SesoriSseEvent.sessionsUpdated(projectID: projectId)));
    await inventory.state.skip(1).firstWhere((state) => state[projectId] is RecentSessionsLoaded);
    await inventory.retry(projectId: projectId);
    verify(() => repository.listSessions(projectId: any(named: "projectId"), waitForPrData: false)).called(4);
  });

  for (final invalidation in [
    (name: "catalog", emit: () => catalog.emitCatalogChanged()),
    (name: "reconnect", emit: () => connection.emitDataMayBeStale()),
  ]) {
    test("pending ${invalidation.name} refresh retains loaded rows and live activity/unseen updates", () async {
      final session = testSession(unseen: true);
      stubSessions(sessions: [session]);
      await inventory.ensureLoaded(projectId: projectId);
      final previous = loaded();
      final started = Completer<void>();
      final reply = Completer<ApiResponse<SessionListResponse>>();
      when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) {
        started.complete();
        return reply.future;
      });
      invalidation.emit();
      await started.future;
      expect(inventory.state.value[projectId], same(previous));
      unseen.applyLocalSessionUnseen(projectId: projectId, sessionId: session.id, unseen: false);
      activity.emitSessionActivity({
        projectId: {
          session.id: const SessionActivityInfo(backgroundTaskCount: 1, lastUserActivityAt: null, updatedAt: null),
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(loaded().isUnseen(session: session), isFalse);
      expect(loaded().isRunning(session: session), isTrue);
      final refreshed = inventory.state.skip(1).first;
      reply.complete(ApiResponse.success(SessionListResponse(items: [session])));
      await refreshed;
      expect(loaded().isUnseen(session: session), isFalse);
      expect(loaded().isRunning(session: session), isTrue);
      expect(unseen.seededSessions, hasLength(2));
      verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(2);
    });
  }

  for (final failure in _RefreshFailure.values) {
    test("${failure.name} refresh failure retains the current live projection", () async {
      final session = testSession(unseen: true);
      stubSessions(sessions: [session]);
      await inventory.ensureLoaded(projectId: projectId);
      final reply = Completer<ApiResponse<SessionListResponse>>();
      when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
      final pending = inventory.refresh();
      unseen.applyLocalSessionUnseen(projectId: projectId, sessionId: session.id, unseen: false);
      await Future<void>.delayed(Duration.zero);
      switch (failure) {
        case _RefreshFailure.response:
          reply.complete(ApiResponse.error(ApiError.generic()));
        case _RefreshFailure.exception:
          reply.completeError(StateError("read failed"), StackTrace.current);
      }
      expect(await pending, isFalse);
      expect(inventory.state.value[projectId], isA<RecentSessionsLoaded>());
      expect(loaded().sourceSessions, [session]);
      expect(loaded().isUnseen(session: session), isFalse);
      expect(unseen.seededSessions, hasLength(1));
      verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(2);
    });
  }

  test("lifecycle events during refresh patch loaded rows and coalesce a fresh snapshot", () async {
    final deleted = testSession(id: "deleted");
    final archived = testSession(id: "archived");
    final created = testSession(id: "created", title: "First");
    final renamed = created.copyWith(title: "Current");
    final archivedUpdate = archived.copyWith(time: archived.time!.copyWith(archived: 1));
    stubSessions(sessions: [deleted, archived]);
    await inventory.ensureLoaded(projectId: projectId);
    final reply = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
    final pending = inventory.refresh();
    events.add(SseEvent(data: SesoriSseEvent.sessionCreated(info: created)));
    events.add(SseEvent(data: SesoriSseEvent.sessionUpdated(info: renamed)));
    events.add(SseEvent(data: SesoriSseEvent.sessionDeleted(info: deleted)));
    events.add(SseEvent(data: SesoriSseEvent.sessionUpdated(info: archivedUpdate)));
    expect(inventory.state.value[projectId], isA<RecentSessionsLoaded>());
    expect(loaded().visibleSessions.single, renamed);
    expect(loaded().rows(selectedSessionId: "archived", excludingSessionIds: const {}), [renamed]);
    stubSessions(sessions: [renamed, archivedUpdate]);
    reply.complete(ApiResponse.success(SessionListResponse(items: [deleted, archived])));
    expect(await pending, isTrue);
    expect(loaded().visibleSessions.single, renamed);
    expect(loaded().sourceSessions, unorderedEquals([renamed, archivedUpdate]));
    expect(unseen.seededSessions, hasLength(2));
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(3);
  });

  test("superseded refresh completion cannot release a newer pending read", () async {
    final known = testSession(id: "known");
    final created = testSession(id: "created");
    stubSessions(sessions: [known]);
    await inventory.ensureLoaded(projectId: projectId);
    final older = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => older.future);
    final oldRead = inventory.retry(projectId: projectId);
    final newer = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => newer.future);
    final currentRead = inventory.retry(projectId: projectId);
    older.complete(ApiResponse.success(SessionListResponse(items: [testSession(id: "stale", unseen: true)])));
    await oldRead;
    expect(inventory.state.value[projectId], isA<RecentSessionsLoaded>());
    expect(loaded().sourceSessions, [known]);
    expect(unseen.seededSessions, hasLength(1));
    events.add(SseEvent(data: SesoriSseEvent.sessionCreated(info: created)));
    expect(loaded().sourceSessions, contains(created));
    stubSessions(sessions: [known, created]);
    newer.complete(ApiResponse.success(SessionListResponse(items: [known])));
    await currentRead;
    expect(loaded().sourceSessions, unorderedEquals([known, created]));
    expect(unseen.seededSessions, hasLength(2));
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(4);
  });

  for (final failure in _RefreshFailure.values) {
    for (final recovery in _RefreshRecovery.values) {
      test("coalesced ${failure.name} failure rearms through ${recovery.name}", () async {
        final known = testSession(id: "known");
        final created = testSession(id: "created");
        final authoritative = testSession(id: "authoritative");
        stubSessions(sessions: [known]);
        await inventory.ensureLoaded(projectId: projectId);
        final reply = Completer<ApiResponse<SessionListResponse>>();
        when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
        final pending = inventory.retry(projectId: projectId);
        events.add(SseEvent(data: SesoriSseEvent.sessionCreated(info: created)));
        when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) async {
          if (failure == _RefreshFailure.exception) throw StateError("follow-up failed");
          return ApiResponse.error(ApiError.generic());
        });
        reply.complete(ApiResponse.success(SessionListResponse(items: [known])));
        await pending;
        expect(loaded().sourceSessions, contains(created));
        expect(unseen.seededSessions, hasLength(1));
        stubSessions(sessions: [known, created, authoritative]);
        switch (recovery) {
          case _RefreshRecovery.inventory:
            final nextReply = Completer<ApiResponse<SessionListResponse>>();
            when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
                .thenAnswer((_) => nextReply.future);
            final rearmed = inventory.ensureLoaded(projectId: projectId);
            await inventory.ensureLoaded(projectId: projectId);
            final newest = testSession(id: "newest");
            events.add(SseEvent(data: SesoriSseEvent.sessionCreated(info: newest)));
            stubSessions(sessions: [known, created, authoritative, newest]);
            nextReply.complete(ApiResponse.success(SessionListResponse(items: [known, created, authoritative])));
            await rearmed;
            expect(loaded().sourceSessions, contains(newest));
          case _RefreshRecovery.lifecycle:
            events.add(
              SseEvent(
                data: SesoriSseEvent.sessionUpdated(info: created.copyWith(title: "Live")),
              ),
            );
            await Future<void>.delayed(Duration.zero);
        }
        expect(loaded().sourceSessions, contains(authoritative));
        expect(unseen.seededSessions, hasLength(2));
        // Successful application retires the signal; an ordinary ensure stays cached.
        await inventory.ensureLoaded(projectId: projectId);
        verify(() => repository.listSessions(projectId: projectId, waitForPrData: false))
            .called(recovery == _RefreshRecovery.inventory ? 5 : 4);
      });
    }
  }

  test("failed initial coalesced read still requires explicit retry", () async {
    final created = testSession(id: "created");
    final reply = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
    final pending = inventory.ensureLoaded(projectId: projectId);
    events.add(SseEvent(data: SesoriSseEvent.sessionCreated(info: created)));
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    reply.complete(ApiResponse.success(const SessionListResponse(items: [])));
    await pending;
    expect(inventory.state.value[projectId], isA<RecentSessionsFailed>());
    expect(unseen.seededSessions, isEmpty);
    await inventory.ensureLoaded(projectId: projectId);
    stubSessions(sessions: [created]);
    await inventory.retry(projectId: projectId);
    expect(loaded().sourceSessions, [created]);
    await inventory.ensureLoaded(projectId: projectId);
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(3);
  });

  test("empty explicit refresh succeeds without starting reads", () async {
    expect(await inventory.refresh(), isTrue);
    verifyNever(() => repository.listSessions(projectId: any(named: "projectId"), waitForPrData: false));
  });

  test("explicit refresh waits for every admitted project and reports partial failure", () async {
    await inventory.ensureLoaded(projectId: projectId);
    await inventory.ensureLoaded(projectId: "other");
    final otherReply = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    when(() => repository.listSessions(projectId: "other", waitForPrData: false)).thenAnswer((_) => otherReply.future);
    var settled = false;
    final refresh = inventory.refresh().then((result) {
      settled = true;
      return result;
    });
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);
    final otherSession = testSession(id: "new").copyWith(projectID: "other");
    otherReply.complete(ApiResponse.success(SessionListResponse(items: [otherSession])));
    expect(await refresh, isFalse);
    expect((inventory.state.value["other"]! as RecentSessionsLoaded).sourceSessions, [otherSession]);
    verify(() => repository.listSessions(projectId: "other", waitForPrData: false)).called(2);
  });

  test("explicit refresh follows a completed failed successor despite retained rows", () async {
    final known = testSession(id: "known");
    stubSessions(sessions: [known]);
    await inventory.ensureLoaded(projectId: projectId);
    final older = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => older.future);
    bool? reported;
    final refresh = inventory.refresh().then((result) {
      reported = result;
      return result;
    });
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    await inventory.retry(projectId: projectId);
    await Future<void>.delayed(Duration.zero);
    expect(reported, isFalse, reason: "the obsolete read must not delay the winning failure");
    older.complete(ApiResponse.success(SessionListResponse(items: [testSession(id: "stale")])));
    expect(await refresh, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(loaded().sourceSessions, [known]);
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(3);
  });

  test("explicit refresh follows a later owner after its awaited successor applied", () async {
    stubSessions(sessions: [testSession(id: "known")]);
    await inventory.ensureLoaded(projectId: projectId);
    final replies = List.generate(3, (_) => Completer<ApiResponse<SessionListResponse>>());
    var reads = 0;
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
        .thenAnswer((_) => replies[reads++].future);
    var settled = false;
    final refresh = inventory.refresh().then((result) {
      settled = true;
      return result;
    });
    unawaited(inventory.retry(projectId: projectId));
    replies[0].complete(ApiResponse.success(const SessionListResponse(items: [])));
    await Future<void>.delayed(Duration.zero);
    final subscription = inventory.state
        .skip(1)
        .where((state) {
          final entry = state[projectId];
          return entry is RecentSessionsLoaded && entry.sourceSessions.single.id == "successor";
        })
        .take(1)
        .listen((_) => unawaited(inventory.retry(projectId: projectId)));
    addTearDown(subscription.cancel);
    replies[1].complete(ApiResponse.success(SessionListResponse(items: [testSession(id: "successor")])));
    await Future<void>.delayed(Duration.zero);
    expect(reads, 3);
    expect(settled, isFalse);
    replies[2].complete(ApiResponse.error(ApiError.generic()));
    expect(await refresh, isFalse);
    expect(loaded().sourceSessions.single.id, "successor");
  });

  for (final replacement in [false, true]) {
    test("removal settles refresh before retired I/O (replacement: $replacement)", () async {
      await inventory.ensureLoaded(projectId: projectId);
      final replies = List.generate(replacement ? 2 : 1, (_) => Completer<ApiResponse<SessionListResponse>>());
      var reads = 0;
      when(() => repository.listSessions(projectId: projectId, waitForPrData: false))
          .thenAnswer((_) => replies[reads++].future);
      bool? reported;
      final refresh = inventory.refresh().then((result) {
        reported = result;
        return result;
      });
      var driverSettled = false;
      final replacementDriver = replacement
          ? inventory.retry(projectId: projectId).then((_) => driverSettled = true)
          : null;
      projectListService.removeProjectAndPublish(
        projects: const [ProjectSummary(id: projectId, name: "One", path: "/one", time: null)],
        projectId: projectId,
      );
      await Future<void>.delayed(Duration.zero);
      expect(reported, isTrue, reason: "no response has completed but the obligation is retired");
      expect(driverSettled, isFalse);
      expect(await refresh, isTrue);
      replies.first.complete(ApiResponse.success(SessionListResponse(items: [testSession(unseen: true)])));
      if (replacement) replies.last.completeError(StateError("retired read failed"), StackTrace.current);
      await replacementDriver;
      await Future<void>.delayed(Duration.zero);
      expect(inventory.state.value, isEmpty);
      expect(unseen.seededSessions, hasLength(1));
      verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(replacement ? 3 : 2);
    });
  }

  test("dispose cancels listeners and late reads cannot seed shared unseen state", () async {
    final reply = Completer<ApiResponse<SessionListResponse>>();
    when(() => repository.listSessions(projectId: projectId, waitForPrData: false)).thenAnswer((_) => reply.future);
    var driverSettled = false;
    final pending = inventory.ensureLoaded(projectId: projectId).then((_) => driverSettled = true);
    bool? reported;
    final refresh = inventory.refresh().then((result) {
      reported = result;
      return result;
    });
    await inventory.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(reported, isFalse);
    expect(driverSettled, isFalse);
    expect(events.hasListener, isFalse);
    reply.complete(ApiResponse.success(SessionListResponse(items: [testSession()])));
    await pending;
    expect(await refresh, isFalse);
    expect(await inventory.refresh(), isFalse);
    expect(unseen.seededSessions, isEmpty);
    verify(() => repository.listSessions(projectId: projectId, waitForPrData: false)).called(1);
  });
}

enum _RefreshFailure() {
  response,
  exception,
}

enum _RefreshRecovery() {
  inventory,
  lifecycle,
}
