import "package:meta/meta.dart" show visibleForTesting;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        PluginAgent,
        PluginCommand,
        PluginCommandSource,
        PluginMessageWithParts,
        PluginPermissionReply,
        PluginProject,
        PluginProjectActivity,
        PluginPromptPart,
        PluginProvidersResult,
        PluginSession,
        PluginSessionVariant;
import "package:sesori_shared/sesori_shared.dart" show StringExtensions, wait2;

import "message_part_mapper.dart";
import "models/openapi/command.g.dart";
import "models/openapi/global_session.g.dart";
import "models/openapi/permission_request.g.dart";
import "models/openapi/project.g.dart";
import "models/openapi/question_request.g.dart";
import "models/openapi/session.g.dart";
import "models/question_reply_body.dart";
import "models/send_command_body.dart";
import "models/send_prompt_body.dart";
import "models/summarize_body.dart";
import "opencode_api.dart";
import "plugin_model_mapper.dart";
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
/// 1. **Derives activity per project**: For every real project, we look at ALL
///    root sessions under its worktree and sandbox aliases (regardless of their
///    project ID) and compute the minimum `createdAt` and maximum `updatedAt`.
///    This activity is purely session-derived; the upstream project's own
///    `time` is never used.
///
/// 2. **Synthesizes virtual projects**: For directories that have `"global"`
///    sessions but no real project entry (e.g., a non-git directory that was
///    used once), we create a virtual project so the mobile app can still
///    display those sessions.
class OpenCodeRepository {
  final OpenCodeApi _api;
  final PluginModelMapper _pluginModelMapper = const PluginModelMapper(
    messagePartMapper: MessagePartMapper(),
  );

  OpenCodeRepository(this._api);

