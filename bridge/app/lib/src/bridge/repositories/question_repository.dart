import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/database/daos/projects_dao.dart";
import "../../api/database/daos/session_dao.dart";
import "../../api/database/tables/session_table.dart";
import "derived_session_builder.dart";
import "mappers/plugin_question_mapper.dart";
import "models/project_not_found_exception.dart";
import "models/session_operation.dart";

/// Layer 2 repository wrapping [BridgePluginApi] for question operations.
///
/// Delegates to the plugin and maps the plugin-contract models to the shared
/// wire models so routing handlers stay plugin-agnostic.
class QuestionRepository {
  static const DerivedSessionBuilder _derivedSessionBuilder = DerivedSessionBuilder();

  final Map<String, BridgePluginApi> _operationalPlugins;
  final SessionDao _sessionDao;
  final ProjectsDao _projectsDao;
  final String _legacyMissingPluginId;
  final Duration _aggregateSourceDeadline;

  QuestionRepository({
    required Map<String, BridgePluginApi> operationalPlugins,
    required SessionDao sessionDao,
    required ProjectsDao projectsDao,
    required String legacyMissingPluginId,
    required Duration aggregateSourceDeadline,
  }) : _operationalPlugins = operationalPlugins,
       _sessionDao = sessionDao,
       _projectsDao = projectsDao,
       _legacyMissingPluginId = legacyMissingPluginId,
       _aggregateSourceDeadline = aggregateSourceDeadline;

