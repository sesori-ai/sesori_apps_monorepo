import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/session_event_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/trackers/session_child_tracker.dart";
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
    late SessionChildTracker childTracker;
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
      childTracker = SessionChildTracker(maxPendingEntries: 1024);
      service = SessionEventService(
        sessionRepository: repository,
        sessionMutationDispatcher: mutationDispatcher,
        eventMapper: const SessionEventMapper(),
        childTracker: childTracker,
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
      expect(childTracker.length, 1);

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
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
      expect(childTracker.length, 0);

      final childRow = await database.sessionDao.getSession(sessionId: child.id);
      final grandchildRow = await database.sessionDao.getSession(sessionId: grandchild.id);
      expect(childRow?.projectId, "project-stable-root");
      expect(childRow?.directory, "/repo/child");
      expect(grandchildRow?.projectId, "project-stable-root");
      expect(grandchildRow?.directory, "/repo/child/grandchild");
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
      expect(childTracker.length, 1);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
