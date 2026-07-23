import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeDerivedProjectsPluginApi, BridgePluginApi, NativeProjectsPluginApi, PluginProject, PluginSessionTime;

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/session_dao.dart" show SessionDao;
import "../../api/database/tables/projects_table.dart" show ProjectDto;
import "../../repositories/project_catalog_identity_calculator.dart";
import "../runtime/plugin_runtime.dart";
import "models/project_activity_evidence.dart";

/// Collects plugin evidence used to reconcile bridge-owned project activity.
class ProjectActivityRepository {
  ProjectActivityRepository({
    required PluginRuntime runtime,
    required ProjectsDao projectsDao,
    required SessionDao sessionDao,
    required ProjectCatalogIdentityCalculator projectCatalogIdentityCalculator,
    required Duration aggregateSourceDeadline,
  }) : _runtime = runtime,
       _projectsDao = projectsDao,
       _sessionDao = sessionDao,
       _projectCatalogIdentityCalculator = projectCatalogIdentityCalculator,
       _aggregateSourceDeadline = aggregateSourceDeadline;

  final PluginRuntime _runtime;
  final ProjectsDao _projectsDao;
  final SessionDao _sessionDao;
  final ProjectCatalogIdentityCalculator _projectCatalogIdentityCalculator;
  final Duration _aggregateSourceDeadline;

  Set<String> get operationalPluginIds => _runtime.activePluginIds;

  Future<List<ProjectActivityEvidence>> listProjectActivityEvidence({required String pluginId}) async {
    final source = await _runtime
        .useIfActive<_ProjectActivitySource>(
          pluginId: pluginId,
          operation: _ProjectActivityOperation.listProjectActivityEvidence,
          body: (plugin, generation) => _loadProjectActivitySource(
            plugin: plugin,
            generation: generation,
          ),
        )
        .timeout(_aggregateSourceDeadline);
    if (source == null) return const <ProjectActivityEvidence>[];
    switch (source) {
      case _NativeProjectActivitySource():
        return _persistNativeProjectActivityEvidence(source: source);
      case _ResolvedProjectActivitySource(:final evidence):
        _requireCurrentProjectActivitySource(source);
        return evidence;
    }
  }

  Future<_ProjectActivitySource> _loadProjectActivitySource({
    required BridgePluginApi plugin,
    required int generation,
  }) async {
    switch (plugin) {
      case final NativeProjectsPluginApi plugin:
        return _NativeProjectActivitySource(
          pluginId: plugin.id,
          generation: generation,
          projects: await plugin.getProjects(),
        );
      case final BridgeDerivedProjectsPluginApi plugin:
        final (storedProjects, sessionProjectPaths, tombstoned) = await (
          _projectsDao.getAllProjects(),
          _sessionDao.getSessionProjectPaths(pluginId: plugin.id),
          _sessionDao.getTombstonedSessionIds(pluginId: plugin.id),
        ).wait;
        final sessions = await plugin.listAllSessions(
          knownDirectories: {
            for (final stored in storedProjects) stored.path,
            for (final row in sessionProjectPaths) ?row.worktreePath,
          },
        );
        final pathBySessionId = {
          for (final row in sessionProjectPaths) row.backendSessionId: row.projectPath,
        };
        final grouped = <String, List<PluginSessionTime>>{};
        for (final session in sessions) {
          if (tombstoned.contains(session.id)) continue;
          final time = session.time;
          if (time == null) continue;
          final projectPath = pathBySessionId[session.id] ?? session.directory;
          final key = normalizeProjectDirectory(directory: projectPath);
          grouped.putIfAbsent(key, () => []).add(time);
        }
        final projectsById = <String, ProjectDto>{
          for (final project in storedProjects) project.projectId: project,
        };
        final projectsByNormalizedPath = _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
          projects: storedProjects,
        );
        final evidence = <ProjectActivityEvidence>[];
        for (final entry in grouped.entries) {
          final stored = _projectCatalogIdentityCalculator.calculate(
            projectsById: projectsById,
            projectsByNormalizedPath: projectsByNormalizedPath,
            preferredProjectId: entry.key,
            observedPath: entry.key,
          );
          if (stored == null) continue;
          evidence.add(
            ProjectActivityEvidence(
              pluginId: plugin.id,
              projectId: stored.projectId,
              pluginActivity: null,
              sessionActivities: entry.value,
            ),
          );
        }
        return _ResolvedProjectActivitySource(
          pluginId: plugin.id,
          generation: generation,
          evidence: evidence,
        );
    }
  }

  Future<List<ProjectActivityEvidence>> _persistNativeProjectActivityEvidence({
    required _NativeProjectActivitySource source,
  }) {
    return _projectsDao.transaction(() async {
      final storedProjects = (await _projectsDao.getAllProjects()).toList();
      final projectsById = <String, ProjectDto>{
        for (final project in storedProjects) project.projectId: project,
      };
      final projectsByNormalizedPath = _projectCatalogIdentityCalculator.buildProjectsByNormalizedPath(
        projects: storedProjects,
      );
      final missingProjects = <String, ({String path, int? createdAt, int? updatedAt})>{};
      final evidence = <ProjectActivityEvidence>[];
      for (final project in source.projects) {
        final existing = _projectCatalogIdentityCalculator.calculate(
          projectsById: projectsById,
          projectsByNormalizedPath: projectsByNormalizedPath,
          preferredProjectId: project.id,
          observedPath: project.directory,
        );
        final projectId = existing?.projectId ?? project.id;
        if (existing == null) {
          missingProjects[projectId] = (
            path: project.directory,
            createdAt: project.activity?.createdAt,
            updatedAt: project.activity?.updatedAt,
          );
          final inserted = ProjectDto(
            projectId: projectId,
            path: project.directory,
            createdAt: project.activity?.createdAt ?? 0,
            updatedAt: project.activity?.updatedAt ?? 0,
            projectionUpdatedAt: 0,
          );
          projectsById[projectId] = inserted;
          projectsByNormalizedPath[normalizeProjectDirectory(directory: project.directory)] = inserted;
        }
        evidence.add(
          ProjectActivityEvidence(
            pluginId: source.pluginId,
            projectId: projectId,
            pluginActivity: project.activity,
            sessionActivities: const [],
          ),
        );
      }
      _requireCurrentProjectActivitySource(source);
      await _projectsDao.insertProjectsWithPathsIfMissing(
        projects: missingProjects,
      );
      _requireCurrentProjectActivitySource(source);
      return evidence;
    });
  }

  void _requireCurrentProjectActivitySource(_ProjectActivitySource source) {
    _runtime.requireCurrentGeneration(
      pluginId: source.pluginId,
      generation: source.generation,
      operation: _ProjectActivityOperation.listProjectActivityEvidence,
    );
  }
}

enum _ProjectActivityOperation { listProjectActivityEvidence }

sealed class _ProjectActivitySource {
  const _ProjectActivitySource({required this.pluginId, required this.generation});

  final String pluginId;
  final int generation;
}

final class _NativeProjectActivitySource extends _ProjectActivitySource {
  const _NativeProjectActivitySource({
    required super.pluginId,
    required super.generation,
    required this.projects,
  });

  final List<PluginProject> projects;
}

final class _ResolvedProjectActivitySource extends _ProjectActivitySource {
  const _ResolvedProjectActivitySource({
    required super.pluginId,
    required super.generation,
    required this.evidence,
  });

  final List<ProjectActivityEvidence> evidence;
}
