import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "session_detail_resolvers.dart";
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

/// Only sub-agents work: the main agent streams nothing and runs no step of
/// its own.
final class const TranscriptActivitySubAgents({
  /// How many sub-agents run; at least one.
  required final int count,

  /// When the earliest running sub-agent started, in epoch ms; null when none
  /// of them has a known start.
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

    /// Supplies the time of the message holding each sub-agent step.
    required List<MessageWithParts> messages,

    /// Whether the session works, with no question or permission waiting.
    required bool isBusy,

    /// Whether the bridge reports the main agent mid-turn; a turn blocked on a
    /// foreground sub-agent still counts, since a new prompt waits for it.
    required bool mainAgentRunning,
    required String? retryErrorMessage,
    required bool hasStreamingText,
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
  }) {
    if (!isBusy || retryErrorMessage != null || hasStreamingText) return const TranscriptActivityIdle();
    final running = runningChildren(children: children, childStatuses: childStatuses);
    if (running.isNotEmpty && !mainAgentRunning && !_hasOwnRunningStep(transcript: transcript)) {
      return TranscriptActivitySubAgents(
        count: running.length,
        sinceMs: _earliestStart(running: running, transcript: transcript, messages: messages),
      );
    }
    if (transcript.liveStep != null) return const TranscriptActivityIdle();
    // While busy, the last turn is the running one.
    return TranscriptActivityWorking(
      sinceMs: switch (turns.turns.lastOrNull) {
        TranscriptPromptTurn(:final opener) => opener.info.time?.created,
        TranscriptPartialTurn() || TranscriptPreamble() || null => null,
      },
    );
  }

  /// Whether the main agent runs a step of its own; a running sub-agent step
  /// is the sub-agent's work, not the main agent's.
  static bool _hasOwnRunningStep({required Transcript transcript}) => transcript.blocksByMessageId.values.any(
    (blocks) => blocks.any(
      (block) => block is TranscriptGroupBlock && block.runningSteps.any((step) => step is! TranscriptSubAgentStep),
    ),
  );

  /// A sub-agent starts with the message holding its first step, else with
  /// its own session; the earliest known start among [running] wins.
  static int? _earliestStart({
    required List<Session> running,
    required Transcript transcript,
    required List<MessageWithParts> messages,
  }) {
    final createdByPartId = {
      for (final message in messages)
        if (message.info.time?.created case final created?)
          for (final part in message.parts)
            if (part is MessagePartSubtask) part.id: created,
    };
    final stepStartByChildId = <String, int>{};
    for (final blocks in transcript.blocksByMessageId.values) {
      for (final block in blocks) {
        if (block is! TranscriptGroupBlock) continue;
        for (final step in block.steps) {
          if (step case TranscriptSubAgentStep(:final childSession?, :final part)) {
            final created = createdByPartId[part.id];
            final known = stepStartByChildId[childSession.id];
            if (created != null && (known == null || created < known)) stepStartByChildId[childSession.id] = created;
          }
        }
      }
    }
    int? earliest;
    for (final child in running) {
      final start = stepStartByChildId[child.id] ?? child.time?.created;
      if (start != null && (earliest == null || start < earliest)) earliest = start;
    }
    return earliest;
  }
}
