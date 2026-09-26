import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Desktop never shows the automatic rating sheet; the shared session cubits
/// only need the dependency to resolve.
@LazySingleton(as: FeedbackPromptConfigSource)
class NoOpFeedbackPromptConfigSource() implements FeedbackPromptConfigSource {
  @override
  Future<FeedbackPromptConfigValues> fetchValues() async => (interactionThreshold: null, cooldownDays: null);
}
