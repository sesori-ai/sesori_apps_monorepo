import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "mappers/plugin_question_mapper.dart";

/// Layer 2 repository wrapping [BridgePluginApi] for question operations.
///
/// Delegates to the plugin and maps the plugin-contract models to the shared
/// wire models so routing handlers stay plugin-agnostic.
class QuestionRepository {
  final BridgePluginApi _plugin;

  QuestionRepository({required BridgePluginApi plugin}) : _plugin = plugin;

  /// Pending questions to surface on [sessionId]'s screen (its own plus any
  /// descendant session whose root resolves to it).
  Future<List<PendingQuestion>> getPendingQuestions({required String sessionId}) async {
    final pluginQuestions = await _plugin.getPendingQuestions(sessionId: sessionId);
    return pluginQuestions.map((q) => q.toSharedPendingQuestion()).toList();
  }

  /// All pending questions for [projectId].
  Future<List<PendingQuestion>> getProjectQuestions({required String projectId}) async {
    final pluginQuestions = await _plugin.getProjectQuestions(projectId: projectId);
    return pluginQuestions.map((q) => q.toSharedPendingQuestion()).toList();
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
