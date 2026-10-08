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
  /// When the newest prompt was sent, in epoch ms: one still waiting for its
  /// message from when the bridge accepted it, else the running turn's latest
  /// user message (a message sent mid-turn, else the prompt that opened it).
  /// Null while this surface's prompt is still on its way to the bridge, when
  /// the harness reports no time, or when no user message has loaded.
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

/// No live row: the session is idle, or streaming text, a live step, a running
/// compaction or the retry row already shows progress.
final class const TranscriptActivityIdle() extends TranscriptActivity;

/// Decides the transcript's live row. Pure and stateless like
/// [TranscriptTurnBuilder], so the rule is tested without a widget and stays
/// harness-neutral: a harness gap shows only as a missing time.
class const TranscriptActivityBuilder() {
  TranscriptActivity build({
    required Transcript transcript,

    /// Supplies the time of the message holding each sub-agent step, and any
    /// running compaction.
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

    /// The sent prompts shown below the messages, oldest first, each with when
    /// the bridge accepted it, or null while it is still on its way there.
    required List<({String promptId, int? acceptedAt})> pendingPrompts,

    /// The newest prompt the bridge was seen holding. Its delivered message
    /// keeps counting from the acceptance, which the message itself lacks.
    required ({String promptId, int acceptedAt})? lastHeldPrompt,
  }) {
    if (!isBusy || retryErrorMessage != null || hasStreamingText) return const TranscriptActivityIdle();
    final running = runningChildren(children: children, childStatuses: childStatuses);
    // A running compaction's own row is live, and it is the main agent's work.
    final compacting = _isCompacting(messages: messages);
    if (running.isNotEmpty && !mainAgentRunning && !compacting && !_hasOwnRunningStep(transcript: transcript)) {
      return TranscriptActivitySubAgents(
        count: running.length,
        sinceMs: _earliestStart(running: running, transcript: transcript, messages: messages),
      );
    }
    if (transcript.liveStep != null || compacting) return const TranscriptActivityIdle();
    // A sent prompt still waiting for its message shows below every message,
    // so the newest of them is the newest prompt: never count from an older
    // prompt's start.
    final deliveredPromptIds = {
      for (final message in messages)
        if (message.info case MessageUser(:final promptId?) when message.hasRenderableUserContent) promptId,
    };
    final pending = pendingPrompts.where((prompt) => !deliveredPromptIds.contains(prompt.promptId)).lastOrNull;
    if (pending != null) return TranscriptActivityWorking(sinceMs: pending.acceptedAt);
    // While busy, the last turn is the running one, and it runs to the newest
    // message. So whatever the turn's shape, its latest user message is the
    // newest shown one: a message sent mid-turn, else the opener. One the
    // bridge held first keeps its acceptance time, which is earlier, so the
    // count never steps back when the harness takes it.
    final latestUser = messages
        .where((message) => message.info is MessageUser && message.hasRenderableUserContent)
        .lastOrNull;
    final created = latestUser?.info.time?.created;
    int? acceptedAt;
    if (latestUser?.info case MessageUser(:final promptId?) when promptId == lastHeldPrompt?.promptId) {
      acceptedAt = lastHeldPrompt?.acceptedAt;
    }
    return TranscriptActivityWorking(
      sinceMs: acceptedAt != null && (created == null || acceptedAt < created) ? acceptedAt : created,
    );
  }

  static bool _isCompacting({required List<MessageWithParts> messages}) => messages.any(
    (message) => message.parts.any((part) => part is MessagePartCompaction && part.state is CompactionStateRunning),
  );

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
