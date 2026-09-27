import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "session_detail_resolvers.dart";
import "transcript_builder.dart";

/// One exchange of the rendered transcript: what a prompt set off, with the
/// follow-ups and automation that joined it.
@immutable
sealed class const TranscriptTurn({
  /// The rendered messages the turn covers, in transcript order.
  required final List<String> messageIds,
});

/// A turn opened by a user prompt, which stays its header.
final class const TranscriptPromptTurn({
  /// The prompt that opened the turn; always its first message.
  required final MessageWithParts opener,
  required super.messageIds,
}) extends TranscriptTurn;

/// The messages before the first loaded prompt while older pages remain. The
/// prompt they answer may be on a page that has not loaded.
final class const TranscriptPartialTurn({required super.messageIds}) extends TranscriptTurn;

/// The messages before the first prompt once the whole history is loaded,
/// such as automation that ran before the user wrote anything.
final class const TranscriptPreamble({required super.messageIds}) extends TranscriptTurn;

/// The rendered transcript split into turns.
final class const TranscriptTurns({
  /// Oldest first.
  required final List<TranscriptTurn> turns,

  /// Where in [turns] each rendered message's turn sits.
  required final Map<String, int> turnIndexByMessageId,
}) {
  /// The turn [openerMessageId] opened, or null when that message opened none.
  TranscriptPromptTurn? promptTurnFor({required String openerMessageId}) {
    final index = turnIndexByMessageId[openerMessageId];
    if (index == null) return null;
    final turn = turns[index];
    return turn is TranscriptPromptTurn && turn.opener.info.id == openerMessageId ? turn : null;
  }
}

/// Splits the rendered transcript into turns.
///
/// A user prompt opens a turn that runs until the next prompt. Follow-ups sent
/// while it runs and automation join it and never open one; which user
/// messages are follow-ups is decided by [_opensTurn] alone. Messages before
/// the first prompt form a headless leading segment.
///
/// Pure and stateless like [TranscriptBuilder], so the message list can run it
/// over whatever it renders. It reads message kinds, senders, part statuses
/// and stored text, never ids, so the same messages split the same way after a
/// re-import.
class const TranscriptTurnBuilder() {
  TranscriptTurns build({
    required List<MessageWithParts> messages,

    /// Whether older pages remain, so the leading messages may belong to a
    /// turn whose prompt has not loaded.
    required bool hasOlderMessages,
  }) {
    final segments = <({MessageWithParts? opener, List<MessageWithParts> messages})>[(opener: null, messages: [])];
    _OutputEnd? lastOutput;
    for (final message in messages) {
      if (!message.hasRenderableUserContent) continue;
      if (message.info is MessageUser && _opensTurn(hasOpener: segments.last.opener != null, lastOutput: lastOutput)) {
        segments.add((opener: message, messages: []));
        lastOutput = null;
      }
      segments.last.messages.add(message);
      lastOutput = _outputEndOf(message: message) ?? lastOutput;
    }
    // Only the leading segment can be empty: every other one holds its opener.
    if (segments.first.messages.isEmpty) segments.removeAt(0);

    final turns = <TranscriptTurn>[];
    final turnIndexByMessageId = <String, int>{};
    for (final (index, segment) in segments.indexed) {
      final messageIds = List<String>.unmodifiable([for (final message in segment.messages) message.info.id]);
      for (final id in messageIds) {
        turnIndexByMessageId[id] = index;
      }
      turns.add(switch (segment.opener) {
        final opener? => TranscriptPromptTurn(opener: opener, messageIds: messageIds),
        null when hasOlderMessages => TranscriptPartialTurn(messageIds: messageIds),
        null => TranscriptPreamble(messageIds: messageIds),
      });
    }
    return TranscriptTurns(
      turns: List.unmodifiable(turns),
      turnIndexByMessageId: Map.unmodifiable(turnIndexByMessageId),
    );
  }
}

// The follow-up rule: [_opensTurn] and the two readers of agent output below
// it. Change which user messages open a turn here and nowhere else.

/// How the agent's latest output ends, as the follow-up rule reads it.
enum _OutputEnd() {
  /// A tool or sub-agent step that is pending, running or completed: the
  /// agent is mid-task.
  step,

  /// Text, reasoning, a file, an error, or a step that failed, was cancelled
  /// or reports a status this app does not know.
  answer,
}

/// Whether a rendered user message opens a turn instead of joining the
/// current one as a follow-up.
///
/// [lastOutput] is how the agent's latest output since the current turn
/// opened ends, automation skipped, or null while there is none. A prompt
/// still waiting for output, or whose output ends mid-step, takes the message
/// as a follow-up; output that ends in an answer or a stop makes it a new
/// prompt. Before the first prompt ([hasOpener] false) there is no prompt to
/// wait on, so only a mid-step ending keeps the message in the leading
/// segment, whose prompt may be on a page that has not loaded.
bool _opensTurn({required bool hasOpener, required _OutputEnd? lastOutput}) => switch (lastOutput) {
  null => !hasOpener,
  _OutputEnd.step => false,
  _OutputEnd.answer => true,
};

/// How [message] leaves the agent's output: by its last part that shows
/// output, as an answer when it is an error, and not at all when it is a user
/// message, automation, or an agent message that shows no output yet.
_OutputEnd? _outputEndOf({required MessageWithParts message}) {
  switch (message.info) {
    case MessageAssistant(sender: MessageSender.agent):
      _OutputEnd? end;
      for (final part in message.parts) {
        end = _partEnd(part: part) ?? end;
      }
      return end;
    case MessageError():
      return _OutputEnd.answer;
    case MessageUser() || MessageAssistant():
      return null;
  }
}

/// How [part] ends output, or null when it shows none. Reads [ToolStatus]
/// directly, because a cancelled step counts as finished in a transcript
/// summary but here means the agent stopped.
_OutputEnd? _partEnd({required MessagePart part}) => switch (part) {
  MessagePartTool(state: ToolState(:final status)) ||
  MessagePartSubtask(taskState: ToolState(:final status)) => switch (status) {
    ToolStatus.pending || ToolStatus.running || ToolStatus.completed => _OutputEnd.step,
    // An unknown status opens a turn: a spare boundary costs less than a
    // prompt hidden inside the turn before it.
    ToolStatus.error || ToolStatus.cancelled || ToolStatus.unknown => _OutputEnd.answer,
  },
  // A sub-agent without its own lifecycle never reads as failed.
  MessagePartSubtask() => _OutputEnd.step,
  MessagePartText(:final text) || MessagePartReasoning(:final text) => text.isEmpty ? null : _OutputEnd.answer,
  MessagePartFile() => _OutputEnd.answer,
  MessagePartStepStart() ||
  MessagePartStepFinish() ||
  MessagePartSnapshot() ||
  MessagePartPatch() ||
  MessagePartAgent() ||
  MessagePartRetry() ||
  MessagePartCompaction() => null,
};
