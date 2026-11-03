import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../runtime/plugin_runtime.dart";
import "models/session_operation.dart";
import "pending_interaction_support.dart";

/// Layer 2 repository wrapping [BridgePluginApi] for question operations.
///
/// Delegates to the plugin and maps the plugin-contract models to the shared
/// wire models so routing handlers stay plugin-agnostic.
class QuestionRepository({
  required final PluginRuntime _runtime,
  required final PendingInteractionSupport _pendingSupport,
}) {
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
              if (_isVisible(question: question, tombstoned: tombstones)) question,
          ],
        );
      },
    );
    // Null means the backend is not running, which is indistinguishable from
    // "it has none" for this question.
    return pending ?? const [];
  }

  bool _isVisible({required PluginPendingQuestion question, required Set<String> tombstoned}) =>
      _pendingSupport.isVisible(
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
}
