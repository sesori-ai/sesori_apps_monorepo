import "dart:async";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/models/project_activity.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/project_activity_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  late AppDatabase database;
  late FakeBridgePlugin plugin;
  late ProjectActivityService service;
  var now = 1000;

  setUp(() {
    database = createTestDatabase();
    plugin = FakeBridgePlugin();
    service = ProjectActivityService(
      projectRepository: singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      ),
      now: () => now,
    );
  });

  tearDown(() async {
    await service.dispose();
    await plugin.close();
    await database.close();
  });

  test("uses user creation or receipt time and assistant completion time", () async {
    await _storeSession(database: database, sessionId: "root", projectId: "project");

    await service.handleEvent(
      const SesoriSseEvent.messageUpdated(
        info: Message.user(
          id: "user",
          sessionID: "root",
          agent: null,
          time: MessageTime(created: 200, completed: null),
        ),
      ),
    );
    await service.handleEvent(
      const SesoriSseEvent.messageUpdated(
        info: Message.assistant(
          id: "assistant-incomplete",
          sessionID: "root",
          agent: null,
          modelID: null,
          providerID: null,
          time: MessageTime(created: 300, completed: null),
        ),
      ),
    );
    expect(
      await _activity(database: database, projectId: "project"),
      const ProjectActivity(createdAt: 100, updatedAt: 200),
      reason: "an incomplete assistant message must not use the receipt-time fallback",
    );
    await service.handleEvent(
      const SesoriSseEvent.messageUpdated(
        info: Message.assistant(
          id: "assistant-complete",
          sessionID: "root",
          agent: null,
          modelID: null,
          providerID: null,
          time: MessageTime(created: 300, completed: 400),
        ),
      ),
    );
    await service.handleEvent(
      const SesoriSseEvent.messageUpdated(
        info: Message.user(id: "missing-time", sessionID: "root", agent: null, time: null),
      ),
    );

    expect(
      await _activity(database: database, projectId: "project"),
      const ProjectActivity(createdAt: 100, updatedAt: 1000),
    );
  });

  test("uses error completion time before creation time", () async {
    await _storeSession(database: database, sessionId: "root", projectId: "project");

    await service.handleEvent(
      const SesoriSseEvent.messageUpdated(
        info: Message.error(
          id: "error",
          sessionID: "root",
          agent: null,
          modelID: null,
          providerID: null,
          errorName: "Failure",
          errorMessage: "failed",
          time: MessageTime(created: 200, completed: 300),
        ),
      ),
    );

    expect(
      await _activity(database: database, projectId: "project"),
      const ProjectActivity(createdAt: 100, updatedAt: 300),
    );
  });

  test("uses error creation time when completion time is absent", () async {
    await _storeSession(database: database, sessionId: "root", projectId: "project");

    await service.handleEvent(
      const SesoriSseEvent.messageUpdated(
        info: Message.error(
          id: "error",
          sessionID: "root",
          agent: null,
          modelID: null,
          providerID: null,
          errorName: "Failure",
          errorMessage: "failed",
          time: MessageTime(created: 200, completed: null),
        ),
      ),
    );

    expect(
      await _activity(database: database, projectId: "project"),
      const ProjectActivity(createdAt: 100, updatedAt: 200),
    );
  });

  test("uses receipt time when an error has no timestamps", () async {
    await _storeSession(database: database, sessionId: "root", projectId: "project");

    await service.handleEvent(
      const SesoriSseEvent.messageUpdated(
        info: Message.error(
          id: "error",
          sessionID: "root",
          agent: null,
          modelID: null,
          providerID: null,
          errorName: "Failure",
          errorMessage: "failed",
          time: null,
        ),
      ),
    );

    expect(
      await _activity(database: database, projectId: "project"),
      const ProjectActivity(createdAt: 100, updatedAt: 1000),
    );
  });

  test("ordinary project listing reads the catalog without reconciling", () async {
    plugin.projectsResult = const [
      PluginProject(
        id: "project",
        directory: "project",
        activity: PluginProjectActivity(createdAt: 10, updatedAt: 20),
      ),
    ];
    await database.projectsDao.setActivity(projectId: "project", createdAt: 10, updatedAt: 20);

    final projects = await service.getProjects();

    expect(plugin.getProjectsCallCount, 0);
    expect(projects.single.time, const ProjectTime(created: 10, updated: 20));
  });

  test("a hanging reconciliation does not block a project list", () async {
    final hangingPlugin = _HangingProjectsPlugin();
    final localService = ProjectActivityService(
      projectRepository: singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: hangingPlugin,
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      ),
      now: () => now,
    );
    await database.projectsDao.setActivity(projectId: "stored", createdAt: 10, updatedAt: 20);
    final reconcile = localService.reconcile(pluginId: null);
    await hangingPlugin.reconciliationStarted.future;

    final projects = await localService.getProjects().timeout(const Duration(seconds: 1));

    expect(projects.single.id, "stored");
    hangingPlugin.releaseReconciliation.complete();
    await reconcile;
    await localService.dispose();
    await hangingPlugin.close();
  });

  test("touches root question and permission events and skips displayed children", () async {
    await _storeSession(database: database, sessionId: "root", projectId: "project");

    now = 200;
    await service.handleEvent(
      const SesoriSseEvent.questionAsked(
        id: "q1",
        sessionID: "root",
        displaySessionId: null,
        questions: [QuestionInfo(header: "Question", question: "Proceed?")],
      ),
    );
    now = 300;
    await service.handleEvent(
      const SesoriSseEvent.questionReplied(requestID: "q1", sessionID: "root", displaySessionId: null),
    );
    now = 400;
    await service.handleEvent(
      const SesoriSseEvent.questionRejected(requestID: "q2", sessionID: "root", displaySessionId: null),
    );
    now = 500;
    await service.handleEvent(
      const SesoriSseEvent.permissionAsked(
        requestID: "p1",
        sessionID: "root",
        displaySessionId: null,
        tool: "bash",
        description: "run",
      ),
    );
    now = 600;
    await service.handleEvent(
      const SesoriSseEvent.permissionReplied(
        requestID: "p1",
        sessionID: "root",
        displaySessionId: null,
        reply: "allow",
      ),
    );
    now = 700;
    await service.handleEvent(
      const SesoriSseEvent.questionReplied(requestID: "child", sessionID: "child", displaySessionId: "root"),
    );
    await service.handleEvent(
      const SesoriSseEvent.permissionAsked(
        requestID: "child-permission",
        sessionID: "child",
        displaySessionId: "root",
        tool: "bash",
        description: "run",
      ),
    );

    expect(
      await _activity(database: database, projectId: "project"),
      const ProjectActivity(createdAt: 100, updatedAt: 600),
    );
  });

  test("ignores child messages without stored rows and session-created events", () async {
    await _storeSession(database: database, sessionId: "root", projectId: "project");

    await service.handleEvent(
      const SesoriSseEvent.messageUpdated(
        info: Message.user(
          id: "child-message",
          sessionID: "child",
          agent: null,
          time: MessageTime(created: 500, completed: null),
        ),
      ),
    );
    await service.handleEvent(
      const SesoriSseEvent.sessionCreated(
        info: Session(
          branchName: null,
          id: "new-session",
          pluginId: "fake",
          projectID: "project",
          directory: "/project",
          parentID: null,
          title: null,
          time: SessionTime(created: 600, updated: 600, archived: null),
          pullRequest: null,
          promptDefaults: null,
        ),
      ),
    );

    expect(
      await _activity(database: database, projectId: "project"),
      const ProjectActivity(createdAt: 100, updatedAt: 100),
    );
  });

  test("serializes concurrent writes and emits only the actual advance", () async {
    await _storeSession(database: database, sessionId: "root", projectId: "project");
    final changes = <ProjectActivityChange>[];
    final subscription = service.changes.listen(changes.add);

    await Future.wait([
      service.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message.user(
            id: "newer",
            sessionID: "root",
            agent: null,
            time: MessageTime(created: 300, completed: null),
          ),
        ),
      ),
      service.handleEvent(
        const SesoriSseEvent.messageUpdated(
          info: Message.assistant(
            id: "older",
            sessionID: "root",
            agent: null,
            modelID: null,
            providerID: null,
            time: MessageTime(created: 150, completed: 200),
          ),
        ),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(
      await _activity(database: database, projectId: "project"),
      const ProjectActivity(createdAt: 100, updatedAt: 300),
    );
    expect(changes, [const ProjectActivityChange(projectId: "project", updatedAt: 300)]);
    await subscription.cancel();
  });

  test("reconcile batch-writes corrections and emits only updated advances", () async {
    await database.projectsDao.setActivity(projectId: "created-only", createdAt: 100, updatedAt: 500);
    await database.projectsDao.setActivity(projectId: "advanced", createdAt: 100, updatedAt: 500);
    plugin.projectsResult = const [
      PluginProject(
        id: "created-only",
        directory: "created-only",
        activity: PluginProjectActivity(createdAt: 50, updatedAt: 400),
      ),
      PluginProject(
        id: "advanced",
        directory: "advanced",
        activity: PluginProjectActivity(createdAt: 80, updatedAt: 600),
      ),
    ];
    final changes = <ProjectActivityChange>[];
    final subscription = service.changes.listen(changes.add);

    await service.reconcile(pluginId: null);
    await Future<void>.delayed(Duration.zero);

    expect(plugin.getProjectsCallCount, 1, reason: "native reconciliation must fetch projects once, not per project");
    expect(
      await _activity(database: database, projectId: "created-only"),
      const ProjectActivity(createdAt: 50, updatedAt: 500),
    );
    expect(
      await _activity(database: database, projectId: "advanced"),
      const ProjectActivity(createdAt: 80, updatedAt: 600),
    );
    expect(changes, [const ProjectActivityChange(projectId: "advanced", updatedAt: 600)]);
    await subscription.cancel();
  });

  test("opening preserves canonical identity and emits only timestamp changes", () async {
    plugin.currentProjectResult = const PluginProject(
      id: "canonical",
      directory: "/new/path",
      name: "Project",
    );
    await database.projectsDao.recordOpenedProject(
      projectId: "canonical",
      path: "/old/path",
      displayName: null,
      createdAt: 100,
      updatedAt: 500,
    );
    now = 400;
    final changes = <ProjectActivityChange>[];
    final subscription = service.changes.listen(changes.add);

    final project = await service.openProject(path: "/new/path");
    await Future<void>.delayed(Duration.zero);

    expect(project.id, "canonical");
    expect(project.path, "/new/path");
    expect(project.time, const ProjectTime(created: 100, updated: 500));
    expect((await database.projectsDao.getProject(projectId: "canonical"))?.path, "/new/path");
    expect(changes, isEmpty);
    await subscription.cancel();
  });
}

Future<void> _storeSession({
  required AppDatabase database,
  required String sessionId,
  required String projectId,
}) async {
  await database.projectsDao.setActivity(projectId: projectId, createdAt: 100, updatedAt: 100);
  await database.sessionDao.insertSession(
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: projectId,
    isDedicated: false,
    createdAt: 100,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
    pluginId: "fake",
  );
}

Future<ProjectActivity?> _activity({required AppDatabase database, required String projectId}) async {
  final row = await database.projectsDao.getProject(projectId: projectId);
  if (row == null) return null;
  return ProjectActivity(createdAt: row.createdAt, updatedAt: row.updatedAt);
}

class _HangingProjectsPlugin extends FakeBridgePlugin {
  final reconciliationStarted = Completer<void>();
  final releaseReconciliation = Completer<void>();

  @override
  Future<List<PluginProject>> getProjects() async {
    getProjectsCallCount++;
    reconciliationStarted.complete();
    await releaseReconciliation.future;
    return const [];
  }
}
