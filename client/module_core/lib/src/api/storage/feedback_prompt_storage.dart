import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../foundation/models/feedback/feedback_prompt_state.dart";
import "../../foundation/persistence/persistence_keys.dart";
import "../../logging/logging.dart";

const _storageVersion = 1;

/// Device-scoped automatic rating sheet progress, one versioned JSON value
/// that survives sign-out and account switches.
@lazySingleton
class FeedbackPromptStorage({required final PersisterRepository _persister}) {
  /// The stored progress, or null when none is stored or it is unreadable.
  Future<FeedbackPromptState?> read() async {
    final value = await _persister.readString(key: StringPreferenceKey.feedbackPrompt);
    if (value == null) return null;
    try {
      return switch (jsonDecodeMap(value)) {
        {
          "version": _storageVersion,
          "kind": "counting",
          "positiveCount": final int positiveCount,
          "lastShownAt": final String? lastShownAt,
        }
            when positiveCount >= 0 =>
          FeedbackPromptCounting(
            positiveCount: positiveCount,
            lastShownAt: lastShownAt == null ? null : DateTime.parse(lastShownAt),
          ),
        {"version": _storageVersion, "kind": "retired"} => const FeedbackPromptRetired(),
        _ => throw FormatException("Invalid stored feedback prompt state", value),
      };
    } on Object catch (error, stackTrace) {
      // Only delays or advances one prompt; the next write replaces it.
      logw("Discarding unreadable feedback prompt state", error, stackTrace);
      return null;
    }
  }

  Future<void> write({required FeedbackPromptState state}) => _persister.writeString(
    key: StringPreferenceKey.feedbackPrompt,
    value: jsonEncode(switch (state) {
      FeedbackPromptCounting(:final positiveCount, :final lastShownAt) => {
        "version": _storageVersion,
        "kind": "counting",
        "positiveCount": positiveCount,
        "lastShownAt": lastShownAt?.toUtc().toIso8601String(),
      },
      FeedbackPromptRetired() => {"version": _storageVersion, "kind": "retired"},
    }),
  );
}
