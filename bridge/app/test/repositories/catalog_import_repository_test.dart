import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/api/database/daos/session_dao.dart";
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

import "../helpers/plugin_runtime_test_support.dart";

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
        runtime: createTestPluginRuntime(plugins: [plugin]),
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

    test("publishes projects before ancestry-ordered session batches of at most 512", () async {
      final projectPath = "${directory.path}/batched";
      final roots = [
        for (var index = 0; index < 512; index++)
          _pluginSession(
            id: "root-$index",
            directory: projectPath,
          ),
      ];
      final parentBackendId = roots.last.id;
      final plugin = _NativeImportPlugin(
        projects: [PluginProject(id: "batched", directory: projectPath)],
        rootsByProject: {projectPath: roots},
        childrenByParent: {
          parentBackendId: [
            _pluginSession(
              id: "boundary-child",
              parentId: parentBackendId,
              directory: projectPath,
            ),
          ],
        },
      );
      final sessionDao = _RecordingSessionDao(
        database: database,
        failOnWriteCall: null,
      );
      final repository = CatalogImportRepository(
        runtime: createTestPluginRuntime(plugins: [plugin]),
        projectsDao: database.projectsDao,
        sessionDao: sessionDao,
        catalogHydrationsDao: database.catalogHydrationsDao,
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
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

      expect(sessionDao.writeBatchSizes, [512, 1]);
      expect(sessionDao.projectsExistedAtWrite, everyElement(isTrue));
      expect(sessionDao.backendIdsByWrite.last, ["boundary-child"]);
      final parent = await database.sessionDao.getSessionByBinding(
        pluginId: plugin.id,
        backendSessionId: parentBackendId,
      );
      final child = await database.sessionDao.getSessionByBinding(
        pluginId: plugin.id,
        backendSessionId: "boundary-child",
      );
      expect(child?.parentSessionId, parent?.sessionId);
      expect(await database.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
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

    test("root-only import filters tombstones", () async {
      final projectPath = "${directory.path}/root-only";
      await database.sessionDao.insertSessionTombstone(
        backendSessionId: "deleted-root",
        pluginId: "derived",
        deletedAt: 30,
      );
      final plugin = _DerivedImportPlugin(
        launchDirectory: projectPath,
        sessions: [
          _pluginSession(id: "live-root", directory: projectPath),
          _pluginSession(id: "deleted-root", directory: projectPath),
        ],
      );

      final statuses = await _repository(database: database, plugin: plugin)
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .toList();

      expect(statuses.whereType<CatalogImportCompleted>().single.sessionsImported, 1);
      expect(
        await database.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "live-root",
        ),
        isNotNull,
      );
      expect(
        await database.sessionDao.getSessionByBinding(
          pluginId: plugin.id,
          backendSessionId: "deleted-root",
        ),
        isNull,
      );
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

    test("consumer cancellation at committing releases the import stream without publication", () async {
      final projectPath = "${directory.path}/cancel-committing";
      final plugin = _NativeImportPlugin(
        projects: [PluginProject(id: "cancel-committing", directory: projectPath)],
        rootsByProject: const {},
        childrenByParent: const {},
      );
      final repository = _repository(database: database, plugin: plugin);
      late StreamSubscription<CatalogImportProgress> subscription;
      late Future<void> cancellation;
      final cancellationStarted = Completer<void>();
      subscription = repository
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .listen((status) {
            if (status is! CatalogImportCommitting) return;
            cancellation = subscription.cancel();
            cancellationStarted.complete();
          });

      await cancellationStarted.future;
      await cancellation.timeout(const Duration(seconds: 1));

      expect(await database.projectsDao.getAllProjects(), isEmpty);
    });

    test("generation replacement at committing prevents stale publication", () async {
      final projectPath = "${directory.path}/stale-generation";
      final plugin = _NativeImportPlugin(
        projects: [PluginProject(id: "stale-generation", directory: projectPath)],
        rootsByProject: const {},
        childrenByParent: const {},
      );
      final runtime = createTestPluginRuntime(plugins: [plugin]);
      final repository = CatalogImportRepository(
        runtime: runtime,
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        catalogHydrationsDao: database.catalogHydrationsDao,
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
      );
      final finished = Completer<void>();
      Object? streamError;
      repository
          .importCatalog(
            pluginId: plugin.id,
            control: CatalogImportControl(
              explicitImportRequested: true,
              hydrationMarkerRequested: false,
            ),
          )
          .listen(
            (status) {
              if (status is CatalogImportCommitting) runtime.generationCurrent = false;
            },
            onError: (Object error) {
              streamError = error;
              if (!finished.isCompleted) finished.complete();
            },
            onDone: () {
              if (!finished.isCompleted) finished.complete();
            },
          );

      await finished.future;

      expect(streamError, isA<PluginOperationException>());
      expect(await database.projectsDao.getAllProjects(), isEmpty);
      await runtime.dispose();
    });

    test("a later session batch failure rolls the entire publication back", () async {
      final projectPath = "${directory.path}/rollback";
      final plugin = _NativeImportPlugin(
        projects: [PluginProject(id: "rollback", directory: projectPath)],
        rootsByProject: {
          projectPath: [
            for (var index = 0; index < 513; index++)
              _pluginSession(
                id: "root-$index",
                directory: projectPath,
              ),
          ],
        },
        childrenByParent: const {},
      );
      final sessionDao = _RecordingSessionDao(
        database: database,
        failOnWriteCall: 2,
      );
      final repository = CatalogImportRepository(
        runtime: createTestPluginRuntime(plugins: [plugin]),
        projectsDao: database.projectsDao,
        sessionDao: sessionDao,
        catalogHydrationsDao: database.catalogHydrationsDao,
        projectCatalogIdentityCalculator: const ProjectCatalogIdentityCalculator(),
      );

      await expectLater(
        repository
            .importCatalog(
              pluginId: plugin.id,
              control: CatalogImportControl(
                explicitImportRequested: false,
                hydrationMarkerRequested: true,
              ),
            )
            .drain<void>(),
        throwsA(anything),
      );

      expect(sessionDao.writeBatchSizes, [512, 1]);
      expect(await database.projectsDao.getProject(projectId: "rollback"), isNull);
      expect(await database.sessionDao.getSessionsForPlugin(pluginId: plugin.id), isEmpty);
      expect(await repository.getHydrationCompletion(pluginId: plugin.id), isNull);
    });
  });
}

class _RecordingSessionDao extends SessionDao {
  _RecordingSessionDao({
    required AppDatabase database,
    required this.failOnWriteCall,
  }) : super(database);

  final int? failOnWriteCall;
  final List<int> writeBatchSizes = [];
  final List<List<String>> backendIdsByWrite = [];
  final List<bool> projectsExistedAtWrite = [];

  @override
  Future<void> upsertSessionRows({required List<SessionDto> rows}) async {
    writeBatchSizes.add(rows.length);
    backendIdsByWrite.add([
      for (final row in rows) row.backendSessionId,
    ]);
    final projectIds = {
      for (final row in rows) row.projectId,
    };
    final projects = await Future.wait([
      for (final projectId in projectIds) attachedDatabase.projectsDao.getProject(projectId: projectId),
    ]);
    projectsExistedAtWrite.add(projects.every((project) => project != null));
    if (writeBatchSizes.length == failOnWriteCall) {
      throw StateError("injected session batch failure");
    }
    await super.upsertSessionRows(rows: rows);
  }
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
