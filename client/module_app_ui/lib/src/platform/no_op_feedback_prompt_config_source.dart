import "package:sesori_dart_core/sesori_dart_core.dart";

/// Supplies no remote values, so the feedback prompt keeps its built-in
/// defaults. Shells bind it where no remote config exists.
class NoOpFeedbackPromptConfigSource() implements FeedbackPromptConfigSource {
  @override
  Future<FeedbackPromptConfigValues> fetchValues() async => (interactionThreshold: null, cooldownDays: null);
}
