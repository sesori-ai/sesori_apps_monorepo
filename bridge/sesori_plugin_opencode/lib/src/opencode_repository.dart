import "package:sesori_shared/sesori_shared.dart" show wait2;

import "models/project.dart";
import "models/session.dart";
import "opencode_api.dart";

const String _globalProjectId = "global";

class OpenCodeRepository {
  final OpenCodeApi _api;

  OpenCodeRepository(this._api);

  OpenCodeApi get api => _api;

  Future<List<Project>> getProjects() async {
    final (rawProjects, globalSessions) = await wait2(
      _api.listProjects(),
      _api.listGlobalSessions(directory: null, roots: true),
    );

    final realProjects = <Project>[];
    final projectByWorktree = <String, Project>{};
    String? globalWorktree;

    for (final project in rawProjects) {
      if (project.id == _globalProjectId) {
        globalWorktree = project.worktree;
        continue;
      }
      realProjects.add(project);
      projectByWorktree[project.worktree] = project;
    }

    final globalByDirectory = _groupGlobalSessionsByDirectory(globalSessions);

    final mergedRealProjects = realProjects.map((project) {
      final groupedSessions = globalByDirectory[project.worktree];
      if (groupedSessions == null) return project;
      return _mergeProjectTimeWithSessions(
        project: project,
        sessions: groupedSessions,
      );
    }).toList();

    final virtualProjects = _buildVirtualProjects(
      globalByDirectory: globalByDirectory,
      projectByWorktree: projectByWorktree,
      realProjects: realProjects,
      globalWorktree: globalWorktree,
    );

    return [...mergedRealProjects, ...virtualProjects];
  }

  Future<List<Session>> getSessions({required String worktree}) async {
    final (standardSessions, globalSessions) = await wait2(
      _api.listSessions(directory: worktree),
      _api.listGlobalSessions(directory: worktree, roots: true),
    );

    final merged = <Session>[];
    final seenIds = <String>{};

    for (final session in standardSessions) {
      seenIds.add(session.id);
      merged.add(session);
    }

    for (final global in globalSessions) {
      if (seenIds.contains(global.id)) continue;
      seenIds.add(global.id);
      merged.add(
        Session(
          id: global.id,
          projectID: global.projectID,
          directory: global.directory,
          parentID: global.parentID,
          title: global.title,
          time: global.time,
          summary: global.summary,
        ),
      );
    }

    final filtered = merged.where((session) {
      if (session.parentID != null) return false;
      return _isDirectoryUnderWorktree(session.directory, worktree);
    }).toList();

    filtered.sort((a, b) {
      final updatedA = a.time?.updated ?? 0;
      final updatedB = b.time?.updated ?? 0;
      return updatedB.compareTo(updatedA);
    });

    return filtered;
  }

  Map<String, List<GlobalSession>> _groupGlobalSessionsByDirectory(
    List<GlobalSession> sessions,
  ) {
    final grouped = <String, List<GlobalSession>>{};
    for (final session in sessions) {
      if (session.projectID != _globalProjectId) continue;
      if (session.directory.isEmpty) continue;
      grouped.putIfAbsent(session.directory, () => []).add(session);
    }
    return grouped;
  }

  List<Project> _buildVirtualProjects({
    required Map<String, List<GlobalSession>> globalByDirectory,
    required Map<String, Project> projectByWorktree,
    required List<Project> realProjects,
    required String? globalWorktree,
  }) {
    final virtual = <Project>[];

    for (final entry in globalByDirectory.entries) {
      final directory = entry.key;
      final groupedSessions = entry.value;

      if (projectByWorktree.containsKey(directory)) continue;
      if (directory == globalWorktree) continue;

      final coveredByRealProject = realProjects.any((project) {
        if (project.worktree.isEmpty) return false;
        if (directory.startsWith("${project.worktree}/")) return true;
        if (project.worktree.startsWith("$directory/")) return true;
        return false;
      });
      if (coveredByRealProject) continue;

      final time = _deriveTimeFromSessions(groupedSessions);
      virtual.add(
        Project(id: _globalProjectId, worktree: directory, time: time),
      );
    }

    return virtual;
  }

  Project _mergeProjectTimeWithSessions({
    required Project project,
    required List<GlobalSession> sessions,
  }) {
    final sessionTime = _deriveTimeFromSessions(sessions);
    final projectTime = project.time;
    if (projectTime == null && sessionTime == null) return project;

    final createdCandidates = <int>[];
    final updatedCandidates = <int>[];

    if (projectTime != null) {
      createdCandidates.add(projectTime.created);
      updatedCandidates.add(projectTime.updated);
    }
    if (sessionTime != null) {
      createdCandidates.add(sessionTime.created);
      updatedCandidates.add(sessionTime.updated);
    }

    if (createdCandidates.isEmpty || updatedCandidates.isEmpty) return project;

    final mergedTime = ProjectTime(
      created: createdCandidates.reduce((a, b) => a < b ? a : b),
      updated: updatedCandidates.reduce((a, b) => a > b ? a : b),
    );

    return project.copyWith(time: mergedTime);
  }

  ProjectTime? _deriveTimeFromSessions(List<GlobalSession> sessions) {
    final created = <int>[];
    final updated = <int>[];

    for (final session in sessions) {
      final time = session.time;
      if (time == null) continue;
      created.add(time.created);
      updated.add(time.updated);
    }

    if (created.isEmpty || updated.isEmpty) return null;

    return ProjectTime(
      created: created.reduce((a, b) => a < b ? a : b),
      updated: updated.reduce((a, b) => a > b ? a : b),
    );
  }
}

bool _isDirectoryUnderWorktree(String directory, String worktree) {
  if (worktree == "/") return true;
  final normalizedDir = directory.replaceAll(r"\", "/");
  final normalizedTree = worktree.replaceAll(r"\", "/");
  return normalizedDir == normalizedTree || normalizedDir.startsWith("$normalizedTree/");
}
