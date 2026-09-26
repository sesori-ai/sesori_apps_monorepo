import "package:meta/meta.dart";

import "transcript_builder.dart";
import "transcript_turns.dart";

/// What the live row at the newest end of the transcript shows.
@immutable
sealed class const TranscriptActivity();

/// The session works and nothing else shows it: before the first token and
/// between steps.
final class const TranscriptActivityWorking({
  /// When the running turn's prompt was sent, in epoch ms; null when the
  /// harness reports no time or no prompt opened the turn.
  required final int? sinceMs,
}) extends TranscriptActivity;

/// No live row: the session is idle, or streaming text, a live step or the
/// retry row already shows progress.
final class const TranscriptActivityIdle() extends TranscriptActivity;

/// Decides the transcript's live row. Pure and stateless like
/// [TranscriptTurnBuilder], so the rule is tested without a widget and stays
/// harness-neutral: a harness gap shows only as a missing time.
class const TranscriptActivityBuilder() {
  TranscriptActivity build({
    required Transcript transcript,
    required TranscriptTurns turns,

    /// Whether the session works, with no question or permission waiting.
    required bool isBusy,
    required String? retryErrorMessage,
    required bool hasStreamingText,
  }) {
    if (!isBusy || retryErrorMessage != null || hasStreamingText || transcript.liveStep != null) {
      return const TranscriptActivityIdle();
    }
    // While busy, the last turn is the running one.
    return TranscriptActivityWorking(
      sinceMs: switch (turns.turns.lastOrNull) {
        TranscriptPromptTurn(:final opener) => opener.info.time?.created,
        TranscriptPartialTurn() || TranscriptPreamble() || null => null,
      },
    );
  }
}
