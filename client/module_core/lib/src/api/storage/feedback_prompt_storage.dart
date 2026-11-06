import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../foundation/models/feedback/feedback_prompt_state.dart";
import "../../foundation/persistence/persistence_keys.dart";
import "../../logging/logging.dart";

/// Device-scoped automatic rating prompt progress, one JSON value that
/// survives sign-out and account switches.
@lazySingleton
class FeedbackPromptStorage({required final PersisterRepository _persister}) {
  /// The stored progress, or null when none is stored or it is unreadable.
  Future<FeedbackPromptState?> read() async {
    final value = await _persister.readString(key: StringPreferenceKey.feedbackPrompt);
    if (value == null) return null;
    try {
      return FeedbackPromptState.fromJson(jsonDecodeMap(value));
    } on Object catch (error, stackTrace) {
      // Only delays or advances one prompt; the next write replaces it.
      logw("Discarding unreadable feedback prompt state", error, stackTrace);
      return null;
    }
  }

  Future<void> write({required FeedbackPromptState state}) =>
      _persister.writeString(key: StringPreferenceKey.feedbackPrompt, value: jsonEncode(state.toJson()));
}
