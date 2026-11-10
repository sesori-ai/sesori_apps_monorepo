import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/src/repositories/hermes_replay_collector.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const String _sessionId = "s1";

/// The row Hermes saves to close a turn that failed before any tool ran
/// (`messages.display_kind = 'failed_turn'` in `~/.hermes/state.db`).
const String _failedTurnBoundary =
    "Your request was not processed. Send it again if you still want me to carry it out.";

/// The same row when a tool already ran in the failed turn.
const String _partialFailedTurnBoundary =
    "This turn did not complete. Some actions may already have run; verify their effects before resending.";

void main() {
  group("HermesReplayCollector", () {
    test("drops the saved failed-turn boundary after a failed prompt", () {
      final messages = _replay(
        frames: [
          _userChunk(text: "Hello"),
          _assistantChunk(text: _failedTurnBoundary),
        ],
      );

      expect(messages, hasLength(1));
      expect(messages.single.info, isA<PluginMessageUser>());
    });

    test("drops the partial boundary but keeps the tool that ran", () {
      final messages = _replay(
        frames: [
          _userChunk(text: "List the files"),
          _toolCall(toolCallId: "call-1"),
          _toolCallDone(toolCallId: "call-1"),
          _assistantChunk(text: _partialFailedTurnBoundary),
        ],
      );

      expect(messages.map((message) => message.info.runtimeType), [PluginMessageUser, PluginMessageAssistant]);
      final assistant = messages.last;
      expect(assistant.parts.whereType<PluginMessagePartTool>(), hasLength(1));
      expect(assistant.parts.whereType<PluginMessagePartText>(), isEmpty);
    });

    test("keeps real replies around a failed turn", () {
      final messages = _replay(
        frames: [
          _userChunk(text: "First"),
          _assistantChunk(text: "First answer."),
          _userChunk(text: "Second"),
          _assistantChunk(text: _failedTurnBoundary),
          _userChunk(text: "Third"),
          _assistantChunk(text: "Third answer."),
        ],
      );

      expect(
        messages.map(_textOf),
        ["First", "First answer.", "Second", "Third", "Third answer."],
      );
    });

    test("keeps a reply that quotes the boundary", () {
      const quoted = "Hermes told you: $_failedTurnBoundary I have now retried it.";
      final messages = _replay(
        frames: [
          _userChunk(text: "What happened?"),
          _assistantChunk(text: quoted),
        ],
      );

      expect(messages.map(_textOf), ["What happened?", quoted]);
    });

    test("keeps a user prompt that repeats the boundary", () {
      final messages = _replay(frames: [_userChunk(text: _failedTurnBoundary)]);

      expect(messages.map(_textOf), [_failedTurnBoundary]);
    });
  });
}

List<PluginMessageWithParts> _replay({required List<Map<String, dynamic>> frames}) {
  final collector = HermesReplayCollector(standardCollector: _standardCollector());
  for (final update in frames) {
    collector.consumeNotification(
      notification: AcpNotification(
        method: "session/update",
        params: {"sessionId": _sessionId, "update": update},
      ),
    );
  }
  return collector.buildWithAssistantSelection(modelId: null, providerId: null, variant: null);
}

AcpReplayCollector _standardCollector() => AcpReplayCollector(
  sessionUpdateNormalizer: null,
  shellCommandResolver: null,
  sessionId: _sessionId,
  agentId: "hermes",
  initialUserMessage: null,
  messageIdOverride: null,
  messageTimeResolver: null,
  haltClassifier: null,
  toolPartReplacement: null,
  toolPartSuppression: null,
);

String _textOf(PluginMessageWithParts message) =>
    message.parts.whereType<PluginMessagePartText>().map((part) => part.text).join();

// Hermes replays history rows as message chunks without message ids
// (acp_adapter/server.py::_history_replay_updates).
Map<String, dynamic> _userChunk({required String text}) => {
  "sessionUpdate": "user_message_chunk",
  "content": {"type": "text", "text": text},
};

Map<String, dynamic> _assistantChunk({required String text}) => {
  "sessionUpdate": "agent_message_chunk",
  "content": {"type": "text", "text": text},
};

Map<String, dynamic> _toolCall({required String toolCallId}) => {
  "sessionUpdate": "tool_call",
  "toolCallId": toolCallId,
  "title": "terminal: ls",
  "kind": "execute",
  "status": "pending",
};

Map<String, dynamic> _toolCallDone({required String toolCallId}) => {
  "sessionUpdate": "tool_call_update",
  "toolCallId": toolCallId,
  "status": "completed",
};