  /// Pending questions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingQuestion>> getPendingQuestions({required String sessionId}) async {
    final target = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.getPendingQuestions,
    );
    Set<String>? tombstoned;
    if (target.plugin case final BridgeDerivedProjectsPluginApi plugin) {
      tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
      if (tombstoned.contains(target.binding.backendSessionId)) return const [];
    }
    final pluginQuestions = await target.plugin.getPendingQuestions(sessionId: target.binding.backendSessionId);
    return _mapPendingQuestions(
      pluginId: target.plugin.id,
      questions: [
        for (final question in pluginQuestions)
          if (tombstoned == null || _isVisible(question, tombstoned)) question,
      ],
    );
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
    final directory = await _projectsDao.getResolvedPath(projectId: projectId);
    if (directory == null) {
      throw ProjectNotFoundException(projectId: projectId);
    }
    final plugins = _operationalPlugins.values.toList(growable: false);
    if (plugins.isEmpty) {
      throw const PluginOperationException(
        "getProjectQuestions",
        statusCode: 503,
        message: "no plugins are running",
      );
    }
    final questions = await Future.wait(
      plugins.map(
        (plugin) => _getPluginProjectQuestions(
          plugin: plugin,
          projectId: projectId,
          directory: directory,
        ).timeout(_aggregateSourceDeadline),
      ),
    );
    return [for (final source in questions) ...source];
  }

  Future<List<PendingQuestion>> _getPluginProjectQuestions({
    required BridgePluginApi plugin,
    required String projectId,
    required String directory,
  }) async {
    switch (plugin) {
      case final NativeProjectsPluginApi plugin:
        final pluginQuestions = await plugin.getProjectQuestions(projectId: directory);
        return _mapPendingQuestions(pluginId: plugin.id, questions: pluginQuestions);

      case final BridgeDerivedProjectsPluginApi plugin:
        final (sessionProjectPaths, tombstoned, ownScopedQuestions) = await (
          _sessionDao.getSessionProjectPaths(pluginId: plugin.id),
          _sessionDao.getTombstonedSessionIds(pluginId: plugin.id),
          plugin.getProjectQuestions(projectId: directory),
        ).wait;
        final allSessions = await plugin.listAllSessions(
          knownDirectories: {
            directory,
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
          projectId: directory,
          sessions: allSessions.where((s) => !tombstoned.contains(s.id)).toList(growable: false),
          projectPathBySessionId: {
            for (final row in sessionProjectPaths) row.backendSessionId: row.projectPath,
          },
        );

        final questionsByKey = <String, PluginPendingQuestion>{
          for (final question in ownScopedQuestions)
            if (_isVisible(question, tombstoned)) "${question.sessionID}:${question.id}": question,
        };
        for (final sessionId in sessionIds) {
          final pluginQuestions = await plugin.getPendingQuestions(sessionId: sessionId);
          for (final question in pluginQuestions) {
            if (!_isVisible(question, tombstoned)) continue;
            questionsByKey["${question.sessionID}:${question.id}"] = question;
          }
        }
        return _mapPendingQuestions(
          pluginId: plugin.id,
          questions: questionsByKey.values.toList(growable: false),
        );
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
  }) async {
    final target = await _requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.replyToQuestion,
    );
    await _throwIfMutationTargetTombstoned(
      questionId: questionId,
      backendSessionId: target.binding.backendSessionId,
      operation: SessionOperation.replyToQuestion,
      plugin: target.plugin,
    );
    return target.plugin.replyToQuestion(
      questionId: questionId,
      sessionId: target.binding.backendSessionId,
      answers: answers.map((answer) => answer.values).toList(),
    );
  }

  // COMPATIBILITY 2026-06-17 (v1.1.0): Old clients may omit the rejection sessionId. Require it and always run tombstone validation once those clients are unsupported.
  Future<void> rejectQuestion({
    required String questionId,
    required String? sessionId,
  }) async {
    String? backendSessionId;
    if (sessionId != null) {
      final target = await _requireBinding(
        sessionId: sessionId,
        operation: SessionOperation.rejectQuestion,
      );
      backendSessionId = target.binding.backendSessionId;
      await _throwIfMutationTargetTombstoned(
        questionId: questionId,
        backendSessionId: backendSessionId,
        operation: SessionOperation.rejectQuestion,
        plugin: target.plugin,
      );
      return target.plugin.rejectQuestion(questionId: questionId, sessionId: backendSessionId);
    }
    final plugin = _operationalPlugins[_legacyMissingPluginId];
    if (plugin == null) {
      throw _pluginUnavailable(id: _legacyMissingPluginId, operation: SessionOperation.rejectQuestion);
    }
    return plugin.rejectQuestion(
      questionId: questionId,
      sessionId: backendSessionId,
    );
  }

  Future<void> _throwIfMutationTargetTombstoned({
    required String questionId,
    required String backendSessionId,
    required SessionOperation operation,
    required BridgePluginApi plugin,
  }) async {
    if (plugin is BridgeDerivedProjectsPluginApi) {
      final tombstoned = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
      if (tombstoned.contains(backendSessionId)) {
        throw PluginOperationException.notFound(
          operation.name,
          message: "session $backendSessionId was deleted",
        );
      }
      final pending = await plugin.getPendingQuestions(sessionId: backendSessionId);
      for (final question in pending) {
        if (question.id != questionId) continue;
        if (tombstoned.contains(question.sessionID)) {
          throw PluginOperationException.notFound(
            operation.name,
            message: "session ${question.sessionID} was deleted",
          );
        }
        if (question.displaySessionId case final displaySessionId? when tombstoned.contains(displaySessionId)) {
          throw PluginOperationException.notFound(
            operation.name,
            message: "display session $displaySessionId was deleted",
          );
        }
        break;
      }
    }
  }

  Future<({SessionDto binding, BridgePluginApi plugin})> _requireBinding({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    if (binding == null) {
      throw PluginOperationException.notFound(
        operation.name,
        message: "session $sessionId was not found",
      );
    }
    final plugin = _operationalPlugins[binding.pluginId];
    if (plugin == null) throw _pluginUnavailable(id: binding.pluginId, operation: operation);
    return (binding: binding, plugin: plugin);
  }

  Future<List<PendingQuestion>> _mapPendingQuestions({
    required String pluginId,
    required List<PluginPendingQuestion> questions,
  }) async {
    final backendSessionIds = {
      for (final question in questions) ...{
        question.sessionID,
        ?question.displaySessionId,
      },
    };
    final bindings = await _sessionDao.getSessionsByBackendIds(
      pluginId: pluginId,
      backendSessionIds: backendSessionIds.toList(growable: false),
    );
    return [
      for (final question in questions)
        if (bindings[question.sessionID] case final session?)
          if (question.displaySessionId == null || bindings.containsKey(question.displaySessionId))
            question.toSharedPendingQuestion(
              sessionId: session.sessionId,
              displaySessionId: question.displaySessionId == null
                  ? null
                  : bindings[question.displaySessionId]!.sessionId,
            ),
    ];
  }

  PluginOperationException _pluginUnavailable({required String id, required SessionOperation operation}) {
    return PluginOperationException(
      operation.name,
      statusCode: 503,
      message: "plugin $id is not running",
    );
  }
}
