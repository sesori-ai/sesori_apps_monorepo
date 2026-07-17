import "dart:collection";
import "dart:math";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/catalog_hydrations_dao.dart";
import "../api/database/daos/projects_dao.dart";
import "../api/database/daos/session_dao.dart";
import "../api/database/tables/catalog_hydrations_table.dart";
import "../api/database/tables/projects_table.dart";
import "../api/database/tables/session_table.dart";
import "models/catalog_import_control.dart";

class CatalogImportRepository {
  CatalogImportRepository({
    required BridgePluginApi plugin,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required CatalogHydrationsDao catalogHydrationsDao,
  }) : _plugin = plugin,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _catalogHydrationsDao = catalogHydrationsDao;

  static const int projectionVersion = 1;
  static const int _responsivenessBatchSize = 512;
  static final Random _secureRandom = Random.secure();

  final BridgePluginApi _plugin;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final CatalogHydrationsDao _catalogHydrationsDao;

  String get pluginId => _plugin.id;

  Future<CatalogHydrationDto?> getHydrationCompletion() {
    return _catalogHydrationsDao.getCompletion(
      pluginId: pluginId,
      projectionVersion: projectionVersion,
    );
  }

  Stream<CatalogImportProgress> importCatalog({required CatalogImportControl control}) async* {
    final importStartedAt = DateTime.now().millisecondsSinceEpoch;
    final observedProjects = <String, _ObservedProject>{};
    final observedSessions = <String, _ObservedSession>{};
    var derivedProjectPathsByBackendId = const <String, String>{};
    String? derivedLaunchDirectory;

    yield CatalogImportProgress.enumerating(
      pluginId: pluginId,
      projectsSeen: 0,
      sessionsSeen: 0,
    );
    if (control.cancellationRequested) {
      yield CatalogImportProgress.cancelled(pluginId: pluginId);
      return;
    }

    switch (_plugin) {
      case NativeProjectsPluginApi():
        final projects = await _plugin.getProjects();
        if (control.cancellationRequested) {
          yield CatalogImportProgress.cancelled(pluginId: pluginId);
          return;
        }
        for (final project in projects) {
          final path = _normalizeRequiredPath(project.directory);
          _mergeObservedProject(
            observedProjects,
            _ObservedProject(
              preferredId: project.id,
              path: path,
              displayName: _usefulText(project.name),
              createdAt: project.activity?.createdAt,
              updatedAt: project.activity?.updatedAt,
            ),
          );
        }
        yield CatalogImportProgress.enumerating(
          pluginId: pluginId,
          projectsSeen: observedProjects.length,
          sessionsSeen: observedSessions.length,
        );

        for (final project in projects) {
          if (control.cancellationRequested) {
            yield CatalogImportProgress.cancelled(pluginId: pluginId);
            return;
          }
          final projectPath = _normalizeRequiredPath(project.directory);
          final roots = await _plugin.getSessions(projectPath);
          if (control.cancellationRequested) {
            yield CatalogImportProgress.cancelled(pluginId: pluginId);
            return;
          }
          final pendingChildren = Queue<PluginSession>();
          for (final session in roots) {
            _recordObservedSession(
              observedSessions,
              _ObservedSession(session: session, rootProjectPath: projectPath),
            );
            pendingChildren.add(session);
            if (observedSessions.length % _responsivenessBatchSize == 0) {
              await Future<void>.delayed(Duration.zero);
            }
          }
          yield CatalogImportProgress.enumerating(
            pluginId: pluginId,
            projectsSeen: observedProjects.length,
            sessionsSeen: observedSessions.length,
          );

          final expanded = <String>{};
          while (pendingChildren.isNotEmpty) {
            final parent = pendingChildren.removeFirst();
            if (!expanded.add(parent.id)) continue;
            if (control.cancellationRequested) {
              yield CatalogImportProgress.cancelled(pluginId: pluginId);
              return;
            }
            final children = await _plugin.getChildSessions(parent.id);
            if (control.cancellationRequested) {
              yield CatalogImportProgress.cancelled(pluginId: pluginId);
              return;
            }
            for (final child in children) {
              final observedChild = child.copyWith(parentID: parent.id);
              _recordObservedSession(
                observedSessions,
                _ObservedSession(session: observedChild, rootProjectPath: null),
              );
              pendingChildren.add(observedChild);
            }
            yield CatalogImportProgress.enumerating(
              pluginId: pluginId,
              projectsSeen: observedProjects.length,
              sessionsSeen: observedSessions.length,
            );
          }
        }
      case BridgeDerivedProjectsPluginApi():
        final storedProjects = await _projectsDao.getAllProjects();
        if (control.cancellationRequested) {
          yield CatalogImportProgress.cancelled(pluginId: pluginId);
          return;
        }
        final storedSessionPaths = await _sessionDao.getSessionProjectPaths(pluginId: pluginId);
        if (control.cancellationRequested) {
          yield CatalogImportProgress.cancelled(pluginId: pluginId);
          return;
        }
        final launchDirectory = _normalizeRequiredPath(_plugin.launchDirectory);
        derivedLaunchDirectory = launchDirectory;
        derivedProjectPathsByBackendId = {
          for (final row in storedSessionPaths) row.backendSessionId: _normalizeRequiredPath(row.projectPath),
        };
        final knownDirectories = <String>{
          launchDirectory,
          for (final project in storedProjects) _normalizeRequiredPath(project.path),
          for (final row in storedSessionPaths) _normalizeRequiredPath(row.projectPath),
          for (final row in storedSessionPaths)
            if (_usefulText(row.worktreePath) case final worktreePath?) _normalizeRequiredPath(worktreePath),
        };
        _mergeObservedProject(
          observedProjects,
          _ObservedProject(
            preferredId: launchDirectory,
            path: launchDirectory,
            displayName: null,
            createdAt: null,
            updatedAt: null,
          ),
        );
        final sessions = await _plugin.listAllSessions(knownDirectories: knownDirectories);
        if (control.cancellationRequested) {
          yield CatalogImportProgress.cancelled(pluginId: pluginId);
          return;
        }
        for (final session in sessions) {
          _recordObservedSession(
            observedSessions,
            _ObservedSession(
              session: session,
              rootProjectPath: session.parentID == null ? _normalizeRequiredPath(session.directory) : null,
            ),
          );
          if (observedSessions.length % _responsivenessBatchSize == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
        yield CatalogImportProgress.enumerating(
          pluginId: pluginId,
          projectsSeen: observedProjects.length,
          sessionsSeen: observedSessions.length,
        );
    }

    // Reject malformed ancestry before publication work starts. Tombstones are
    // re-read and applied with the same validation inside the transaction.
    final ancestryValidated = _validOrderedSessions(
      observedSessions: observedSessions,
      omittedBackendIds: const {},
    );
    if (_plugin is BridgeDerivedProjectsPluginApi) {
      for (final observation in ancestryValidated) {
        if (observation.session.parentID != null) continue;
        final projectPath =
            derivedProjectPathsByBackendId[observation.session.id] ??
            _normalizeRequiredPath(observation.session.directory);
        final time = observation.session.time;
        observation.rootProjectPath = projectPath;
        _mergeObservedProject(
          observedProjects,
          _ObservedProject(
            preferredId: projectPath,
            path: projectPath,
            displayName: null,
            createdAt: time?.created,
            updatedAt: time?.updated,
          ),
        );
      }
    }
    yield CatalogImportProgress.enumerating(
      pluginId: pluginId,
      projectsSeen: observedProjects.length,
      sessionsSeen: ancestryValidated.length,
    );

    yield CatalogImportProgress.committing(
      pluginId: pluginId,
      projectsSeen: observedProjects.length,
      sessionsSeen: ancestryValidated.length,
    );
    if (control.cancellationRequested) {
      yield CatalogImportProgress.cancelled(pluginId: pluginId);
      return;
    }

    final result = await _sessionDao.attachedDatabase.transaction(() async {
      final currentProjects = await _projectsDao.getAllProjects();
      final tombstones = await _sessionDao.getTombstonedSessionIds(pluginId: pluginId);
      final orderedSessions = _validOrderedSessions(
        observedSessions: observedSessions,
        omittedBackendIds: tombstones,
      );
      final currentBindings = await _sessionDao.getSessionsForPlugin(pluginId: pluginId);

      final projectsById = <String, ProjectDto>{
        for (final project in currentProjects) project.projectId: project,
      };
      final projectsByPath = <String, ProjectDto>{};
      for (final project in currentProjects) {
        projectsByPath.putIfAbsent(_normalizeRequiredPath(project.path), () => project);
      }

      final publicationProjects = <String, _ObservedProject>{};
      if (_plugin is BridgeDerivedProjectsPluginApi) {
        final launchDirectory = derivedLaunchDirectory!;
        _mergeObservedProject(publicationProjects, observedProjects[launchDirectory]!);
        for (final observation in orderedSessions) {
          if (observation.session.parentID != null) continue;
          final existing = currentBindings[observation.session.id];
          final existingProject = existing == null ? null : projectsById[existing.projectId];
          final projectPath = existingProject == null
              ? _normalizeRequiredPath(observation.session.directory)
              : _normalizeRequiredPath(existingProject.path);
          final time = observation.session.time;
          _mergeObservedProject(
            publicationProjects,
            _ObservedProject(
              preferredId: existingProject?.projectId ?? projectPath,
              path: projectPath,
              displayName: null,
              createdAt: time?.created,
              updatedAt: time?.updated,
            ),
          );
          observation.rootProjectPath = projectPath;
        }
      } else {
        publicationProjects.addAll(observedProjects);
      }

      final projectRows = <ProjectDto>[];
      final importedProjectIdByPath = <String, String>{};
      for (final observation in publicationProjects.values) {
        final existing = projectsByPath[observation.path] ?? projectsById[observation.preferredId];
        final row = _mergeProjectRow(
          observation: observation,
          existing: existing,
          importStartedAt: importStartedAt,
        );
        projectRows.add(row);
        projectsById[row.projectId] = row;
        projectsByPath[observation.path] = row;
        importedProjectIdByPath[observation.path] = row.projectId;
      }

      final reservedIds = await _sessionDao.getAllSessionIds();

      final sessionRows = <SessionDto>[];
      final finalRowsByBackendId = <String, SessionDto>{};
      for (final observation in orderedSessions) {
        final session = observation.session;
        final existing = currentBindings[session.id];
        final parent = session.parentID == null ? null : finalRowsByBackendId[session.parentID];
        final rootProjectPath = observation.rootProjectPath;
        final projectId =
            parent?.projectId ??
            (rootProjectPath == null ? null : importedProjectIdByPath[_normalizeRequiredPath(rootProjectPath)]);
        if (projectId == null) {
          throw StateError("plugin $pluginId returned session ${session.id} without a publishable project");
        }
        final row = _mergeSessionRow(
          observation: observation,
          existing: existing,
          sessionId: existing?.sessionId ?? _allocateSessionId(reservedIds: reservedIds),
          parentSessionId: parent?.sessionId,
          projectId: projectId,
          importStartedAt: importStartedAt,
        );
        sessionRows.add(row);
        finalRowsByBackendId[session.id] = row;
        if (sessionRows.length % _responsivenessBatchSize == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      await _projectsDao.upsertProjectRows(rows: projectRows);
      await _sessionDao.upsertSessionRows(rows: sessionRows);
      final completedAt = DateTime.now().millisecondsSinceEpoch;
      if (control.hydrationMarkerRequested) {
        await _catalogHydrationsDao.recordCompletion(
          completion: CatalogHydrationDto(
            pluginId: pluginId,
            projectionVersion: projectionVersion,
            completedAt: completedAt,
          ),
        );
      }
      return (
        projectsImported: projectRows.length,
        sessionsImported: sessionRows.length,
        completedAt: completedAt,
      );
    });

    yield CatalogImportProgress.completed(
      pluginId: pluginId,
      projectsImported: result.projectsImported,
      sessionsImported: result.sessionsImported,
      completedAt: result.completedAt,
    );
  }

  ProjectDto _mergeProjectRow({
    required _ObservedProject observation,
    required ProjectDto? existing,
    required int importStartedAt,
  }) {
    if (existing != null && existing.projectionUpdatedAt > importStartedAt) return existing;
    return ProjectDto(
      projectId: existing?.projectId ?? observation.preferredId,
      path: observation.path,
      hidden: existing?.hidden ?? false,
      baseBranch: existing?.baseBranch,
      displayName: existing?.displayName ?? observation.displayName,
      createdAt: existing?.createdAt ?? observation.createdAt ?? importStartedAt,
      updatedAt: observation.updatedAt ?? existing?.updatedAt ?? importStartedAt,
      projectionUpdatedAt: importStartedAt,
    );
  }

  SessionDto _mergeSessionRow({
    required _ObservedSession observation,
    required SessionDto? existing,
    required String sessionId,
    required String? parentSessionId,
    required String projectId,
    required int importStartedAt,
  }) {
    if (existing != null && existing.projectionUpdatedAt > importStartedAt) return existing;
    final session = observation.session;
    final time = session.time;
    final createdAt = existing?.createdAt ?? time?.created ?? importStartedAt;
    return SessionDto(
      sessionId: sessionId,
      backendSessionId: session.id,
      projectId: projectId,
      parentSessionId: parentSessionId,
      directory: existing?.directory ?? _normalizeRequiredPath(session.directory),
      worktreePath: existing?.worktreePath,
      branchName: existing?.branchName,
      isDedicated: existing?.isDedicated ?? false,
      archivedAt: existing == null ? time?.archived : existing.archivedAt,
      baseBranch: existing?.baseBranch,
      baseCommit: existing?.baseCommit,
      lastAgent: existing?.lastAgent,
      lastAgentModel: existing?.lastAgentModel,
      createdAt: createdAt,
      updatedAt: max(time?.updated ?? createdAt, existing?.updatedAt ?? createdAt),
      projectionUpdatedAt: importStartedAt,
      lastActivityAt: existing?.lastActivityAt,
      lastSeenAt: existing?.lastSeenAt,
      lastUserMessageAt: existing?.lastUserMessageAt,
      pluginId: pluginId,
      title: existing?.title,
      catalogTitle: _usefulText(session.title),
    );
  }

  String _allocateSessionId({required Set<String> reservedIds}) {
    while (true) {
      final buffer = StringBuffer("ses_");
      for (var index = 0; index < 16; index++) {
        buffer.write(_secureRandom.nextInt(256).toRadixString(16).padLeft(2, "0"));
      }
      final candidate = buffer.toString();
      if (reservedIds.add(candidate)) return candidate;
    }
  }

  List<_ObservedSession> _validOrderedSessions({
    required Map<String, _ObservedSession> observedSessions,
    required Set<String> omittedBackendIds,
  }) {
    final validity = <String, bool>{};
    final depths = <String, int>{};

    bool validate(String backendId, Set<String> visiting) {
      final known = validity[backendId];
      if (known != null) return known;
      final observation = observedSessions[backendId];
      if (observation == null || omittedBackendIds.contains(backendId) || !visiting.add(backendId)) {
        validity[backendId] = false;
        return false;
      }
      final parentId = observation.session.parentID;
      final valid = parentId == null || validate(parentId, visiting);
      visiting.remove(backendId);
      validity[backendId] = valid;
      if (valid) depths[backendId] = parentId == null ? 0 : (depths[parentId] ?? 0) + 1;
      return valid;
    }

    for (final backendId in observedSessions.keys) {
      validate(backendId, <String>{});
    }
    final result = [
      for (final entry in observedSessions.entries)
        if (validity[entry.key] ?? false) entry.value,
    ];
    result.sort((a, b) => (depths[a.session.id] ?? 0).compareTo(depths[b.session.id] ?? 0));

    final rootPathByBackendId = <String, String>{};
    for (final observation in result) {
      final parentId = observation.session.parentID;
      if (parentId == null) {
        final rootPath = observation.rootProjectPath;
        if (rootPath != null) rootPathByBackendId[observation.session.id] = rootPath;
      } else {
        final rootPath = rootPathByBackendId[parentId];
        if (rootPath != null) {
          observation.rootProjectPath = rootPath;
          rootPathByBackendId[observation.session.id] = rootPath;
        }
      }
    }
    return result;
  }

  void _recordObservedSession(
    Map<String, _ObservedSession> observations,
    _ObservedSession observation,
  ) {
    final existing = observations[observation.session.id];
    if (existing == null) {
      observations[observation.session.id] = observation;
      return;
    }
    if (existing.session != observation.session) {
      throw StateError("plugin $pluginId returned conflicting session ${observation.session.id}");
    }
    existing.rootProjectPath ??= observation.rootProjectPath;
  }

  void _mergeObservedProject(
    Map<String, _ObservedProject> observations,
    _ObservedProject observation,
  ) {
    final existing = observations[observation.path];
    if (existing == null) {
      observations[observation.path] = observation;
      return;
    }
    existing.displayName ??= observation.displayName;
    if (observation.createdAt case final createdAt?) {
      existing.createdAt = existing.createdAt == null ? createdAt : min(existing.createdAt!, createdAt);
    }
    if (observation.updatedAt case final updatedAt?) {
      existing.updatedAt = existing.updatedAt == null ? updatedAt : max(existing.updatedAt!, updatedAt);
    }
  }

  String _normalizeRequiredPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) throw StateError("plugin $pluginId returned an empty catalog path");
    return normalizeProjectDirectory(directory: trimmed);
  }

  String? _usefulText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : value;
  }
}

class _ObservedProject {
  _ObservedProject({
    required this.preferredId,
    required this.path,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String preferredId;
  final String path;
  String? displayName;
  int? createdAt;
  int? updatedAt;
}

class _ObservedSession {
  _ObservedSession({required this.session, required this.rootProjectPath});

  final PluginSession session;
  String? rootProjectPath;
}
