import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/api/database/tables/session_table.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";

void main() {
  group("CatalogImportRepository", () {
    late AppDatabase database;
    late Directory directory;

    setUp(() async {
      database = createTestDatabase();
      directory = await Directory.systemTemp.createTemp("sesori-catalog-import-test-");
    });

    tearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    test("native import validates ancestry, preserves bridge state, and is idempotent", () async {
      final projectPath = "${directory.path}/project";
      await database.projectsDao.upsertProjectRows(
        rows: [
          ProjectDto(
            projectId: "stored-project",
            path: projectPath,
            hidden: true,
            baseBranch: "main",
            displayName: "User project name",
            createdAt: 10,
            updatedAt: 20,
            projectionUpdatedAt: 20,
          ),
        ],
      );
      await database.sessionDao.upsertSessionRows(
        rows: [
          _sessionRow(
            sessionId: "ses_existing_root",
            backendSessionId: "root",
            projectId: "stored-project",
            directory: projectPath,
            archivedAt: null,
            title: "User session title",
            catalogTitle: "Old catalog title",
            projectionUpdatedAt: 20,
          ),
        ],
      );
      await database.sessionDao.insertSessionTombstone(
        backendSessionId: "deleted",
        pluginId: "native",
        deletedAt: 30,
      );

      final plugin = _NativeImportPlugin(
        projects: [
          PluginProject(
            id: "backend-project",
            directory: "$projectPath/./",
            name: "Backend project name",
            activity: const PluginProjectActivity(createdAt: 1, updatedAt: 100),
          ),
        ],
        rootsByProject: {
          projectPath: [
            _pluginSession(id: "root", directory: projectPath, title: "Fresh catalog title", archivedAt: 99),
            _pluginSession(id: "orphan", parentId: "missing", directory: projectPath),
            _pluginSession(id: "cycle-a", parentId: "cycle-b", directory: projectPath),
            _pluginSession(id: "cycle-b", parentId: "cycle-a", directory: projectPath),
          ],
        },
        childrenByParent: {
          "root": [
            _pluginSession(id: "child", directory: projectPath),
            _pluginSession(id: "deleted", parentId: "root", directory: projectPath),
          ],
          "child": [_pluginSession(id: "grandchild", parentId: "child", directory: projectPath)],
        },
      );
      final repository = _repository(database: database, plugin: plugin);
      final control = CatalogImportControl(
        explicitImportRequested: false,
        hydrationMarkerRequested: true,
      );

      final statuses = await repository.importCatalog(pluginId: plugin.id, control: control).toList();

      expect(statuses.last, isA<CatalogImportCompleted>());
      final project = await database.projectsDao.getProject(projectId: "stored-project");
      expect(project?.path, projectPath);
      expect(project?.hidden, isTrue);
      expect(project?.baseBranch, "main");
      expect(project?.displayName, "User project name");

      final root = await database.sessionDao.getSessionByBinding(
        pluginId: "native",
        backendSessionId: "root",
      );
      final child = await database.sessionDao.getSessionByBinding(
        pluginId: "native",
        backendSessionId: "child",
      );
      final grandchild = await database.sessionDao.getSessionByBinding(
        pluginId: "native",
        backendSessionId: "grandchild",
      );
      expect(root?.sessionId, "ses_existing_root");
      expect(root?.title, "User session title");
      expect(root?.catalogTitle, "Fresh catalog title");
      expect(root?.archivedAt, isNull);
      expect(child?.sessionId, startsWith("ses_"));
      expect(child?.parentSessionId, root?.sessionId);
      expect(grandchild?.parentSessionId, child?.sessionId);
      for (final omitted in ["deleted", "orphan", "cycle-a", "cycle-b"]) {
        expect(
          await database.sessionDao.getSessionByBinding(pluginId: "native", backendSessionId: omitted),
          isNull,
        );
      }
      expect(await repository.getHydrationCompletion(pluginId: plugin.id), isNotNull);

      await repository
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .drain<void>();
      expect(
        (await database.sessionDao.getSessionByBinding(pluginId: "native", backendSessionId: "child"))?.sessionId,
        child?.sessionId,
      );
    });

    test("native import gives an exact project id precedence during a move", () async {
      final oldPath = "${directory.path}/old";
      final movedPath = "${directory.path}/moved";
      await database.projectsDao.upsertProjectRows(
        rows: [
          _projectRow(id: "backend-project", path: oldPath),
          _projectRow(id: "path-owner", path: movedPath),
        ],
      );
      final plugin = _NativeImportPlugin(
        projects: [PluginProject(id: "backend-project", directory: movedPath)],
        rootsByProject: {
          movedPath: [_pluginSession(id: "moved-root", directory: movedPath)],
        },
        childrenByParent: const {},
      );

      await _repository(database: database, plugin: plugin)
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .drain<void>();

      expect((await database.projectsDao.getProject(projectId: "backend-project"))?.path, movedPath);
      expect(
        (await database.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "moved-root",
        ))?.projectId,
        "backend-project",
      );
    });

    test("native import reuses a derived project in the same directory without duplicates", () async {
      final sharedPath = "${directory.path}/shared";
      final derived = _DerivedImportPlugin(launchDirectory: sharedPath, sessions: const []);
      await _repository(database: database, plugin: derived)
          .importCatalog(
            pluginId: derived.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .drain<void>();
      final native = _NativeImportPlugin(
        projects: [PluginProject(id: "native-project", directory: "$sharedPath/.")],
        rootsByProject: {
          sharedPath: [_pluginSession(id: "native-root", directory: sharedPath)],
        },
        childrenByParent: const {},
      );

      await _repository(database: database, plugin: native)
          .importCatalog(
            pluginId: native.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .drain<void>();

      final projects = await database.projectsDao.getAllProjects();
      expect(projects, hasLength(1));
      expect(projects.single.projectId, sharedPath);
      expect(
        (await database.sessionDao.getSessionByBinding(
          pluginId: native.id,
          backendSessionId: "native-root",
        ))?.projectId,
        sharedPath,
      );
    });

    test("project identity indexes are reused and updated throughout an import batch", () async {
      final firstPath = "${directory.path}/first";
      final secondPath = "${directory.path}/second";
      final calculator = _TrackingProjectCatalogIdentityCalculator(
        firstProjectId: "first",
        firstPath: firstPath,
      );
      final plugin = _NativeImportPlugin(
        projects: [
          PluginProject(id: "first", directory: firstPath),
          PluginProject(id: "second", directory: secondPath),
        ],
        rootsByProject: const {},
        childrenByParent: const {},
      );
      final repository = CatalogImportRepository(
        operationalPlugins: {plugin.id: plugin},
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        catalogHydrationsDao: database.catalogHydrationsDao,
        projectCatalogIdentityCalculator: calculator,
      );

      await repository
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .drain<void>();

      expect(calculator.callCount, 2);
      expect(calculator.reusedIndexes, isTrue);
      expect(calculator.sawFirstRowOnSecondLookup, isTrue);
    });

    test("derived import sends complete normalized hints and retains owning-project attribution", () async {
      final projectOne = "${directory.path}/one";
      final projectTwo = "${directory.path}/two";
      final selectedWorktree = "${directory.path}/selected-worktree";
      final otherWorktree = "${directory.path}/other-worktree";
      final launchDirectory = "${directory.path}/launch";
      await database.projectsDao.upsertProjectRows(
        rows: [
          _projectRow(id: "one", path: projectOne, updatedAt: 200),
          _projectRow(id: "two", path: projectTwo),
        ],
      );
      await database.sessionDao.upsertSessionRows(
        rows: [
          _sessionRow(
            sessionId: "ses_selected",
            backendSessionId: "selected",
            projectId: "one",
            directory: selectedWorktree,
            worktreePath: selectedWorktree,
            pluginId: "derived",
            catalogTitle: "Stored catalog title",
            projectionUpdatedAt: 20,
            updatedAt: 200,
          ),
          _sessionRow(
            sessionId: "ses_other",
            backendSessionId: "other",
            projectId: "two",
            directory: otherWorktree,
            worktreePath: otherWorktree,
            pluginId: "other-plugin",
            projectionUpdatedAt: 20,
          ),
        ],
      );
      final plugin = _DerivedImportPlugin(
        launchDirectory: launchDirectory,
        sessions: [
          _pluginSession(
            id: "selected",
            directory: "$selectedWorktree/stale-catalog-path",
            updatedAt: 100,
          ),
          _pluginSession(id: "child", parentId: "selected", directory: selectedWorktree),
          _pluginSession(id: "orphan", parentId: "missing", directory: selectedWorktree),
        ],
      );
      final repository = _repository(database: database, plugin: plugin);

      final statuses = await repository
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .toList();

      expect(
        plugin.knownDirectories,
        containsAll([projectOne, projectTwo, selectedWorktree, launchDirectory]),
      );
      expect(plugin.knownDirectories, isNot(contains(otherWorktree)));
      expect(statuses.whereType<CatalogImportCommitting>().single.projectsSeen, 2);
      final selected = await database.sessionDao.getSession(sessionId: "ses_selected");
      final selectedProject = await database.projectsDao.getProject(projectId: "one");
      final child = await database.sessionDao.getSessionByBinding(pluginId: "derived", backendSessionId: "child");
      expect(selectedProject?.updatedAt, 200);
      expect(selected?.projectId, "one");
      expect(selected?.directory, selectedWorktree);
      expect(selected?.updatedAt, 200);
      expect(selected?.catalogTitle, "Stored catalog title");
      expect(child?.projectId, "one");
      expect(child?.parentSessionId, "ses_selected");
      expect(await database.projectsDao.getProjectsByPath(path: selectedWorktree), isEmpty);
      expect(await database.projectsDao.getProjectsByPath(path: launchDirectory), hasLength(1));
      expect(
        await database.sessionDao.getSessionByBinding(pluginId: "derived", backendSessionId: "orphan"),
        isNull,
      );
    });

    test("a projection changed after enumeration starts wins over the stale import", () async {
      final projectPath = "${directory.path}/stale";
      await database.projectsDao.upsertProjectRows(
        rows: [_projectRow(id: "stale", path: projectPath)],
      );
      await database.sessionDao.upsertSessionRows(
        rows: [
          _sessionRow(
            sessionId: "ses_stale",
            backendSessionId: "stale-root",
            projectId: "stale",
            directory: projectPath,
            catalogTitle: "before",
            projectionUpdatedAt: 20,
          ),
        ],
      );
      final newerRow = _sessionRow(
        sessionId: "ses_stale",
        backendSessionId: "stale-root",
        projectId: "stale",
        directory: "$projectPath/newer",
        title: "Concurrent bridge title",
        catalogTitle: "concurrent catalog title",
        projectionUpdatedAt: DateTime.now().millisecondsSinceEpoch + 100000,
      );
      final plugin = _NativeImportPlugin(
        projects: [PluginProject(id: "stale", directory: projectPath)],
        rootsByProject: {
          projectPath: [
            _pluginSession(
              id: "stale-root",
              directory: "$projectPath/import",
              title: "stale import title",
            ),
          ],
        },
        childrenByParent: const {},
        onGetSessions: (_) => database.sessionDao.upsertSessionRows(rows: [newerRow]),
      );
      final repository = _repository(database: database, plugin: plugin);

      await repository
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .drain<void>();

      expect(await database.sessionDao.getSession(sessionId: "ses_stale"), newerRow);
    });

    test("project activity uses import time only when no real timestamp exists", () async {
      final observedPath = "${directory.path}/observed";
      final persistedPath = "${directory.path}/persisted";
      await database.projectsDao.upsertProjectRows(
        rows: [_projectRow(id: "persisted", path: persistedPath, updatedAt: 200)],
      );
      final repository = _repository(
        database: database,
        plugin: _NativeImportPlugin(
          projects: [
            PluginProject(
              id: "observed",
              directory: observedPath,
              activity: const PluginProjectActivity(createdAt: 50, updatedAt: 100),
            ),
            PluginProject(id: "persisted", directory: persistedPath),
          ],
          rootsByProject: const {},
          childrenByParent: const {},
        ),
      );

      await repository
          .importCatalog(
            pluginId: "native",
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .drain<void>();

      expect((await database.projectsDao.getProject(projectId: "observed"))?.updatedAt, 100);
      expect((await database.projectsDao.getProject(projectId: "persisted"))?.updatedAt, 200);
    });

    test("cancellation after a backend call publishes no rows", () async {
      final gate = Completer<void>();
      final plugin = _NativeImportPlugin(
        projects: [PluginProject(id: "project", directory: "${directory.path}/project")],
        rootsByProject: const {},
        childrenByParent: const {},
        getProjectsGate: gate,
      );
      final repository = _repository(database: database, plugin: plugin);
      final control = CatalogImportControl(
        explicitImportRequested: true,
        hydrationMarkerRequested: false,
      );
      final result = repository.importCatalog(pluginId: plugin.id, control: control).toList();
      await plugin.getProjectsStarted.future;

      control.cancellationRequested = true;
      gate.complete();
      final statuses = await result;

      expect(statuses.last, isA<CatalogImportCancelled>());
      expect(await database.projectsDao.getAllProjects(), isEmpty);
    });

    test("session write failure rolls the project batch back", () async {
      final projectPath = "${directory.path}/rollback";
      final plugin = _NativeImportPlugin(
        projects: [PluginProject(id: "rollback", directory: projectPath)],
        rootsByProject: {
          projectPath: [_pluginSession(id: "root", directory: projectPath)],
        },
        childrenByParent: const {},
      );
      await database.customStatement(
        "CREATE TRIGGER reject_import BEFORE INSERT ON sessions_table "
        "BEGIN SELECT RAISE(ABORT, 'reject import'); END",
      );
      final repository = _repository(database: database, plugin: plugin);

      await expectLater(
        repository
            .importCatalog(
              pluginId: plugin.id,
              control: CatalogImportControl(
                explicitImportRequested: true,
                hydrationMarkerRequested: false,
              ),
            )
            .drain<void>(),
        throwsA(anything),
      );

      expect(await database.projectsDao.getProject(projectId: "rollback"), isNull);
    });
  });
}

class _TrackingProjectCatalogIdentityCalculator extends ProjectCatalogIdentityCalculator {
  _TrackingProjectCatalogIdentityCalculator({required this.firstProjectId, required this.firstPath});

  final String firstProjectId;
  final String firstPath;
  Map<String, ProjectDto>? _firstProjectsById;
  Map<String, ProjectDto>? _firstProjectsByNormalizedPath;
  int callCount = 0;
  bool reusedIndexes = false;
  bool sawFirstRowOnSecondLookup = false;

  @override
  ProjectDto? calculate({
    required Map<String, ProjectDto> projectsById,
    required Map<String, ProjectDto> projectsByNormalizedPath,
    required String preferredProjectId,
    required String observedPath,
  }) {
    if (callCount == 0) {
      _firstProjectsById = projectsById;
      _firstProjectsByNormalizedPath = projectsByNormalizedPath;
    } else if (callCount == 1) {
      reusedIndexes =
          identical(_firstProjectsById, projectsById) &&
          identical(_firstProjectsByNormalizedPath, projectsByNormalizedPath);
      sawFirstRowOnSecondLookup =
          projectsById[firstProjectId]?.projectId == firstProjectId &&
          projectsByNormalizedPath[normalizeProjectDirectory(directory: firstPath)]?.projectId == firstProjectId;
    }
    callCount++;
    return super.calculate(
      projectsById: projectsById,
      projectsByNormalizedPath: projectsByNormalizedPath,
      preferredProjectId: preferredProjectId,
      observedPath: observedPath,
    );
  }
}

CatalogImportRepository _repository({required AppDatabase database, required BridgePluginApi plugin}) {
  return singlePluginCatalogImportRepository(
    plugin: plugin,
    projectsDao: database.projectsDao,
    sessionDao: database.sessionDao,
    catalogHydrationsDao: database.catalogHydrationsDao,
  );
}

ProjectDto _projectRow({required String id, required String path, int updatedAt = 20}) {
  return ProjectDto(
    projectId: id,
    path: path,
    hidden: false,
    baseBranch: null,
    displayName: null,
    createdAt: 10,
    updatedAt: updatedAt,
    projectionUpdatedAt: 20,
  );
}

SessionDto _sessionRow({
  required String sessionId,
  required String backendSessionId,
  required String projectId,
  required String directory,
  String? worktreePath,
  String pluginId = "native",
  int? archivedAt,
  String? title,
  String? catalogTitle,
  required int projectionUpdatedAt,
  int updatedAt = 20,
}) {
  return SessionDto(
    sessionId: sessionId,
    backendSessionId: backendSessionId,
    projectId: projectId,
    parentSessionId: null,
    directory: directory,
    worktreePath: worktreePath,
    branchName: worktreePath == null ? null : "feature",
    isDedicated: worktreePath != null,
    archivedAt: archivedAt,
    baseBranch: "main",
    baseCommit: "abc123",
    lastAgent: "agent",
    lastAgentModel: null,
    createdAt: 10,
    updatedAt: updatedAt,
    projectionUpdatedAt: projectionUpdatedAt,
    lastActivityAt: 18,
    lastSeenAt: 17,
    lastUserMessageAt: 16,
    pluginId: pluginId,
    title: title,
    catalogTitle: catalogTitle,
  );
}

PluginSession _pluginSession({
  required String id,
  required String directory,
  String? parentId,
  String? title,
  int? archivedAt,
  int updatedAt = 100,
}) {
  return PluginSession(
    id: id,
    projectID: directory,
    directory: directory,
    parentID: parentId,
    title: title,
    time: PluginSessionTime(created: 1, updated: updatedAt, archived: archivedAt),
  );
}

class _NativeImportPlugin implements NativeProjectsPluginApi {
  _NativeImportPlugin({
    required this.projects,
    required this.rootsByProject,
    required this.childrenByParent,
    this.getProjectsGate,
    this.onGetSessions,
  });

  final List<PluginProject> projects;
  final Map<String, List<PluginSession>> rootsByProject;
  final Map<String, List<PluginSession>> childrenByParent;
  final Completer<void>? getProjectsGate;
  final Future<void> Function(String projectId)? onGetSessions;
  final Completer<void> getProjectsStarted = Completer<void>();

  @override
  String get id => "native";

  @override
  Future<List<PluginProject>> getProjects() async {
    if (!getProjectsStarted.isCompleted) getProjectsStarted.complete();
    await getProjectsGate?.future;
    return projects;
  }

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) async {
    await onGetSessions?.call(projectId);
    return rootsByProject[projectId] ?? const [];
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async {
    return childrenByParent[sessionId] ?? const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DerivedImportPlugin implements BridgeDerivedProjectsPluginApi {
  _DerivedImportPlugin({required this.launchDirectory, required this.sessions});

  @override
  final String launchDirectory;
  final List<PluginSession> sessions;
  Set<String>? knownDirectories;

  @override
  String get id => "derived";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    this.knownDirectories = knownDirectories;
    return sessions;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
