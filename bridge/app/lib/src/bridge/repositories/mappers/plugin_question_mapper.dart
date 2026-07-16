import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../plugin_to_shared_mapping.dart";

extension PluginPendingQuestionMapping on PluginPendingQuestion {
  /// Maps to the shared [PendingQuestion] wire model for the mobile client.
  PendingQuestion toSharedPendingQuestion({
    required String sessionId,
    required String? displaySessionId,
  }) => PendingQuestion(
    id: id,
    sessionID: sessionId,
    displaySessionId: displaySessionId,
    questions: questions.map((qi) => qi.toSharedQuestionInfo()).toList(),
  );
}
