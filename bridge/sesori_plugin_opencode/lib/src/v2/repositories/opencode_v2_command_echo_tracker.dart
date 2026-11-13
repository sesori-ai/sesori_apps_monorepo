import "../../prompt_message_tracker.dart";
import "v2_message_mapper.dart";

/// Matches the user message a native command creates to the command's prompt.
///
/// OpenCode 2's command endpoint takes no message id, so that message can't
/// carry its prompt id the way a prompt's message does. OpenCode admits it to
/// the session's inbox while the command request runs, so the first message
/// admitted without a Sesori prompt id while a command is outstanding is the
/// command's. A message the TUI admits in that same moment would be taken for
/// it; nothing else can claim it.
class OpenCodeV2CommandEchoTracker() {
  final Map<String, String> _outstandingBySession = {};
  final PromptMessageTracker _admitted = PromptMessageTracker();

  /// Records [promptId] as [sessionId]'s outstanding command, before it is sent.
  void expect({required String sessionId, required String promptId}) {
    _outstandingBySession[sessionId] = promptId;
  }

  /// Forgets a command whose request failed, so it claims no later message.
  void forget({required String sessionId, required String promptId}) {
    if (_outstandingBySession[sessionId] == promptId) _outstandingBySession.remove(sessionId);
  }

  /// Gives a message admitted to [sessionId] the outstanding command's prompt.
  void observeAdmitted({required String sessionId, required String messageId}) {
    if (V2MessageMapper.promptIdForMessage(messageId: messageId) != null) return;
    if (_outstandingBySession.remove(sessionId) case final promptId?) {
      _admitted.record(messageId: messageId, promptId: promptId);
    }
  }

  /// The prompt of the command that created [messageId], when this bridge sent it.
  String? promptIdFor({required String messageId}) => _admitted.promptIdFor(messageId: messageId);

  void reset() {
    _outstandingBySession.clear();
    _admitted.clear();
  }
}
