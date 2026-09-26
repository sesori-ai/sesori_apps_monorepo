import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../di/firebase_register_module.dart";

@firebaseDisabledEnvironment
@LazySingleton(as: FeedbackPromptConfigSource)
class NoOpFeedbackPromptConfigSource() implements FeedbackPromptConfigSource {
  @override
  Future<FeedbackPromptConfigValues> fetchValues() async => (interactionThreshold: null, cooldownDays: null);
}
