import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/src/hermes_event_mapper.dart";
import "package:hermes_plugin/src/repositories/hermes_session_replay_collector.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "fixtures/hermes_failure_copy_fixtures.dart";

// The recorded replay's session, given a synthetic id.
const String _sessionId = "00000000-0000-4000-8000-00000000e001";

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
          _notice(errorName: "hermes_failed_turn", text: notice.replaceAll("`", "")),
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

    test("a recorded compaction summary replays as a compaction row in its place", () {
      // Recorded from Hermes v0.21.5 after an automatic compaction, with
      // synthetic ids and shortened prompts.
      final recorded =
          jsonDecode(File("test/fixtures/replay_compaction_auto.json").readAsStringSync()) as List<dynamic>;
      final messages = _replay(
        frames: [
          for (final frame in recorded)
            if (frame case {"params": {"update": final Map<String, dynamic> update}}) update,
        ],
      );

      expect(messages.map((message) => message.info), [
        for (var turn = 0; turn < 4; turn++) ...[isA<PluginMessageUser>(), isA<PluginMessageAssistant>()],
      ]);
      final compaction = messages[1].parts.single as PluginMessagePartCompaction;
      expect(compaction.messageID, "$_sessionId-compaction-0");
      final state = compaction.compactionState as PluginCompactionStateCompleted;
      expect(state.summary, startsWith("## Historical Task Snapshot"));
      expect(state.summary, isNot(contains("REFERENCE ONLY")));
      expect(state.summary, isNot(contains("END OF CONTEXT SUMMARY")));
      expect((state.freedTokens, state.trigger), (null, null));
      expect(messages.map(_textOf).where((text) => text.contains("CONTEXT COMPACTION")), isEmpty);
    });

    // The bridge pairs a live reply with its replayed copy by content, so a
    // reply that reads differently on replay shows twice after a reload.
    test("a reply after a tool round reads the same live as on replay", () {
      // Recorded from Hermes v0.21.5 with synthetic ids: a read_file round,
      // then a reply whose first live chunk starts with a paragraph break.
      final recorded =
          jsonDecode(File("test/fixtures/reply_after_tool_round.json").readAsStringSync()) as Map<String, dynamic>;
      List<Map<String, dynamic>> updates({required String key}) => [
        if (recorded[key] case final List<dynamic> frames)
          for (final frame in frames)
            if (frame case {"params": {"update": final Map<String, dynamic> update}}) update,
      ];

      final replayed = _replay(frames: updates(key: "replay"));
      final mapper = HermesEventMapper(
        launchDirectory: "/repo",
        pluginId: "hermes",
        configurationTracker: AcpSessionConfigurationTracker(),
        childSessions: AcpChildSessionTracker(),
        clock: const ServerClock(),
      );
      mapper.beginTurn(sessionId: _sessionId, messageId: null);
      final events = [
        for (final update in updates(key: "live"))
          ...mapper.map(
            AcpNotification(
              method: "session/update",
              params: {"sessionId": _sessionId, "update": update},
            ),
          ),
        ...mapper.finalizeTurn(sessionId: _sessionId),
      ];

      final reply = _textOf(replayed.last);
      expect(reply, startsWith("`greeter.py`"));
      final saved = events
          .whereType<BridgeSseMessagePartUpdated>()
          .map((event) => event.part)
          .whereType<PluginMessagePartText>()
          .last;
      expect(saved.text, reply);
      final streamed = events.whereType<BridgeSseMessagePartDelta>().where((delta) => delta.partID == saved.id);
      expect(streamed.map((delta) => delta.delta).join(), reply);
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

/// Replays [frames] the way `AcpPlugin.getSessionMessages` wires Hermes:
/// Hermes's collector around the standard one, with Hermes's mapper as
/// normalizer and halt classifier.
List<PluginMessageWithParts> _replay({required List<Map<String, dynamic>> frames}) {
  final mapper = HermesEventMapper(
    launchDirectory: "/repo",
    pluginId: "hermes",
    configurationTracker: AcpSessionConfigurationTracker(),
    childSessions: AcpChildSessionTracker(),
    clock: const ServerClock(),
  );
  final collector = HermesSessionReplayCollector(
    sessionId: _sessionId,
    standardCollector: AcpReplayCollector(
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
    ),
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
