import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Layer 2 repository wrapping [BridgePluginApi] for question operations.
///
/// Delegates to the plugin and maps wire-format answer models to the plugin
/// contract shape so routing handlers stay plugin-agnostic.
class QuestionRepository {
  final BridgePluginApi _plugin;

  QuestionRepository({required BridgePluginApi plugin}) : _plugin = plugin;

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
