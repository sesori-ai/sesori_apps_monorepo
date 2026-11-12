import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/src/hermes_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "fixtures/hermes_failure_copy_fixtures.dart";

const String _sessionId = "s1";

void main() {
  group("Hermes history replay", () {
    test("a turn that failed outside Sesori replays as one error notice", () {
      final messages = _replay(
        frames: [
          _userChunk(text: "Hello"),
          _assistantChunk(text: failedTurnBoundary),
        ],
      );

      expect(messages.map((message) => message.info), [
        isA<PluginMessageUser>(),
        _notice(errorName: "hermes_failed_turn", text: failedTurnBoundary),
      ]);
    });

    test("a refused turn replays as the user's prompt and one error notice", () {
      final messages = _replay(
        frames: [
          _userChunk(text: "Hello"),
          _assistantChunk(text: contentRefusedRow),
        ],
      );

      expect(messages.map((message) => message.info), [
        isA<PluginMessageUser>(),
        _notice(errorName: "hermes_failed_turn", text: contentRefusedRow),
      ]);
    });

    test("a partial turn keeps the tool that ran and shows its warning as the notice", () {
      final messages = _replay(
        frames: [
          _userChunk(text: "List the files"),
          _toolCall(toolCallId: "call-1"),
          _toolCallDone(toolCallId: "call-1"),
          _assistantChunk(text: partialFailedTurnBoundary),
        ],
      );

      expect(messages.map((message) => message.info), [
        isA<PluginMessageUser>(),
        isA<PluginMessageAssistant>(),
        _notice(errorName: "hermes_partial_turn", text: partialFailedTurnBoundary),
      ]);
      expect(messages[1].parts.single, isA<PluginMessagePartTool>());
    });

    test("a failure copy Hermes saved as a reply replays as a notice", () {
      for (final MapEntry(key: family, value: notice) in failureNotices.entries) {
        final messages = _replay(
          frames: [
            _userChunk(text: "Hello"),
            _assistantChunk(text: notice),
          ],
        );
        expect(
          messages.last.info,
          _notice(errorName: "hermes_failed_turn", text: notice),
          reason: family,
        );
      }
    });

    test("keeps real replies around a failed turn", () {
      final messages = _replay(
        frames: [
          _userChunk(text: "First"),
          _assistantChunk(text: "First answer."),
          _userChunk(text: "Second"),
          _assistantChunk(text: failedTurnBoundary),
          _userChunk(text: "Third"),
          _assistantChunk(text: "Third answer."),
        ],
      );

      expect(messages.map((message) => message.info.runtimeType), [
        PluginMessageUser,
        PluginMessageAssistant,
        PluginMessageUser,
        PluginMessageError,
        PluginMessageUser,
        PluginMessageAssistant,
      ]);
      expect(messages.map(_textOf), ["First", "First answer.", "Second", "", "Third", "Third answer."]);
    });

    test("a reply that quotes the row stays a reply", () {
      const quoted = "Hermes told you: $failedTurnBoundary I have now retried it.";
      final messages = _replay(
        frames: [
          _userChunk(text: "What happened?"),
          _assistantChunk(text: quoted),
        ],
      );

      expect(messages.last.info, isA<PluginMessageAssistant>());
      expect(messages.map(_textOf), ["What happened?", quoted]);
    });

    test("a user prompt that repeats the row stays the user's prompt", () {
      final messages = _replay(frames: [_userChunk(text: failedTurnBoundary)]);

      expect(messages.single.info, isA<PluginMessageUser>());
      expect(messages.map(_textOf), [failedTurnBoundary]);
    });
  });
}

Matcher _notice({required String errorName, required String text}) => isA<PluginMessageError>()
    .having((error) => error.errorName, "errorName", errorName)
    .having((error) => error.errorMessage, "errorMessage", text);

/// Replays [frames] the way `AcpPlugin.getSessionMessages` wires Hermes: the
/// standard collector, with Hermes's mapper as normalizer and halt classifier.
List<PluginMessageWithParts> _replay({required List<Map<String, dynamic>> frames}) {
  final mapper = HermesEventMapper(
    launchDirectory: "/repo",
    pluginId: "hermes",
    configurationTracker: AcpSessionConfigurationTracker(),
    childSessions: AcpChildSessionTracker(),
  );
  final collector = AcpReplayCollector(
    sessionUpdateNormalizer: mapper.normalizeSessionUpdate,
    shellCommandResolver: null,
    toolNameResolver: null,
    sessionId: _sessionId,
    agentId: "hermes",
    initialUserMessage: null,
    messageIdOverride: null,
    messageTimeResolver: null,
    haltClassifier: mapper.classifyHaltNotice,
    toolPartReplacement: null,
    toolPartSuppression: null,
  );
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
