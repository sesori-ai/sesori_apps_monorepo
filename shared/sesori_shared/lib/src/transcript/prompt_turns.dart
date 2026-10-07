import "../models/sesori/message.dart";
import "../models/sesori/message_part.dart";
import "../models/sesori/message_with_parts.dart";

/// How a transcript names and shows a user prompt, shared by the app and the
/// bridge so both read the same prompts.
extension SessionMessagePresentation on MessageWithParts {
  /// False only for a user message with no text and no known file, which the
  /// transcript hides.
  bool get hasRenderableUserContent {
    if (info is! MessageUser) return true;
    return parts.any(
      (part) => switch (part) {
        MessagePartText(:final text) => text.isNotEmpty,
        MessagePartFile(:final attachment) => attachment is! MessageAttachmentUnknown,
        MessagePartReasoning() ||
        MessagePartTool() ||
        MessagePartSubtask() ||
        MessagePartStepStart() ||
        MessagePartStepFinish() ||
        MessagePartSnapshot() ||
        MessagePartPatch() ||
        MessagePartAgent() ||
        MessagePartRetry() ||
        MessagePartCompaction() => false,
      },
    );
  }

  /// What a user prompt says, wherever the app names it outside its bubble:
  /// its whole text, else its first attachment's name, else null. Views show
  /// their localized "Attachment" for null.
  String? get promptText {
    final text = parts.whereType<MessagePartText>().map((part) => part.text).join("\n");
    if (text.isNotEmpty) return text;
    final filename = switch (parts.whereType<MessagePartFile>().firstOrNull?.attachment) {
      MessageAttachmentInlineImage(:final filename) ||
      MessageAttachmentRemoteUrl(:final filename) ||
      MessageAttachmentStoredImage(:final filename) ||
      MessageAttachmentMetadata(:final filename) => filename?.trim(),
      MessageAttachmentUnknown() || null => null,
    };
    return filename == null || filename.isEmpty ? null : filename;
  }
}

/// A run of rendered messages that [splitPromptTurns] keeps together.
sealed class const PromptTurnSegment({
  /// In transcript order; never empty.
  required final List<MessageWithParts> messages,
});

/// The messages before the first prompt opens a turn. Their prompt may sit
/// before the given messages, or there may be none, such as automation that
/// ran before the user wrote anything.
final class const LeadingPromptSegment({required super.messages}) extends PromptTurnSegment;

/// A turn opened by a user prompt, with the follow-ups and automation that
/// joined it.
final class const PromptSegment({
  /// The prompt that opened the turn; always the first of the messages.
  required final MessageWithParts opener,
  required super.messages,
}) extends PromptTurnSegment;

/// Splits [messages] into prompt turns, oldest first.
///
/// A user prompt opens a turn that runs until the next prompt. Follow-ups sent
/// while it runs and automation join it and never open one; which user
/// messages are follow-ups is decided by [_opensTurn] alone. Messages before
/// the first prompt form one [LeadingPromptSegment]. Hidden user messages
/// ([SessionMessagePresentation.hasRenderableUserContent] false) are left out.
///
/// It reads message kinds, senders, part statuses and stored text, never ids,
/// so the same messages split the same way after a re-import.
List<PromptTurnSegment> splitPromptTurns({required List<MessageWithParts> messages}) {
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
  return List.unmodifiable([
    for (final segment in segments)
      switch (segment.opener) {
        final opener? => PromptSegment(opener: opener, messages: List.unmodifiable(segment.messages)),
        null => LeadingPromptSegment(messages: List.unmodifiable(segment.messages)),
      },
  ]);
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
