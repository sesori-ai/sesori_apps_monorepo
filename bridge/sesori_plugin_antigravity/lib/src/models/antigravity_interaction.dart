import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

sealed class const AntigravityInteraction({
  required final Object requestId,
  required final String sessionId,
});

final class const AntigravityPermission({
  required super.requestId,
  required super.sessionId,
  required final String tool,
  required final String description,
  required final String allowOptionId,
  required final String? rejectOptionId,
}) extends AntigravityInteraction;

final class AntigravityQuestion({
  required super.requestId,
  required super.sessionId,
  required final PluginQuestionInfo question,
  required Map<String, String> optionIdsByLabel,
}) extends AntigravityInteraction {
  final Map<String, String> optionIdsByLabel = Map.unmodifiable(optionIdsByLabel);
}

class const AntigravityInteractionException({
  required final String message,
  required final Object cause,
}) implements Exception {
  @override
  String toString() => "Antigravity interaction: $message";
}
