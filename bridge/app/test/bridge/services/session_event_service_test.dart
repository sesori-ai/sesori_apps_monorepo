import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/session_event_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/trackers/session_event_tracker.dart";
import "package:sesori_bridge/src/bridge/services/session_event_service.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../../helpers/test_helpers.dart";

void main() {
  group("SessionEventService", () {
    late AppDatabase database;
    late _EventPlugin plugin;
    late SessionRepository repository;
    late SessionMutationDispatcher mutationDispatcher;
    late SessionEventTracker eventTracker;
    late SessionEventService service;

    setUp(() {
      database = createTestDatabase();
      plugin = _EventPlugin();
      repository = SessionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
        pullRequestDao: database.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      mutationDispatcher = SessionMutationDispatcher(sessionRepository: repository);
      eventTracker = SessionEventTracker(maxPendingEntries: 1024);
      service = SessionEventService(
        sessionRepository: repository,
        sessionMutationDispatcher: mutationDispatcher,
        eventMapper: const SessionEventMapper(),
        eventTracker: eventTracker,
        failureReporter: FakeFailureReporter(),
      );
    });

    tearDown(() async {
      await mutationDispatcher.dispose();
      await database.close();
    });

    test("drops unknown roots without discovering projects and preserves backend-deleted history", () async {
      final unknown = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 1,
          event: BridgeSseSessionCreated(
            info: _sessionInfo(
              sessionId: "unknown-root",
              parentId: null,
              projectId: "unknown-project",
              directory: "/unknown/project",
            ),
          ),
        ),
      );

      expect(unknown, isEmpty);
      expect(await database.projectsDao.getProject(projectId: "unknown-project"), isNull);
      expect(
        await database.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "unknown-root",
        ),
        isNull,
      );

      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      final deleted = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 2,
          event: BridgeSseSessionDeleted(
            info: _sessionInfo(
              sessionId: "backend-root",
              parentId: null,
              projectId: "project",
              directory: "/repo",
            ),
          ),
        ),
      );

      expect(deleted, isEmpty);
      expect(await database.sessionDao.getSession(sessionId: "stable-root"), isNotNull);
      expect(
        await database.sessionDao.isSessionTombstoned(
          backendSessionId: "backend-root",
          pluginId: plugin.id,
        ),
        isFalse,
      );
    });

    test("recursively drains out-of-order descendants under a durable same-plugin parent", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );

      final grandchildOutput = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 3,
          event: BridgeSseSessionCreated(
            info: _sessionInfo(
              sessionId: "backend-grandchild",
              parentId: "backend-child",
              projectId: "backend-project",
              directory: "/repo/child/grandchild",
            ),
          ),
        ),
      );
      expect(grandchildOutput, isEmpty);
      expect(eventTracker.length, 1);

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 4,
          event: BridgeSseSessionCreated(
            info: _sessionInfo(
              sessionId: "backend-child",
              parentId: "backend-root",
              projectId: "backend-project",
              directory: "/repo/child",
            ),
          ),
        ),
      );

      expect(output, hasLength(2));
      final child = Session.fromJson((output[0] as BridgeSseSessionCreated).info);
      final grandchild = Session.fromJson((output[1] as BridgeSseSessionCreated).info);
      expect(child.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(child.id, isNot("backend-child"));
      expect(child.parentID, "stable-root");
      expect(grandchild.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(grandchild.id, isNot("backend-grandchild"));
      expect(grandchild.parentID, child.id);
      expect(eventTracker.length, 0);

      final childRow = await database.sessionDao.getSession(sessionId: child.id);
      final grandchildRow = await database.sessionDao.getSession(sessionId: grandchild.id);
      expect(childRow?.projectId, "project-stable-root");
      expect(childRow?.directory, "/repo/child");
      expect(grandchildRow?.projectId, "project-stable-root");
      expect(grandchildRow?.directory, "/repo/child/grandchild");
    });

    test("persists the archive state of a child when it is first observed", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 5,
          event: BridgeSseSessionCreated(
            info: Session(
              id: "backend-child",
              pluginId: plugin.id,
              projectID: "backend-project",
              directory: "/repo/child",
              parentID: "backend-root",
              title: "archived child",
              time: const SessionTime(created: 10, updated: 20, archived: 30),
              pullRequest: null,
              promptDefaults: null,
            ).toJson(),
          ),
        ),
      );

      final child = Session.fromJson((output.single as BridgeSseSessionCreated).info);
      expect(child.time?.archived, 30);
      expect((await database.sessionDao.getSession(sessionId: child.id))?.archivedAt, 30);
      expect((await repository.getChildSessions(sessionId: "stable-root")).single.time?.archived, 30);
    });

    test("announces a child created by its first full update event", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 6,
          event: BridgeSseSessionUpdated(
            info: _sessionInfo(
              sessionId: "backend-child",
              parentId: "backend-root",
              projectId: "backend-project",
              directory: "/repo/child",
            ),
            titleChanged: true,
          ),
        ),
      );

      expect(output, hasLength(2));
      expect(output.first, isA<BridgeSseSessionCreated>());
      expect(output.last, isA<BridgeSseSessionUpdated>());
      final child = Session.fromJson((output.first as BridgeSseSessionCreated).info);
      expect(child.id, matches(RegExp(r"^ses_[0-9a-f]{32}$")));
      expect(child.parentID, "stable-root");
    });

    test("does not attach a child to a parent owned by another plugin", () async {
      await _insertRoot(
        database: database,
        pluginId: "other-plugin",
        sessionId: "other-root",
        backendSessionId: "shared-backend-parent",
      );

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 7,
          event: BridgeSseSessionCreated(
            info: _sessionInfo(
              sessionId: "backend-child",
              parentId: "shared-backend-parent",
              projectId: "backend-project",
              directory: "/repo/child",
            ),
          ),
        ),
      );

      expect(output, isEmpty);
      expect(eventTracker.length, 1);
      expect(
        await database.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "backend-child",
        ),
        isNull,
      );
    });

    test("drops multi-session events unless every reference has a durable binding", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 7,
          event: const BridgeSsePermissionAsked(
            requestID: "permission",
            sessionID: "backend-root",
            displaySessionId: "unknown-display",
            tool: "bash",
            description: "run",
          ),
        ),
      );

      expect(output, isEmpty);
    });

    test("releases a pending root and descendants after its durable binding commits", () async {
      final rootEvent = BridgeSseSessionCreated(
        info: _sessionInfo(
          sessionId: "backend-root",
          parentId: null,
          projectId: "backend-project",
          directory: "/repo",
        ),
      );
      final childEvent = BridgeSseSessionCreated(
        info: _sessionInfo(
          sessionId: "backend-child",
          parentId: "backend-root",
          projectId: "backend-project",
          directory: "/repo/child",
        ),
      );

      expect(
        await service.normalize(
          source: (pluginId: plugin.id, projectionUpdatedAt: 10, event: rootEvent),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, projectionUpdatedAt: 11, event: childEvent),
        ),
        isEmpty,
      );
      expect(eventTracker.length, 2);

      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      final output = await service.handleBindingsCommitted(
        commit: (pluginId: plugin.id, backendSessionIds: const ["backend-root"]),
      );

      expect(output, hasLength(2));
      final root = Session.fromJson((output[0] as BridgeSseSessionCreated).info);
      final child = Session.fromJson((output[1] as BridgeSseSessionCreated).info);
      expect(root.id, "stable-root");
      expect(child.parentID, "stable-root");
      expect(eventTracker.length, 0);
    });

    test("replays child input after its pending ancestry commits", () async {
      final rootEvent = BridgeSseSessionCreated(
        info: _sessionInfo(
          sessionId: "backend-root",
          parentId: null,
          projectId: "backend-project",
          directory: "/repo",
        ),
      );
      final childEvent = BridgeSseSessionCreated(
        info: _sessionInfo(
          sessionId: "backend-child",
          parentId: "backend-root",
          projectId: "backend-project",
          directory: "/repo/child",
        ),
      );
      const rootPermissionEvent = BridgeSsePermissionAsked(
        requestID: "root-permission",
        sessionID: "backend-root",
        displaySessionId: "backend-root",
        tool: "bash",
        description: "continue root",
      );
      const childPermissionEvent = BridgeSsePermissionAsked(
        requestID: "child-permission",
        sessionID: "backend-child",
        displaySessionId: "backend-root",
        tool: "bash",
        description: "continue child",
      );

      expect(
        await service.normalize(
          source: (pluginId: plugin.id, projectionUpdatedAt: 20, event: rootEvent),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, projectionUpdatedAt: 21, event: childEvent),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, projectionUpdatedAt: 22, event: rootPermissionEvent),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, projectionUpdatedAt: 23, event: childPermissionEvent),
        ),
        isEmpty,
      );
      expect(eventTracker.length, 4);

      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      final output = await service.handleBindingsCommitted(
        commit: (pluginId: plugin.id, backendSessionIds: const ["backend-root"]),
      );

      expect(output, hasLength(4));
      final root = Session.fromJson((output[0] as BridgeSseSessionCreated).info);
      final child = Session.fromJson((output[1] as BridgeSseSessionCreated).info);
      final rootPermission = output[2] as BridgeSsePermissionAsked;
      final childPermission = output[3] as BridgeSsePermissionAsked;
      expect(root.id, "stable-root");
      expect(child.parentID, root.id);
      expect(rootPermission.requestID, "root-permission");
      expect(rootPermission.sessionID, root.id);
      expect(childPermission.requestID, "child-permission");
      expect(childPermission.sessionID, child.id);
      expect(childPermission.displaySessionId, root.id);
      expect(eventTracker.length, 0);
    });

    test("replays child input before a later pending child update", () async {
      final rootEvent = BridgeSseSessionCreated(
        info: _sessionInfo(
          sessionId: "backend-root",
          parentId: null,
          projectId: "backend-project",
          directory: "/repo",
        ),
      );
      final childInfo = _sessionInfo(
        sessionId: "backend-child",
        parentId: "backend-root",
        projectId: "backend-project",
        directory: "/repo/child",
      );
      final events = <BridgeSseEvent>[
        rootEvent,
        BridgeSseSessionCreated(info: childInfo),
        const BridgeSsePermissionAsked(
          requestID: "child-permission",
          sessionID: "backend-child",
          displaySessionId: "backend-root",
          tool: "bash",
          description: "continue child",
        ),
        BridgeSseSessionUpdated(info: childInfo, titleChanged: false),
      ];
      for (var index = 0; index < events.length; index++) {
        expect(
          await service.normalize(
            source: (pluginId: plugin.id, projectionUpdatedAt: 30 + index, event: events[index]),
          ),
          isEmpty,
        );
      }

      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      final output = await service.handleBindingsCommitted(
        commit: (pluginId: plugin.id, backendSessionIds: const ["backend-root"]),
      );

      expect(output, hasLength(4));
      expect(output[0], isA<BridgeSseSessionCreated>());
      expect(output[1], isA<BridgeSseSessionCreated>());
      expect(output[2], isA<BridgeSsePermissionAsked>());
      expect(output[3], isA<BridgeSseSessionUpdated>());
      expect((output[2] as BridgeSsePermissionAsked).requestID, "child-permission");
      expect(eventTracker.length, 0);
    });

    test("rejects a queued event older than the current catalog projection", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      await database.sessionDao.updateObservedSessionProjection(
        sessionId: "stable-root",
        directory: "/newer",
        catalogTitle: "newer title",
        updateCatalogTitle: true,
        updatedAt: 200,
        projectionUpdatedAt: 200,
      );

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
          projectionUpdatedAt: 100,
          event: BridgeSseSessionUpdated(
            info: Session(
              id: "backend-root",
              pluginId: plugin.id,
              projectID: "backend-project",
              directory: "/older",
              parentID: null,
              title: "older title",
              time: const SessionTime(created: 1, updated: 100, archived: null),
              pullRequest: null,
              promptDefaults: null,
            ).toJson(),
            titleChanged: false,
          ),
        ),
      );

      expect(output, isEmpty);
      final row = await database.sessionDao.getSession(sessionId: "stable-root");
      expect(row?.directory, "/newer");
      expect(row?.catalogTitle, "newer title");
      expect(row?.projectionUpdatedAt, 200);
    });

    test("does not publish a created event after its durable row is removed", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      await database.sessionDao.deleteSession(sessionId: "stable-root");

      expect(
        await service.canPublish(
          event: BridgeSseSessionCreated(
            info: Session(
              id: "stable-root",
              pluginId: plugin.id,
              projectID: "project-stable-root",
              directory: "/repo",
              parentID: null,
              title: "stale",
              time: null,
              pullRequest: null,
              promptDefaults: null,
            ).toJson(),
          ),
        ),
        isFalse,
      );
    });

    test("does not publish an updated event after its durable row is removed", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      final event = BridgeSseSessionUpdated(
        info: Session(
          id: "stable-root",
          pluginId: plugin.id,
          projectID: "project-stable-root",
          directory: "/repo",
          parentID: null,
          title: "stale",
          time: null,
          pullRequest: null,
          promptDefaults: null,
        ).toJson(),
        titleChanged: false,
      );
      expect(await service.canPublish(event: event), isTrue);

      await database.sessionDao.deleteSession(sessionId: "stable-root");

      expect(await service.canPublish(event: event), isFalse);
    });
  });
}

Future<void> _insertRoot({
  required AppDatabase database,
  required String pluginId,
  required String sessionId,
  required String backendSessionId,
}) async {
  final projectId = "project-$sessionId";
  await database.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  await database.sessionDao.insertSession(
    sessionId: sessionId,
    backendSessionId: backendSessionId,
    projectId: projectId,
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
    pluginId: pluginId,
  );
}

Map<String, dynamic> _sessionInfo({
  required String sessionId,
  required String? parentId,
  required String projectId,
  required String directory,
}) {
  return Session(
    id: sessionId,
    pluginId: "backend",
    projectID: projectId,
    directory: directory,
    parentID: parentId,
    title: "title-$sessionId",
    time: const SessionTime(created: 10, updated: 20, archived: null),
    pullRequest: null,
    promptDefaults: null,
  ).toJson();
}

class _EventPlugin implements NativeProjectsPluginApi {
  @override
  String get id => "event-plugin";

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
