import "package:pi_plugin/src/api/models/pi_event.dart";
import "package:pi_plugin/src/api/models/pi_session_history_dto.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/mappers/pi_message_identity_builder.dart";
import "package:pi_plugin/src/repositories/trackers/pi_message_identity_tracker.dart";
import "package:pi_plugin/src/repositories/trackers/pi_tool_tracker.dart";
import "package:pi_plugin/src/services/pi_event_dispatcher.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const sessionId = "session";
  late PiHistoryMapper history;
  late PiEventDispatcher dispatcher;
  late PiMessageIdentityTracker identities;

  setUp(() {
    identities = PiMessageIdentityTracker(pluginId: "pi");
    history = PiHistoryMapper(pluginId: "pi");
    dispatcher = PiEventDispatcher(
      historyMapper: history,
      identityTracker: identities,
      toolTracker: PiToolTracker(),
    );
  });

  test("streaming indices and authoritative final equal cold replay", () {
    final start = _assistant(content: const [], timestamp: 100);
    final finalMessage = _assistant(
      content: [
        {"type": "thinking", "thinking": "Reason"},
        {"type": "text", "text": "Answer"},
        {"type": "toolCall", "id": "call-1", "name": "read", "arguments": <String, Object?>{}},
      ],
      timestamp: 100,
      stopReason: "toolUse",
    );

    dispatcher.map(sessionId: sessionId, event: _event("message_start", {"message": start}));
    final streamed = <BridgeSseEvent>[
      ...dispatcher.map(
        sessionId: sessionId,
        event: _event("message_update", {
          "assistantMessageEvent": {"type": "text_delta", "contentIndex": 1, "delta": "Ans"},
        }),
      ),
      ...dispatcher.map(
        sessionId: sessionId,
        event: _event("message_update", {
          "assistantMessageEvent": {"type": "thinking_delta", "contentIndex": 0, "delta": "Rea"},
        }),
      ),
      ...dispatcher.map(
        sessionId: sessionId,
        event: _event("message_update", {
          "assistantMessageEvent": {
            "type": "toolcall_end",
            "contentIndex": 2,
            "toolCall": {"id": "call-1", "name": "read", "arguments": <String, Object?>{}},
          },
        }),
      ),
    ];
    final finalEvents = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_end", {"message": finalMessage}),
    );

    expect(streamed.whereType<BridgeSseMessageUpdated>(), hasLength(1));
    expect(
      streamed.whereType<BridgeSseMessagePartDelta>().map((event) => event.partID),
      ["pi:session:assistant:100:1-block-2", "pi:session:assistant:100:1-block-1"],
    );
    final replay = history
        .map(
          sessionId: sessionId,
          entries: [
            PiSessionEntryDto.message(
              id: "entry",
              parentId: null,
              timestamp: DateTime.utc(2026),
              message: PiAgentMessageDto.fromJson(finalMessage),
            ),
          ],
          leafId: "entry",
          identities: PiMessageIdentityBuilder(pluginId: "pi", sessionId: sessionId),
        )
        .single;
    expect((finalEvents.first as BridgeSseMessageUpdated).info, replay.info.toJson());
    expect(finalEvents.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part), replay.parts);
  });

  test("tool updates replace cumulative output and duplicate terminal is ignored", () {
    final message = _assistant(
      content: [
        {"type": "toolCall", "id": "call-1", "name": "edit", "arguments": <String, Object?>{}},
      ],
      timestamp: 1,
      stopReason: "toolUse",
    );
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_start", {"message": _assistant(content: [], timestamp: 1)}),
    );
    dispatcher.map(sessionId: sessionId, event: _event("message_end", {"message": message}));

    final first = dispatcher.map(
      sessionId: sessionId,
      event: _event("tool_execution_update", {
        "toolCallId": "call-1",
        "toolName": "edit",
        "partialResult": {
          "content": [
            {"type": "text", "text": "a"},
          ],
        },
      }),
    );
    final second = dispatcher.map(
      sessionId: sessionId,
      event: _event("tool_execution_update", {
        "toolCallId": "call-1",
        "toolName": "edit",
        "partialResult": {
          "content": [
            {"type": "text", "text": "abc"},
          ],
        },
      }),
    );
    final completed = dispatcher.map(
      sessionId: sessionId,
      event: _event("tool_execution_end", {
        "toolCallId": "call-1",
        "toolName": "edit",
        "result": {
          "content": [
            {"type": "text", "text": "done"},
          ],
        },
      }),
    );
    final duplicate = dispatcher.map(
      sessionId: sessionId,
      event: _event("tool_execution_end", {
        "toolCallId": "call-1",
        "toolName": "edit",
        "result": {
          "content": [
            {"type": "text", "text": "other"},
          ],
        },
      }),
    );

    expect((first.single as BridgeSseMessagePartUpdated).part.state?.output, "a");
    expect((second.single as BridgeSseMessagePartUpdated).part.state?.output, "abc");
    expect(completed.whereType<BridgeSseMessagePartUpdated>().single.part.state?.output, "done");
    expect(completed.whereType<BridgeSseSessionDiff>(), hasLength(1));
    expect(duplicate, isEmpty);
  });

  test("malformed tool results are omitted without ending the turn", () {
    final message = _assistant(
      content: [
        {"type": "toolCall", "id": "call-1", "name": "read"},
      ],
      timestamp: 1,
      stopReason: "toolUse",
    );
    dispatcher.map(sessionId: sessionId, event: _event("message_end", {"message": message}));

    expect(
      dispatcher.map(
        sessionId: sessionId,
        event: _event("tool_execution_update", {
          "toolCallId": "call-1",
          "toolName": "read",
          "partialResult": {"content": 7},
        }),
      ),
      isEmpty,
    );
    expect(
      dispatcher
          .map(
            sessionId: sessionId,
            event: _event("agent_settled"),
          )
          .whereType<BridgeSseSessionIdle>(),
      hasLength(1),
    );
  });

  test("provider error and abort finals preserve replay parity", () {
    for (final reason in ["error", "aborted"]) {
      final message = _assistant(
        content: const [],
        timestamp: reason == "error" ? 1 : 2,
        stopReason: reason,
        errorMessage: reason == "error" ? "private provider detail" : null,
      );
      final live = dispatcher.map(
        sessionId: sessionId,
        event: _event("message_end", {"message": message}),
      );
      final replay = history
          .map(
            sessionId: sessionId,
            entries: [
              PiSessionEntryDto.message(
                id: reason,
                parentId: null,
                timestamp: DateTime.utc(2026),
                message: PiAgentMessageDto.fromJson(message),
              ),
            ],
            leafId: reason,
            identities: PiMessageIdentityBuilder(pluginId: "pi", sessionId: sessionId),
          )
          .single;

      expect((live.single as BridgeSseMessageUpdated).info, replay.info.toJson());
      expect(live.single.toString(), isNot(contains("private provider detail")));
    }
  });

  test("late tool args are repaired and unfinished failed tools terminalize", () {
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_start", {"message": _assistant(content: [], timestamp: 3)}),
    );
    final pending = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_update", {
        "assistantMessageEvent": {
          "type": "toolcall_end",
          "contentIndex": 0,
          "toolCall": {
            "id": "call-late",
            "name": "write",
            "arguments": {"path": "late.dart"},
          },
        },
      }),
    );
    final failed = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_end", {
        "message": _assistant(
          content: [
            {
              "type": "toolCall",
              "id": "call-late",
              "name": "write",
              "arguments": {"path": "late.dart"},
            },
          ],
          timestamp: 3,
          stopReason: "error",
          errorMessage: "provider failed",
        ),
      }),
    );

    expect(pending.whereType<BridgeSseMessagePartUpdated>().single.part.state?.status, PluginToolStatus.pending);
    expect(failed.whereType<BridgeSseMessagePartUpdated>().single.part.state?.status, PluginToolStatus.error);
    expect(failed.whereType<BridgeSseMessagePartUpdated>().single.part.state?.error, "Pi tool call did not complete.");
  });

  test("retry, compaction, and only agent_settled produce status lifecycle", () {
    final retry = dispatcher.map(
      sessionId: sessionId,
      event: _event("auto_retry_start", {"attempt": 2, "delayMs": 500}),
      now: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final agentEnd = dispatcher.map(
      sessionId: sessionId,
      event: _event("agent_end", {"willRetry": false}),
    );
    final compacted = dispatcher.map(
      sessionId: sessionId,
      event: _event("compaction_end", {"aborted": false, "willRetry": false}),
    );
    final settled = dispatcher.map(sessionId: sessionId, event: _event("agent_settled"));

    expect((retry.single as BridgeSseSessionStatus).status, {
      "attempt": 2,
      "message": "Pi is retrying the provider request.",
      "next": 1500,
      "runtimeType": "retry",
    });
    expect(agentEnd, isEmpty);
    expect(compacted.whereType<BridgeSseSessionCompacted>(), hasLength(1));
    expect(compacted.whereType<BridgeSseMessagePartUpdated>().single.part.state?.title, "Context compacted");
    expect(settled.whereType<BridgeSseSessionIdle>(), hasLength(1));
  });

  test("interleaved sessions and unknown variants keep state isolated", () {
    dispatcher.map(
      sessionId: "one",
      event: _event("message_start", {"message": _assistant(content: [], timestamp: 1)}),
    );
    dispatcher.map(
      sessionId: "two",
      event: _event("message_start", {"message": _assistant(content: [], timestamp: 2)}),
    );
    final one = dispatcher.map(
      sessionId: "one",
      event: _event("message_update", {
        "assistantMessageEvent": {"type": "text_delta", "contentIndex": 0, "delta": "one"},
      }),
    );
    final two = dispatcher.map(
      sessionId: "two",
      event: _event("message_update", {
        "assistantMessageEvent": {"type": "text_delta", "contentIndex": 0, "delta": "two"},
      }),
    );

    expect(one.whereType<BridgeSseMessagePartDelta>().single.messageID, "pi:one:assistant:1:1");
    expect(two.whereType<BridgeSseMessagePartDelta>().single.messageID, "pi:two:assistant:2:1");
    expect(dispatcher.map(sessionId: sessionId, event: _event("future_event")), isEmpty);
  });

  test("history hydration advances live identities and final removes stale provisional parts", () {
    final hydrated = _assistant(content: const [], timestamp: 10);
    history.map(
      sessionId: sessionId,
      entries: [
        PiSessionEntryDto.message(
          id: "prior",
          parentId: null,
          timestamp: DateTime.utc(2026),
          message: PiAgentMessageDto.fromJson(hydrated),
        ),
        PiSessionEntryDto.compaction(
          id: "compact",
          parentId: "prior",
          timestamp: DateTime.utc(2026),
        ),
      ],
      leafId: "compact",
      identities: identities.rebuild(sessionId: sessionId),
    );
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_start", {"message": hydrated}),
    );
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_update", {
        "assistantMessageEvent": {"type": "thinking_delta", "contentIndex": 0, "delta": "discard"},
      }),
    );
    final finalized = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_end", {"message": hydrated}),
    );
    final compacted = dispatcher.map(
      sessionId: sessionId,
      event: _event("compaction_end", {"aborted": false, "willRetry": false}),
    );

    expect((finalized.first as BridgeSseMessageUpdated).info["id"], "pi:session:assistant:10:2");
    expect(finalized.whereType<BridgeSseMessagePartRemoved>().single.partID, "pi:session:assistant:10:2-block-1");
    expect(
      compacted.whereType<BridgeSseMessageUpdated>().single.info["id"],
      "pi:session:compaction:compaction:2",
    );
  });
}

PiEvent _event(String type, [Map<String, Object?> fields = const {}]) => PiEvent.parse(
  type: type,
  json: {"type": type, ...fields},
);

Map<String, dynamic> _assistant({
  required List<Map<String, Object?>> content,
  required int timestamp,
  String stopReason = "pending",
  String? errorMessage,
}) => {
  "role": "assistant",
  "content": content,
  "provider": "provider",
  "model": "model",
  "stopReason": stopReason,
  "errorMessage": errorMessage,
  "timestamp": timestamp,
};
