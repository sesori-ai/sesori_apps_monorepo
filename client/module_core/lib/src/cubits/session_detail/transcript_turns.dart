import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "session_detail_resolvers.dart";
import "transcript_builder.dart";

/// Where a turn stands. A finished turn's outcome comes from how it ends: its
/// last agent output or error, with automation and follow-ups skipped.
@immutable
sealed class const TranscriptTurnOutcome();

/// The newest turn while the session is busy.
final class const TranscriptTurnRunning() extends TranscriptTurnOutcome;

/// A turn that ends in an error message or a failed step.
final class const TranscriptTurnFailed({
  /// The first line of the error message; null when a failed step ends the
  /// turn or the message has no text.
  required final String? errorLine,
}) extends TranscriptTurnOutcome;

/// A turn that ends without failing. A cancelled last step counts as done,
/// since there is no stopped state yet.
final class const TranscriptTurnDone({
  /// The first line of the text the turn ends in; null when it ends in a step,
  /// a file or no output. Streaming text is not read.
  required final String? answerLine,
}) extends TranscriptTurnOutcome;

/// What a folded turn's one line tells, alike for every kind of turn.
final class const TranscriptTurnSummary({
  /// Every step in the turn's step groups, running steps included.
  required final int steps,

  /// How many of [steps] failed.
  required final int failedSteps,
  required final TranscriptTurnOutcome outcome,
});

/// One exchange of the rendered transcript: what a prompt set off, with the
/// follow-ups and automation that joined it.
@immutable
sealed class const TranscriptTurn({
  /// The rendered messages the turn covers, in transcript order.
  required final List<String> messageIds,
  required final TranscriptTurnSummary summary,
});

/// A turn opened by a user prompt, which stays its header.
final class const TranscriptPromptTurn({
  /// The prompt that opened the turn; always its first message.
  required final MessageWithParts opener,

  /// From the opener's creation to the latest time in the turn; null when the
  /// opener carries no time.
  required final Duration? duration,
  required super.messageIds,
  required super.summary,
}) extends TranscriptTurn;

/// The messages before the first loaded prompt while older pages remain. The
/// prompt they answer may be on a page that has not loaded.
final class const TranscriptPartialTurn({required super.messageIds, required super.summary}) extends TranscriptTurn;

/// The messages before the first prompt once the whole history is loaded,
/// such as automation that ran before the user wrote anything.
final class const TranscriptPreamble({required super.messageIds, required super.summary}) extends TranscriptTurn;

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
/// over whatever it renders. It reads message kinds, senders, part statuses,
/// stored text and times, never ids, so the same messages split the same way
/// after a re-import.
class const TranscriptTurnBuilder() {
  TranscriptTurns build({
    required List<MessageWithParts> messages,

    /// [TranscriptBuilder]'s blocks for [messages], which hold the step groups.
    required Transcript transcript,
    required bool isBusy,

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
      final summary = _summaryOf(
        messages: segment.messages,
        transcript: transcript,
        isRunning: isBusy && index == segments.length - 1,
      );
      turns.add(switch (segment.opener) {
        final opener? => TranscriptPromptTurn(
          opener: opener,
          duration: _durationOf(opener: opener, messages: segment.messages),
          messageIds: messageIds,
          summary: summary,
        ),
        null when hasOlderMessages => TranscriptPartialTurn(messageIds: messageIds, summary: summary),
        null => TranscriptPreamble(messageIds: messageIds, summary: summary),
      });
    }
    return TranscriptTurns(
      turns: List.unmodifiable(turns),
      turnIndexByMessageId: Map.unmodifiable(turnIndexByMessageId),
    );
  }

  static TranscriptTurnSummary _summaryOf({
    required List<MessageWithParts> messages,
    required Transcript transcript,
    required bool isRunning,
  }) {
    var steps = 0;
    var failedSteps = 0;
    TranscriptTurnOutcome ending = const TranscriptTurnDone(answerLine: null);
    for (final message in messages) {
      for (final block in transcript.blocksFor(messageId: message.info.id)) {
        if (block is! TranscriptGroupBlock) continue;
        steps += block.steps.length;
        failedSteps += block.summary.failedCount;
      }
      switch (message.info) {
        case MessageAssistant(sender: MessageSender.agent):
          for (final part in message.parts) {
            ending = _endingIn(part: part) ?? ending;
          }
        case MessageError(:final errorMessage):
          ending = TranscriptTurnFailed(errorLine: _firstLine(text: errorMessage));
        case MessageAssistant() || MessageUser():
          // Automation and follow-ups neither answer nor fail the turn.
          break;
      }
    }
    return TranscriptTurnSummary(
      steps: steps,
      failedSteps: failedSteps,
      outcome: isRunning ? const TranscriptTurnRunning() : ending,
    );
  }

  /// The outcome of a turn that ends in [part], or null when [part] shows no
  /// output. Only text gives an excerpt, and only a failed step fails.
  static TranscriptTurnOutcome? _endingIn({required MessagePart part}) => switch (part) {
    MessagePartText(:final text) => text.isEmpty ? null : TranscriptTurnDone(answerLine: _firstLine(text: text)),
    MessagePartTool(state: ToolState(status: ToolStatus.error)) ||
    MessagePartSubtask(taskState: ToolState(status: ToolStatus.error)) => const TranscriptTurnFailed(errorLine: null),
    MessagePartTool() || MessagePartSubtask() || MessagePartFile() => const TranscriptTurnDone(answerLine: null),
    MessagePartReasoning(:final text) => text.isEmpty ? null : const TranscriptTurnDone(answerLine: null),
    MessagePartStepStart() ||
    MessagePartStepFinish() ||
    MessagePartSnapshot() ||
    MessagePartPatch() ||
    MessagePartAgent() ||
    MessagePartRetry() ||
    MessagePartCompaction() => null,
  };

  static Duration? _durationOf({required MessageWithParts opener, required List<MessageWithParts> messages}) {
    final start = opener.info.time?.created;
    if (start == null) return null;
    var end = start;
    for (final message in messages) {
      if (message.info.time case MessageTime(:final created, :final completed)) {
        final latest = completed ?? created;
        if (latest > end) end = latest;
      }
    }
    return Duration(milliseconds: end - start);
  }

  /// The first line of [text] that holds more than whitespace, trimmed; null
  /// when none does. Stops at that line, since answers can be long.
  static String? _firstLine({required String text}) {
    var start = 0;
    while (start < text.length) {
      final newline = text.indexOf("\n", start);
      final end = newline < 0 ? text.length : newline;
      final line = text.substring(start, end).trim();
      if (line.isNotEmpty) return line;
      start = end + 1;
    }
    return null;
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
