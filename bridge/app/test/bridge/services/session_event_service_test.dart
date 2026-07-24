import "dart:async";

import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/session_event_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/trackers/session_event_tracker.dart";
import "package:sesori_bridge/src/bridge/services/session_event_service.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";
import "../../helpers/test_helpers.dart";

void main() {
  group("SessionEventService", () {
    late AppDatabase database;
    late _TransactionGatedSessionDao sessionDao;
    late _EventPlugin plugin;
    late TestPluginRuntime pluginRuntime;
    late SessionRepository repository;
    late SessionEventTracker eventTracker;
    late SessionEventService service;
    late CapturingFailureReporter failureReporter;

    setUp(() {
      database = createTestDatabase();
      sessionDao = _TransactionGatedSessionDao(database);
      plugin = _EventPlugin();
      pluginRuntime = createTestPluginRuntime(plugins: [plugin]);
      repository = SessionRepository(
        runtime: pluginRuntime,
        bridgeDerivedProjectPluginIds: const {},
        sessionDao: sessionDao,
        projectsDao: database.projectsDao,
        pullRequestDao: database.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
        aggregateSourceDeadline: const Duration(seconds: 5),
      );
      eventTracker = SessionEventTracker(maxPendingEntriesPerPlugin: 1024);
      failureReporter = CapturingFailureReporter();
      service = SessionEventService(
        sessionRepository: repository,
        pluginRuntime: pluginRuntime,
        eventMapper: const SessionEventMapper(),
        eventTracker: eventTracker,
        failureReporter: failureReporter,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test("drops unknown roots without discovering projects and preserves backend-deleted history", () async {
      final unknown = await service.normalize(
        source: (
          pluginId: plugin.id,
          generation: 1,
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
          generation: 1,
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
          generation: 1,
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
          generation: 1,
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
          generation: 1,
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
              branchName: null,
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
          generation: 1,
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

    test("plugin title updates the catalog fallback without replacing the Sesori title", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      await database.sessionDao.setTitle(
        sessionId: "stable-root",
        title: "Sesori title",
        updatedAt: 2,
        projectionUpdatedAt: 2,
      );

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
          generation: 1,
          projectionUpdatedAt: 3,
          event: BridgeSseSessionUpdated(
            info: _sessionInfo(
              sessionId: "backend-root",
              parentId: null,
              projectId: "backend-project",
              directory: "/repo",
            ),
            titleChanged: true,
          ),
        ),
      );

      final row = await database.sessionDao.getSession(sessionId: "stable-root");
      expect(row?.title, "Sesori title");
      expect(row?.catalogTitle, "title-backend-root");
      final updated = output.single as BridgeSseSessionUpdated;
      expect(Session.fromJson(updated.info).title, "Sesori title");
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
          generation: 1,
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

    test("rejects a root-shaped update for a durable child", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      final created = await service.normalize(
        source: (
          pluginId: plugin.id,
          generation: 1,
          projectionUpdatedAt: 7,
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
      final child = Session.fromJson((created.single as BridgeSseSessionCreated).info);

      final output = await service.normalize(
        source: (
          pluginId: plugin.id,
          generation: 1,
          projectionUpdatedAt: 8,
          event: BridgeSseSessionUpdated(
            info: Session.fromJson(
              _sessionInfo(
                sessionId: "backend-child",
                parentId: null,
                projectId: "backend-project",
                directory: "/wrong",
              ),
            ).copyWith(title: "wrong").toJson(),
            titleChanged: true,
          ),
        ),
      );

      expect(output, isEmpty);
      final row = await database.sessionDao.getSession(sessionId: child.id);
      expect(row?.parentSessionId, "stable-root");
      expect(row?.directory, "/repo/child");
      expect(row?.catalogTitle, "title-backend-child");
      expect(row?.projectionUpdatedAt, 7);
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
          generation: 1,
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
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 10, event: rootEvent),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 11, event: childEvent),
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
      final root = Session.fromJson((output[0].event as BridgeSseSessionCreated).info);
      final child = Session.fromJson((output[1].event as BridgeSseSessionCreated).info);
      expect(output.map((item) => item.generation), everyElement(1));
      expect(root.id, "stable-root");
      expect(child.parentID, "stable-root");
      expect(eventTracker.length, 0);
    });

    test("releases a new root's initial message and status after its binding commits", () async {
      final created = BridgeSseSessionCreated(
        info: _sessionInfo(
          sessionId: "backend-root",
          parentId: null,
          projectId: "backend-project",
          directory: "/repo",
        ),
      );
      final message = BridgeSseMessageUpdated(
        info: const Message.user(
          id: "backend-message",
          sessionID: "backend-root",
          agent: null,
          time: null,
        ).toJson(),
      );
      const part = BridgeSseMessagePartUpdated(
        part: PluginMessagePart(
          id: "backend-part",
          sessionID: "backend-root",
          messageID: "backend-message",
          type: PluginMessagePartType.text,
          text: "visible prompt",
          tool: null,
          state: null,
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
        ),
      );
      final status = BridgeSseSessionStatus(
        sessionID: "backend-root",
        status: const SessionStatus.busy().toJson(),
      );

      for (final (index, event) in [created, message, part, status].indexed) {
        expect(
          await service.normalize(
            source: (
              pluginId: plugin.id,
              generation: 1,
              projectionUpdatedAt: 20 + index,
              event: event,
            ),
          ),
          isEmpty,
        );
      }
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
      expect(output.map((item) => item.generation), everyElement(1));
      expect(Session.fromJson((output[0].event as BridgeSseSessionCreated).info).id, "stable-root");
      expect(Message.fromJson((output[1].event as BridgeSseMessageUpdated).info).sessionID, "stable-root");
      expect((output[2].event as BridgeSseMessagePartUpdated).part.sessionID, "stable-root");
      expect((output[3].event as BridgeSseSessionStatus).sessionID, "stable-root");
      expect(eventTracker.length, 0);
    });

    test("replays an update that follows a pending root creation", () async {
      final created = BridgeSseSessionCreated(
        info: _sessionInfo(
          sessionId: "backend-root",
          parentId: null,
          projectId: "backend-project",
          directory: "/repo",
        ),
      );
      final updated = BridgeSseSessionUpdated(
        info: Session.fromJson(
          _sessionInfo(
            sessionId: "backend-root",
            parentId: null,
            projectId: "backend-project",
            directory: "/repo",
          ),
        ).copyWith(title: "Updated title").toJson(),
        titleChanged: true,
      );

      expect(
        await service.normalize(
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 12, event: created),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 13, event: updated),
        ),
        isEmpty,
      );

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
      expect(output.first.event, isA<BridgeSseSessionCreated>());
      final normalizedUpdate = output.last.event as BridgeSseSessionUpdated;
      expect(output.map((item) => item.generation), everyElement(1));
      final session = Session.fromJson(normalizedUpdate.info);
      expect(session.id, "stable-root");
      expect(session.title, "Updated title");
      expect(eventTracker.length, 0);
    });

    test("replaces a stale pending root when its successor observes an update", () async {
      final created = BridgeSseSessionCreated(
        info: _sessionInfo(
          sessionId: "backend-root",
          parentId: null,
          projectId: "backend-project",
          directory: "/repo",
        ),
      );
      final updated = BridgeSseSessionUpdated(
        info: Session.fromJson(created.info).copyWith(title: "Successor title").toJson(),
        titleChanged: true,
      );

      expect(
        await service.normalize(
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 12, event: created),
        ),
        isEmpty,
      );
      pluginRuntime.currentGeneration = 2;
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, generation: 2, projectionUpdatedAt: 13, event: updated),
        ),
        isEmpty,
      );

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
      expect(output.map((item) => item.generation), everyElement(2));
      expect(output.first.event, isA<BridgeSseSessionCreated>());
      final normalizedUpdate = output.last.event as BridgeSseSessionUpdated;
      expect(Session.fromJson(normalizedUpdate.info).title, "Successor title");
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
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 20, event: rootEvent),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 21, event: childEvent),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 22, event: rootPermissionEvent),
        ),
        isEmpty,
      );
      expect(
        await service.normalize(
          source: (pluginId: plugin.id, generation: 1, projectionUpdatedAt: 23, event: childPermissionEvent),
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
      final root = Session.fromJson((output[0].event as BridgeSseSessionCreated).info);
      final child = Session.fromJson((output[1].event as BridgeSseSessionCreated).info);
      final rootPermission = output[2].event as BridgeSsePermissionAsked;
      final childPermission = output[3].event as BridgeSsePermissionAsked;
      expect(output.map((item) => item.generation), everyElement(1));
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
            source: (
              pluginId: plugin.id,
              generation: 1,
              projectionUpdatedAt: 30 + index,
              event: events[index],
            ),
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
      expect(output[0].event, isA<BridgeSseSessionCreated>());
      expect(output[1].event, isA<BridgeSseSessionCreated>());
      expect(output[2].event, isA<BridgeSsePermissionAsked>());
      expect(output[3].event, isA<BridgeSseSessionUpdated>());
      expect((output[2].event as BridgeSsePermissionAsked).requestID, "child-permission");
      expect(output.map((item) => item.generation), everyElement(1));
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
          generation: 1,
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
              branchName: null,
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

    test("does not commit a retired-generation session projection after transaction entry", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      final before = await database.sessionDao.getSession(sessionId: "stable-root");
      sessionDao.gateNextProjectionTransaction();

      final normalization = service.normalize(
        source: (
          pluginId: plugin.id,
          generation: 1,
          projectionUpdatedAt: 100,
          event: BridgeSseSessionUpdated(
            info: Session.fromJson(
              _sessionInfo(
                sessionId: "backend-root",
                parentId: null,
                projectId: "backend-project",
                directory: "/retired",
              ),
            ).copyWith(title: "Retired title").toJson(),
            titleChanged: true,
          ),
        ),
      );
      await sessionDao.projectionTransactionEntered;
      pluginRuntime.generationCurrent = false;
      sessionDao.releaseProjectionTransaction();

      expect(await normalization, isEmpty);
      final after = await database.sessionDao.getSession(sessionId: "stable-root");
      expect(after?.directory, before?.directory);
      expect(after?.catalogTitle, before?.catalogTitle);
      expect(after?.updatedAt, before?.updatedAt);
      expect(after?.projectionUpdatedAt, before?.projectionUpdatedAt);
      expect(failureReporter.recordedIdentifiers, isEmpty);
    });

    test("does not commit a retired-generation child after transaction entry", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      sessionDao.gateNextProjectionTransaction();

      final normalization = service.normalize(
        source: (
          pluginId: plugin.id,
          generation: 1,
          projectionUpdatedAt: 100,
          event: BridgeSseSessionCreated(
            info: _sessionInfo(
              sessionId: "backend-child",
              parentId: "backend-root",
              projectId: "backend-project",
              directory: "/retired-child",
            ),
          ),
        ),
      );
      await sessionDao.projectionTransactionEntered;
      pluginRuntime.generationCurrent = false;
      sessionDao.releaseProjectionTransaction();

      expect(await normalization, isEmpty);
      expect(
        await database.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "backend-child",
        ),
        isNull,
      );
      expect(failureReporter.recordedIdentifiers, isEmpty);
    });

    test("commits same-generation projection writes after transaction entry", () async {
      await _insertRoot(
        database: database,
        pluginId: plugin.id,
        sessionId: "stable-root",
        backendSessionId: "backend-root",
      );
      sessionDao.gateNextProjectionTransaction();

      final update = service.normalize(
        source: (
          pluginId: plugin.id,
          generation: 1,
          projectionUpdatedAt: 100,
          event: BridgeSseSessionUpdated(
            info: Session.fromJson(
              _sessionInfo(
                sessionId: "backend-root",
                parentId: null,
                projectId: "backend-project",
                directory: "/current",
              ),
            ).copyWith(title: "Current title").toJson(),
            titleChanged: true,
          ),
        ),
      );
      await sessionDao.projectionTransactionEntered;
      sessionDao.releaseProjectionTransaction();

      expect(await update, hasLength(1));
      final updated = await database.sessionDao.getSession(sessionId: "stable-root");
      expect(updated?.directory, "/current");
      expect(updated?.catalogTitle, "Current title");
      expect(updated?.projectionUpdatedAt, greaterThanOrEqualTo(100));

      sessionDao.gateNextProjectionTransaction();
      final childCreation = service.normalize(
        source: (
          pluginId: plugin.id,
          generation: 1,
          projectionUpdatedAt: 101,
          event: BridgeSseSessionCreated(
            info: _sessionInfo(
              sessionId: "backend-child",
              parentId: "backend-root",
              projectId: "backend-project",
              directory: "/current-child",
            ),
          ),
        ),
      );
      await sessionDao.projectionTransactionEntered;
      sessionDao.releaseProjectionTransaction();

      expect(await childCreation, hasLength(1));
      final child = await database.sessionDao.getSessionByBinding(
        pluginId: plugin.id,
        backendSessionId: "backend-child",
      );
      expect(child?.parentSessionId, "stable-root");
      expect(child?.directory, "/current-child");
      expect(child?.projectionUpdatedAt, greaterThanOrEqualTo(101));
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
              branchName: null,
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
          branchName: null,
        ).toJson(),
        titleChanged: false,
      );
      expect(await service.canPublish(event: event), isTrue);

      await database.sessionDao.deleteSession(sessionId: "stable-root");

      expect(await service.canPublish(event: event), isFalse);
    });
  });
}

class _TransactionGatedSessionDao extends SessionDao {
  _TransactionGatedSessionDao(super.attachedDatabase);

  Completer<void>? _transactionEntered;
  Completer<void>? _releaseTransaction;

  Future<void> get projectionTransactionEntered => _transactionEntered!.future;

  void gateNextProjectionTransaction() {
    _transactionEntered = Completer<void>();
    _releaseTransaction = Completer<void>();
  }

  void releaseProjectionTransaction() {
    _releaseTransaction!.complete();
  }

  @override
  Future<bool> isSessionTombstoned({required String backendSessionId, required String pluginId}) async {
    final transactionEntered = _transactionEntered;
    final releaseTransaction = _releaseTransaction;
    if (transactionEntered != null && releaseTransaction != null) {
      transactionEntered.complete();
      await releaseTransaction.future;
      _transactionEntered = null;
      _releaseTransaction = null;
    }
    return super.isSessionTombstoned(
      backendSessionId: backendSessionId,
      pluginId: pluginId,
    );
  }
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
    branchName: null,
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
