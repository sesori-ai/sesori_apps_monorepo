import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/projects_dao.dart";
import "../api/database/daos/session_dao.dart";
import "../runtime/plugin_runtime.dart";
import "derived_session_builder.dart";
import "models/project_not_found_exception.dart";
import "models/session_operation.dart";
import "pending_interaction_support.dart";

/// Layer 2 repository wrapping [BridgePluginApi] for question operations.
///
/// Delegates to the plugin and maps the plugin-contract models to the shared
/// wire models so routing handlers stay plugin-agnostic.
class QuestionRepository({
  required final PluginRuntime _runtime,
  required final PendingInteractionSupport _pendingSupport,
  required final SessionDao _sessionDao,
  required final ProjectsDao _projectsDao,
  required final Duration _aggregateSourceDeadline,
}) {
  static const DerivedSessionBuilder _derivedSessionBuilder = DerivedSessionBuilder();

  /// Pending questions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingQuestion>> getPendingQuestions({required String sessionId}) async {
    final binding = await _pendingSupport.requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.getPendingQuestions,
    );
    // Deliberately does not start a stopped backend. Pending questions live in
    // the backend process — an in-memory approval registry for ACP, the
    // running HTTP server for OpenCode — so a stopped one holds none. Starting
    // it could only ever answer "none" after paying the full start cost, and
    // harnesses are slow to respond for a while after starting.
    final pending = await _runtime.useIfActive(
      pluginId: binding.pluginId,
      operation: SessionOperation.getPendingQuestions,
      body: (plugin, _) async {
        final tombstones = await _pendingSupport.readPendingTombstones(
          plugin: plugin,
          backendSessionId: binding.backendSessionId,
        );
        if (tombstones == null) return const <PendingQuestion>[];
        final questions = await plugin.getPendingQuestions(sessionId: binding.backendSessionId);
        return await _pendingSupport.mapQuestions(
          pluginId: plugin.id,
          questions: [
            for (final question in questions)
              if (_isVisible(question, tombstones)) question,
          ],
        );
      },
    );
    // Null means the backend is not running, which is indistinguishable from
    // "it has none" for this question.
    return pending ?? const [];
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
    final pluginIds = _runtime.activePluginIds;
    if (pluginIds.isEmpty) {
      throw PluginOperationException(
        SessionOperation.getProjectQuestions.name,
        statusCode: 503,
        message: "no plugins are running",
      );
    }
    final sources = await Future.wait<List<PendingQuestion>?>(
      pluginIds.map((pluginId) async {
        try {
          return await _runtime.useIfActive(
            pluginId: pluginId,
            operation: SessionOperation.getProjectQuestions,
            body: (plugin, _) => _getPluginProjectQuestions(
              plugin: plugin,
              projectId: projectId,
              directory: directory,
            ).timeout(_aggregateSourceDeadline),
          );
        } on Object catch (error, stackTrace) {
          Log.w("Could not read project questions from plugin $pluginId", error, stackTrace);
          return null;
        }
      }),
    );
    if (sources.every((source) => source == null)) {
      throw PluginOperationException(
        SessionOperation.getProjectQuestions.name,
        statusCode: 503,
        message: "all running plugins failed to get project questions",
      );
    }
    return [for (final source in sources) ...?source];
  }

  Future<List<PendingQuestion>> _getPluginProjectQuestions({
    required BridgePluginApi plugin,
    required String projectId,
    required String directory,
  }) async {
    switch (plugin) {
      case final NativeProjectsPluginApi plugin:
        final pluginQuestions = await plugin.getProjectQuestions(projectId: directory);
        return await _pendingSupport.mapQuestions(pluginId: plugin.id, questions: pluginQuestions);

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
        return await _pendingSupport.mapQuestions(
          pluginId: plugin.id,
          questions: questionsByKey.values.toList(growable: false),
        );
    }
  }

  bool _isVisible(PluginPendingQuestion question, Set<String> tombstoned) => _pendingSupport.isVisible(
    sessionId: question.sessionID,
    displaySessionId: question.displaySessionId,
    tombstones: tombstoned,
  );

  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) async {
    final binding = await _pendingSupport.requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.replyToQuestion,
    );
    return await _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.replyToQuestion,
      body: (plugin) async {
        await _pendingSupport.throwIfMutationTargetTombstoned(
          interactionId: questionId,
          backendSessionId: binding.backendSessionId,
          operation: SessionOperation.replyToQuestion,
          plugin: plugin,
          readPending: () async => [
            for (final question in await plugin.getPendingQuestions(sessionId: binding.backendSessionId))
              (id: question.id, sessionID: question.sessionID, displaySessionId: question.displaySessionId),
          ],
        );
        return await plugin.replyToQuestion(
          questionId: questionId,
          sessionId: binding.backendSessionId,
          answers: answers.map((answer) => answer.values).toList(),
        );
      },
    );
  }

  Future<void> rejectQuestion({
    required String questionId,
    required String sessionId,
  }) async {
    final binding = await _pendingSupport.requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.rejectQuestion,
    );
    return await _runtime.use(
      pluginId: binding.pluginId,
      operation: SessionOperation.rejectQuestion,
      body: (plugin) async {
        await _pendingSupport.throwIfMutationTargetTombstoned(
          interactionId: questionId,
          backendSessionId: binding.backendSessionId,
          operation: SessionOperation.rejectQuestion,
          plugin: plugin,
          readPending: () async => [
            for (final question in await plugin.getPendingQuestions(sessionId: binding.backendSessionId))
              (id: question.id, sessionID: question.sessionID, displaySessionId: question.displaySessionId),
          ],
        );
        return await plugin.rejectQuestion(
          questionId: questionId,
          sessionId: binding.backendSessionId,
        );
      },
    );
  }

  Future<List<String>> findPendingQuestionOwnerSessionIds({
    required String pluginId,
    required String questionId,
  }) async {
    final bindings = await _sessionDao.getSessionsForPlugin(pluginId: pluginId);
    final roots = bindings.values.where((binding) => binding.parentSessionId == null);
    return await _runtime.use(
      pluginId: pluginId,
      operation: SessionOperation.rejectQuestion,
      body: (plugin) async {
        final tombstoned = plugin is BridgeDerivedProjectsPluginApi
            ? await _sessionDao.getTombstonedSessionIds(pluginId: pluginId)
            : const <String>{};
        final owners = <String>{};
        for (final root in roots) {
          if (tombstoned.contains(root.backendSessionId)) continue;
          final questions = await plugin.getPendingQuestions(sessionId: root.backendSessionId);
          for (final question in questions) {
            if (question.id != questionId || !_isVisible(question, tombstoned)) continue;
            final owner = bindings[question.sessionID];
            if (owner != null) owners.add(owner.sessionId);
          }
        }
        return owners.toList(growable: false)..sort();
      },
    );
  }
}
