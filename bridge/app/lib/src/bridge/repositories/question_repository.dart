import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/projects_dao.dart";
import "../persistence/daos/session_dao.dart";
import "derived_session_builder.dart";
import "mappers/plugin_question_mapper.dart";
import "models/project_not_found_exception.dart";

/// Layer 2 repository wrapping [BridgePluginApi] for question operations.
///
/// Delegates to the plugin and maps the plugin-contract models to the shared
/// wire models so routing handlers stay plugin-agnostic.
class QuestionRepository {
  static const DerivedSessionBuilder _derivedSessionBuilder = DerivedSessionBuilder();

  final BridgePluginApi _plugin;
  final SessionDao _sessionDao;
  final ProjectsDao _projectsDao;

  QuestionRepository({
    required BridgePluginApi plugin,
    required SessionDao sessionDao,
    required ProjectsDao projectsDao,
  }) : _plugin = plugin,
       _sessionDao = sessionDao,
       _projectsDao = projectsDao;

  /// Pending questions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingQuestion>> getPendingQuestions({required String sessionId}) async {
    Set<String>? tombstoned;
    if (_plugin case final BridgeDerivedProjectsPluginApi plugin) {
      tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
      if (tombstoned.contains(sessionId)) return const [];
    }
    final pluginQuestions = await _plugin.getPendingQuestions(sessionId: sessionId);
    return [
      for (final question in pluginQuestions)
        if (tombstoned == null || _isVisible(question, tombstoned)) question.toSharedPendingQuestion(),
    ];
  }

  /// All pending questions for [projectId].
  ///
  /// A native plugin scopes questions to the project itself. A bridge-derived
  /// plugin scopes only by a session's own cwd, so a question raised in a
  /// session running in a dedicated worktree would never surface under the
  /// project the user opened. For derived plugins the bridge owns the
  /// session→project attribution, so we resolve the project's sessions via
  /// [DerivedSessionBuilder] and aggregate each session's pending questions —
  /// equivalent to the plugin's own project scoping, but worktree-aware.
  ///
  /// The plugin's own project-scoped result is merged in as well: a derived
  /// backend can hold a freshly-created session only in memory (codex before
  /// the rollout is flushed to disk), in which case the session is missing
  /// from `listAllSessions()` and only the plugin's live scoping can surface
  /// its questions. Merging is keyed by session id + question id — so a
  /// question seen by both paths appears once, without assuming question ids
  /// are globally unique across sessions.
  Future<List<PendingQuestion>> getProjectQuestions({required String projectId}) async {
    switch (_plugin) {
      case final NativeProjectsPluginApi plugin:
        // The plugin scopes questions by directory, so hand it the project's
        // live directory rather than the (possibly moved-away-from) id.
        final directory = await _projectsDao.getResolvedPath(projectId: projectId);
        if (directory == null) {
          throw ProjectNotFoundException(projectId: projectId);
        }
        final pluginQuestions = await plugin.getProjectQuestions(projectId: directory);
        return pluginQuestions.map((q) => q.toSharedPendingQuestion()).toList();

      case final BridgeDerivedProjectsPluginApi plugin:
        final (sessionProjectPaths, tombstoned, ownScopedQuestions) = await (
          _sessionDao.getSessionProjectPaths(pluginId: plugin.id),
          _sessionDao.getTombstonedSessionIds(pluginId: plugin.id),
          plugin.getProjectQuestions(projectId: projectId),
        ).wait;
        final allSessions = await plugin.listAllSessions(
          knownDirectories: {
            projectId,
            for (final row in sessionProjectPaths) ...[
              row.projectPath,
              ?row.worktreePath,
            ],
          },
        );
        // Id-level scoping: includes stored-row attributions missing from the
        // plugin enumeration, so a question raised in a fresh worktree session
        // (attributed to this project by its row, but not yet in the backend's
        // on-disk enumeration and scoped to its worktree cwd by the plugin's
        // own query) still surfaces here. Tombstoned (deleted) sessions are
        // excluded — a backend without session deletion still enumerates them.
        final sessionIds = _derivedSessionBuilder.buildSessionIds(
          projectId: projectId,
          sessions: allSessions.where((s) => !tombstoned.contains(s.id)).toList(growable: false),
          projectPathBySessionId: {
            for (final row in sessionProjectPaths) row.sessionId: row.projectPath,
          },
        );

        final questionsByKey = <String, PendingQuestion>{
          for (final question in ownScopedQuestions)
            if (_isVisible(question, tombstoned))
              "${question.sessionID}:${question.id}": question.toSharedPendingQuestion(),
        };
        for (final sessionId in sessionIds) {
          final pluginQuestions = await plugin.getPendingQuestions(sessionId: sessionId);
          for (final question in pluginQuestions) {
            if (!_isVisible(question, tombstoned)) continue;
            questionsByKey["${question.sessionID}:${question.id}"] = question.toSharedPendingQuestion();
          }
        }
        return questionsByKey.values.toList();
    }
  }

  static bool _isVisible(PluginPendingQuestion question, Set<String> tombstoned) {
    return !tombstoned.contains(question.sessionID) &&
        (question.displaySessionId == null || !tombstoned.contains(question.displaySessionId));
  }

  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) => _plugin.replyToQuestion(
    questionId: questionId,
    sessionId: sessionId,
    answers: answers.map((answer) => answer.values).toList(),
  );

  Future<void> rejectQuestion({
    required String questionId,
    required String? sessionId,
  }) => _plugin.rejectQuestion(
    questionId: questionId,
    sessionId: sessionId,
  );
}
