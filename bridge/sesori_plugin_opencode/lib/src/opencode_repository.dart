import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginProvidersResult;
import "package:sesori_shared/sesori_shared.dart" show wait2;

import "models/pending_question.dart";
import "models/project.dart";
import "models/session.dart";
import "opencode_api.dart";
import "provider_mapper.dart";

const String _globalProjectId = "global";

/// Merges OpenCode's standard and global session APIs into a unified view of
/// projects and sessions.
///
/// ## Why "global" sessions exist
///
/// OpenCode assigns a special project ID (`"global"`) to sessions created in
/// directories that don't yet have a git repository. Once a directory is
/// `git init`-ed and OpenCode restarts, it creates a real project entry and
/// migrates future sessions to that project ID. However, any sessions created
/// **before** the git init retain `projectID = "global"` in the database.
///
/// This means a single directory can have sessions split across two project
/// IDs:
///
/// - **Real project ID** — sessions created after the project was recognized.
/// - **`"global"`** — orphaned sessions created before git init.
///
/// ## How this class handles it
///
/// [getProjects] fetches both the project list (`/project`) and all root
/// sessions across every project (`/experimental/session?roots=true`). It then:
///
/// 1. **Merges timestamps**: For every real project, we look at ALL sessions
///    under its worktree (regardless of their project ID) and merge their
///    timestamps so the project's "last updated" reflects the most recent
///    session activity.
///
/// 2. **Synthesizes virtual projects**: For directories that have `"global"`
///    sessions but no real project entry (e.g., a non-git directory that was
///    used once), we create a virtual project so the mobile app can still
///    display those sessions.
class OpenCodeRepository {
  final OpenCodeApi _api;

  OpenCodeRepository(this._api);

  OpenCodeApi get api => _api;

  Future<List<Project>> getProjects() async {
    final (rawProjects, allSessions) = await wait2(
      _api.listProjects(),
      _api.listAllSessions(directory: null, roots: true),
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

    // All sessions grouped by directory — used to merge timestamps into real
    // projects so that "last updated" reflects the most recent session activity,
    // not just the project's own metadata timestamp.
    final allSessionsByDirectory = _groupSessionsByDirectory(allSessions);

    // Only "global" project sessions grouped by directory — used to detect
    // directories that have orphaned sessions but no real project entry, so we
    // can create virtual projects for them.
    final globalOnlyByDirectory = _groupSessionsByDirectory(
      allSessions,
      projectID: _globalProjectId,
    );

    final mergedRealProjects = realProjects.map((project) {
      final sessions = _sessionsUnderWorktree(
        allSessionsByDirectory,
        project.worktree,
      );
      if (sessions.isEmpty) return project;
      return _mergeProjectTimeWithSessions(
        project: project,
        sessions: sessions,
      );
    }).toList();

    final virtualProjects = _buildVirtualProjects(
      globalOnlyByDirectory: globalOnlyByDirectory,
      projectByWorktree: projectByWorktree,
      realProjects: realProjects,
      globalWorktree: globalWorktree,
    );

    return [...mergedRealProjects, ...virtualProjects];
  }

  Future<List<Session>> getSessions({required String worktree}) async {
    final (standardSessions, globalSessions) = await wait2(
      _api.listSessions(directory: worktree),
      _api.listAllSessions(directory: worktree, roots: true),
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

  /// Fetches providers from the API, optionally filtering to connected-only,
  /// and maps OpenCode-specific models to plugin interface types.
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async {
    final response = await _api.listProviders();
    return mapProviderResponse(response: response, connectedOnly: connectedOnly);
  }

  Future<List<PendingQuestion>> getPendingQuestions() {
    return _api.getPendingQuestions(directory: null);
  }

  /// Collects all sessions whose directory is equal to or under [worktree],
  /// using the same prefix-based matching as [_isDirectoryUnderWorktree].
  ///
  /// This is necessary because users can start sessions from subdirectories
  /// (e.g., `/repo/packages/foo`) while the project worktree is the git root
  /// (`/repo`). A simple exact-key lookup would miss those subdirectory
  /// sessions.
  List<GlobalSession> _sessionsUnderWorktree(
    Map<String, List<GlobalSession>> sessionsByDirectory,
    String worktree,
  ) {
    final result = <GlobalSession>[];
    for (final entry in sessionsByDirectory.entries) {
      if (_isDirectoryUnderWorktree(entry.key, worktree)) {
        result.addAll(entry.value);
      }
    }
    return result;
  }

  /// Groups [sessions] by their [GlobalSession.directory] field.
  ///
  /// When [projectID] is provided, only sessions whose
  /// [GlobalSession.projectID] matches are included. When null, all sessions
  /// are included regardless of their project ID.
  Map<String, List<GlobalSession>> _groupSessionsByDirectory(
    List<GlobalSession> sessions, {
    String? projectID,
  }) {
    final grouped = <String, List<GlobalSession>>{};
    for (final session in sessions) {
      if (projectID != null && session.projectID != projectID) continue;
      if (session.directory.isEmpty) continue;
      grouped.putIfAbsent(session.directory, () => []).add(session);
    }
    return grouped;
  }

  /// Builds virtual [Project] entries for directories that have `"global"`
  /// sessions but no corresponding real project entry.
  ///
  /// This covers directories where a user ran OpenCode before `git init`. Those
  /// sessions are assigned to the `"global"` project and wouldn't appear in the
  /// project list without a synthetic entry.
  ///
  /// Directories already covered by a real project (exact match or
  /// parent/child) are skipped to avoid duplicates.
  List<Project> _buildVirtualProjects({
    required Map<String, List<GlobalSession>> globalOnlyByDirectory,
    required Map<String, Project> projectByWorktree,
    required List<Project> realProjects,
    required String? globalWorktree,
  }) {
    final virtual = <Project>[];

    for (final entry in globalOnlyByDirectory.entries) {
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

  /// Merges a project's own timestamps with the timestamps derived from its
  /// sessions, producing a [ProjectTime] where `created` is the earliest and
  /// `updated` is the most recent across both sources.
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

  /// Returns a [ProjectTime] representing the earliest `created` and latest
  /// `updated` across the given [sessions]. Returns null if no session carries
  /// time information.
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