  OpenCodeApi get api => _api;

  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    final commands = await _api.listCommands(directory: projectId?.normalize());
    return commands.map<PluginCommand>(_mapCommand).toList();
  }

  Future<List<PluginAgent>> getAgents({required String directory}) async {
    final agents = await _api.listAgents(directory: directory);
    return agents.map(_pluginModelMapper.mapAgent).toList();
  }

  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
  }) async {
    final normalizedDirectory = directory.trim();
    final session = await _api.createSession(
      directory: normalizedDirectory,
      parentSessionId: parentSessionId,
    );
    return _pluginModelMapper.mapSession(session, projectID: normalizedDirectory);
  }

  Future<void> sendPrompt({
    required String sessionId,
    required String? directory,
    required List<PluginPromptPart> parts,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    return _api.sendPrompt(
      sessionId: sessionId,
      directory: directory?.normalize(),
      body: SendPromptBody(
        parts: parts,
        agent: agent,
        variant: variant?.id,
        model: model,
      ),
    );
  }

  Future<void> sendCommand({
    required String sessionId,
    required String? directory,
    required String command,
    required String arguments,
    required String? agent,
    required PluginSessionVariant? variant,
    required ({String providerID, String modelID})? model,
  }) {
    return _api.sendCommand(
      sessionId: sessionId,
      directory: directory?.normalize(),
      body: SendCommandBody(
        command: command,
        arguments: arguments,
        agent: agent,
        variant: variant?.id,
        model: model,
      ),
    );
  }

  /// Triggers manual compaction of [sessionId] via the summarize endpoint.
  ///
  /// Unlike [sendCommand], OpenCode's summarize payload needs the provider and
  /// model as separate, non-optional fields, so [model] is required here.
  Future<void> summarize({
    required String sessionId,
    required String? directory,
    required ({String providerID, String modelID}) model,
  }) {
    return _api.summarize(
      sessionId: sessionId,
      directory: directory?.normalize(),
      body: SummarizeBody(
        providerID: model.providerID,
        modelID: model.modelID,
      ),
    );
  }

  Future<void> deleteSession({
    required String sessionId,
    required String? directory,
  }) {
    return _api.deleteSession(
      sessionId: sessionId,
      directory: directory?.normalize(),
    );
  }

  Future<List<({PluginProject project, List<String> sandboxes})>> getProjects() async {
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

    // All root sessions grouped by directory — used to derive each project's
    // activity so that "last updated" reflects real session work, not the
    // upstream project metadata timestamp.
    final allSessionsByDirectory = _groupSessionsByDirectory(allSessions);

    // Only "global" project sessions grouped by directory — used to detect
    // directories that have orphaned sessions but no real project entry, so we
    // can create virtual projects for them.
    final globalOnlyByDirectory = _groupSessionsByDirectory(
      allSessions,
      projectID: _globalProjectId,
    );

    final mappedRealProjects = realProjects.map((project) {
      final sessions = _sessionsUnderWorktrees(
        allSessionsByDirectory,
        [project.worktree, ...project.sandboxes],
      );
      return (
        project: _pluginModelMapper.mapProject(
          worktree: project.worktree,
          directory: project.worktree,
          name: project.name,
          activity: _deriveActivityFromSessions(sessions),
        ),
        sandboxes: project.sandboxes,
      );
    }).toList();

    final virtualProjects = _buildVirtualProjects(
      globalOnlyByDirectory: globalOnlyByDirectory,
      projectByWorktree: projectByWorktree,
      realProjects: realProjects,
      globalWorktree: globalWorktree,
    );

    return [...mappedRealProjects, ...virtualProjects];
  }

  Future<void> replyToPermission({
    required String requestId,
    required String? directory,
    required PluginPermissionReply reply,
  }) {
    return _api.replyToPermission(
      requestId: requestId,
      directory: directory?.normalize(),
      reply: reply,
    );
  }

  Future<void> replyToQuestion({
    required String questionId,
    required String? directory,
    required QuestionReplyBody body,
  }) {
    return _api.replyToQuestion(
      questionId: questionId,
      directory: directory?.normalize(),
      body: body,
    );
  }

  Future<void> rejectQuestion({
    required String questionId,
    required String? directory,
  }) {
    return _api.rejectQuestion(
      questionId: questionId,
      directory: directory?.normalize(),
    );
  }

  /// Lists the sessions in [directory] (or the OpenCode server's cwd instance
  /// when null). [roots] limits the result to root sessions.
  Future<List<Session>> listSessions({required String? directory, required bool roots}) {
    return _api.listSessions(directory: directory, roots: roots);
  }

  Future<List<Session>> getSessions({required String worktree}) async {
    final (standardSessions, globalSessions) = await wait2(
      _api.listSessions(directory: worktree, roots: true),
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
          slug: global.slug,
          projectID: global.projectID,
          workspaceID: global.workspaceID,
          directory: global.directory,
          path: global.path,
          parentID: global.parentID,
          title: global.title,
          cost: global.cost,
          tokens: switch (global.tokens) {
            null => null,
            final t => SessionTokens(
              input: t.input,
              output: t.output,
              reasoning: t.reasoning,
              cache: SessionTokensCache(
                read: t.cache.read,
                write: t.cache.write,
              ),
            ),
          },
          share: switch (global.share) {
            null => null,
            final s => SessionShare(url: s.url),
          },
          agent: global.agent,
          model: switch (global.model) {
            null => null,
            final m => SessionModel(
              id: m.id,
              providerID: m.providerID,
              variant: m.variant,
            ),
          },
          version: global.version,
          metadata: global.metadata,
          time: SessionTime(
            created: global.time.created,
            updated: global.time.updated,
            compacting: global.time.compacting,
            archived: global.time.archived,
          ),
          summary: switch (global.summary) {
            null => null,
            final s => SessionSummary(
              additions: s.additions,
              deletions: s.deletions,
              files: s.files,
              diffs: s.diffs,
            ),
          },
          permission: global.permission,
          revert: switch (global.revert) {
            null => null,
            final r => SessionRevert(
              messageID: r.messageID,
              partID: r.partID,
              snapshot: r.snapshot,
              diff: r.diff,
            ),
          },
        ),
      );
    }

    final filtered = merged.where((session) {
      if (session.parentID != null) return false;
      return _isDirectoryUnderWorktree(session.directory, worktree);
    }).toList();

    filtered.sort((a, b) {
      final updatedA = a.time.updated;
      final updatedB = b.time.updated;
      return updatedB.compareTo(updatedA);
    });

    return filtered;
  }

  /// Fetches providers from the API, optionally filtering to connected-only,
  /// and maps OpenCode-specific models to plugin interface types.
  Future<PluginProvidersResult> getProviders({
    required String? directory,
  }) async {
    final response = await _api.listConfigProviders(
      directory: directory?.normalize(),
    );
    return mapProviderResponse(response: response);
  }

  Future<Session> getSession({
    required String sessionId,
    required String? directory,
  }) {
    return _api.getSession(
      sessionId: sessionId,
      directory: directory?.normalize(),
    );
  }

  Future<List<QuestionRequest>> getPendingQuestions({required String? directory}) {
    return _api.getPendingQuestions(directory: directory?.normalize());
  }

  Future<List<PermissionRequest>> getPendingPermissions({required String? directory}) {
    return _api.getPendingPermissions(directory: directory?.normalize());
  }

  /// Collects all sessions whose directory is equal to or under any [worktrees],
  /// using the same prefix-based matching as [_isDirectoryUnderWorktree].
  ///
  /// This is necessary because users can start sessions from subdirectories
  /// (e.g., `/repo/packages/foo`) while the project worktree is the git root
  /// (`/repo`). A simple exact-key lookup would miss those subdirectory
  /// sessions.
  List<GlobalSession> _sessionsUnderWorktrees(
    Map<String, List<GlobalSession>> sessionsByDirectory,
    Iterable<String> worktrees,
  ) {
    final nonEmptyWorktrees = worktrees.where((worktree) => worktree.isNotEmpty);
    final result = <GlobalSession>[];
    for (final entry in sessionsByDirectory.entries) {
      if (nonEmptyWorktrees.any((worktree) => _isDirectoryUnderWorktree(entry.key, worktree))) {
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
      if (session.parentID != null) continue;
      if (session.directory.isEmpty) continue;
      grouped.putIfAbsent(session.directory, () => []).add(session);
    }
    return grouped;
  }

  /// Builds virtual [PluginProject] entries for directories that have `"global"`
  /// sessions but no corresponding real project entry.
  ///
  /// This covers directories where a user ran OpenCode before `git init`. Those
  /// sessions are assigned to the `"global"` project and wouldn't appear in the
  /// project list without a synthetic entry.
  ///
  /// Directories already covered by a real project (exact match or
  /// parent/child) are skipped to avoid duplicates.
  List<({PluginProject project, List<String> sandboxes})> _buildVirtualProjects({
    required Map<String, List<GlobalSession>> globalOnlyByDirectory,
    required Map<String, Project> projectByWorktree,
    required List<Project> realProjects,
    required String? globalWorktree,
  }) {
    final virtual = <({PluginProject project, List<String> sandboxes})>[];

    for (final entry in globalOnlyByDirectory.entries) {
      final directory = entry.key;
      final groupedSessions = entry.value;

      if (projectByWorktree.containsKey(directory)) continue;
      if (directory == globalWorktree) continue;

      final coveredByRealProject = realProjects.any(
        (project) => <String>[project.worktree, ...project.sandboxes].any(
          (worktree) =>
              worktree.isNotEmpty &&
              (_isDirectoryUnderWorktree(directory, worktree) || _isDirectoryUnderWorktree(worktree, directory)),
        ),
      );
      if (coveredByRealProject) continue;

      final activity = _deriveActivityFromSessions(groupedSessions);
      virtual.add((
        project: _pluginModelMapper.mapProject(
          worktree: directory,
          directory: directory,
          name: null,
          activity: activity,
        ),
        sandboxes: const [],
      ));
    }

    return virtual;
  }

  /// Returns a [PluginProjectActivity] representing the earliest `createdAt`
  /// and latest `updatedAt` across the given [sessions]. Returns null if the
  /// sessions provide no time information.
  PluginProjectActivity? _deriveActivityFromSessions(List<GlobalSession> sessions) {
    return deriveActivityFromSessionTimes(
      times: sessions.map((session) => session.time),
    );
  }

  @visibleForTesting
  static PluginProjectActivity? deriveActivityFromSessionTimes({
    required Iterable<GlobalSessionTime?> times,
  }) {
    final created = <int>[];
    final updated = <int>[];

    for (final time in times) {
      if (time == null) continue;
      created.add(time.created);
      updated.add(time.updated);
    }

    if (created.isEmpty || updated.isEmpty) return null;

    return PluginProjectActivity(
      createdAt: created.reduce((a, b) => a < b ? a : b),
      updatedAt: updated.reduce((a, b) => a > b ? a : b),
    );
  }

  Future<List<PluginMessageWithParts>> getMessages({
    required String sessionId,
    required String? directory,
  }) async {
    final messages = await _api.getMessages(
      sessionId: sessionId,
      directory: directory,
    );
    return messages.map(_pluginModelMapper.mapMessageWithParts).toList();
  }

  PluginCommand _mapCommand(Command command) {
    return PluginCommand(
      name: command.name,
      template: command.template,
      hints: command.hints,
      description: command.description,
      agent: command.agent,
      model: command.model,
      provider: command.provider,
      source: switch (command.source) {
        CommandSource.command => PluginCommandSource.command,
        CommandSource.mcp => PluginCommandSource.mcp,
        CommandSource.skill => PluginCommandSource.skill,
        CommandSource.unknown || null => PluginCommandSource.unknown,
      },
      subtask: command.subtask,
    );
  }
}

bool _isDirectoryUnderWorktree(String directory, String worktree) {
  if (worktree == "/") return true;
  final normalizedDir = directory.replaceAll(r"\", "/");
  final normalizedTree = worktree.replaceAll(r"\", "/");
  return normalizedDir == normalizedTree || normalizedDir.startsWith("$normalizedTree/");
}
