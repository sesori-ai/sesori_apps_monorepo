import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "derived_session_builder.dart";
import "mappers/plugin_question_mapper.dart";

/// Layer 2 repository wrapping [BridgePluginApi] for question operations.
///
/// Delegates to the plugin and maps the plugin-contract models to the shared
/// wire models so routing handlers stay plugin-agnostic.
class QuestionRepository {
  static const DerivedSessionBuilder _derivedSessionBuilder = DerivedSessionBuilder();

  final BridgePluginApi _plugin;
  final SessionDao _sessionDao;

  QuestionRepository({required BridgePluginApi plugin, required SessionDao sessionDao})
    : _plugin = plugin,
      _sessionDao = sessionDao;

  /// Pending questions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingQuestion>> getPendingQuestions({required String sessionId}) async {
    final pluginQuestions = await _plugin.getPendingQuestions(sessionId: sessionId);
    return pluginQuestions.map((q) => q.toSharedPendingQuestion()).toList();
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
        final pluginQuestions = await plugin.getProjectQuestions(projectId: projectId);
        return pluginQuestions.map((q) => q.toSharedPendingQuestion()).toList();

      case final BridgeDerivedProjectsPluginApi plugin:
        final (allSessions, sessionProjectPaths, ownScopedQuestions) = await (
          plugin.listAllSessions(),
          _sessionDao.getSessionProjectPaths(pluginId: plugin.id),
          plugin.getProjectQuestions(projectId: projectId),
        ).wait;
        // Id-level scoping: includes stored-row attributions missing from the
        // plugin enumeration, so a question raised in a fresh worktree session
        // (attributed to this project by its row, but not yet in the backend's
        // on-disk enumeration and scoped to its worktree cwd by the plugin's
        // own query) still surfaces here.
        final sessionIds = _derivedSessionBuilder.buildSessionIds(
          projectId: projectId,
          sessions: allSessions,
          projectPathBySessionId: {
            for (final row in sessionProjectPaths) row.sessionId: row.projectPath,
          },
        );

        final questionsByKey = <String, PendingQuestion>{
          for (final question in ownScopedQuestions)
            "${question.sessionID}:${question.id}": question.toSharedPendingQuestion(),
        };
        for (final sessionId in sessionIds) {
          final pluginQuestions = await plugin.getPendingQuestions(sessionId: sessionId);
          for (final question in pluginQuestions) {
            questionsByKey["${question.sessionID}:${question.id}"] = question.toSharedPendingQuestion();
          }
        }
        return questionsByKey.values.toList();
    }
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
