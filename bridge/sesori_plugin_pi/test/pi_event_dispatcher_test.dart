import "package:pi_plugin/src/api/models/pi_event.dart";
import "package:pi_plugin/src/api/models/pi_session_history_dto.dart";
import "package:pi_plugin/src/repositories/mappers/pi_history_mapper.dart";
import "package:pi_plugin/src/repositories/mappers/pi_message_identity_builder.dart";
import "package:pi_plugin/src/services/pi_event_dispatcher.dart";
import "package:pi_plugin/src/trackers/pi_message_identity_tracker.dart";
import "package:pi_plugin/src/trackers/pi_tool_tracker.dart";
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

  test("user message finals equal cold replay", () {
    final raw = {
      "role": "user",
      "content": [
        {"type": "text", "text": "Hello from another surface"},
      ],
      "timestamp": 99,
    };

    final live = dispatcher.map(sessionId: sessionId, event: _event("message_end", {"message": raw}));
    final replay = history
        .map(
          sessionId: sessionId,
          entries: [
            PiSessionEntryDto.message(
              id: "user",
              parentId: null,
              timestamp: DateTime.utc(2026),
              message: PiAgentMessageDto.fromJson(raw),
            ),
          ],
          leafId: "user",
          identities: PiMessageIdentityBuilder(pluginId: "pi", sessionId: sessionId),
        )
        .single;

    expect((live.first as BridgeSseMessageUpdated).info, replay.info.toJson());
    expect(live.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part), replay.parts);
  });

  test("top-level custom entries preserve hidden ordinals and visible replay parity", () {
    final hidden = {
      "type": "custom_message",
      "id": "hidden",
      "parentId": null,
      "timestamp": "2026-01-01T00:00:00.000Z",
      "content": [
        {"type": "text", "text": "hidden"},
      ],
      "display": false,
    };
    final visible = {
      "type": "custom_message",
      "id": "visible",
      "parentId": "hidden",
      "timestamp": "2026-01-01T00:00:01.000Z",
      "content": [
        {"type": "text", "text": "visible"},
      ],
      "display": true,
    };

    expect(dispatcher.map(sessionId: sessionId, event: _event("entry_appended", {"entry": hidden})), isEmpty);
    final live = dispatcher.map(sessionId: sessionId, event: _event("entry_appended", {"entry": visible}));
    final replay = history
        .map(
          sessionId: sessionId,
          entries: [
            PiSessionEntryDto.fromJson(hidden),
            PiSessionEntryDto.fromJson(visible),
          ],
          leafId: "visible",
          identities: PiMessageIdentityBuilder(pluginId: "pi", sessionId: sessionId),
        )
        .single;

    expect((live.first as BridgeSseMessageUpdated).info, replay.info.toJson());
    expect(live.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part), replay.parts);
  });

  test("authoritative final removes streamed parts before restoring final order", () {
    final start = _assistant(content: const [], timestamp: 101);
    dispatcher.map(sessionId: sessionId, event: _event("message_start", {"message": start}));
    for (final update in [
      {"type": "text_end", "contentIndex": 1, "content": "second"},
      {"type": "thinking_end", "contentIndex": 0, "content": "first"},
    ]) {
      dispatcher.map(
        sessionId: sessionId,
        event: _event("message_update", {"assistantMessageEvent": update}),
      );
    }

    final events = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_end", {
        "message": _assistant(
          content: [
            {"type": "thinking", "thinking": "first"},
            {"type": "text", "text": "second"},
          ],
          timestamp: 101,
        ),
      }),
    );

    expect(
      events.whereType<BridgeSseMessagePartRemoved>().map((event) => event.partID),
      ["pi:session:assistant:101:1-block-2", "pi:session:assistant:101:1-block-1"],
    );
    expect(
      events.whereType<BridgeSseMessagePartUpdated>().map((event) => event.part.id),
      ["pi:session:assistant:101:1-block-1", "pi:session:assistant:101:1-block-2"],
    );
  });

  test("empty successful final removes its provisional message", () {
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_start", {"message": _assistant(content: const [], timestamp: 102)}),
    );
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_update", {
        "assistantMessageEvent": {"type": "text_end", "contentIndex": 0, "content": "discard"},
      }),
    );

    final events = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_end", {"message": _assistant(content: const [], timestamp: 102)}),
    );

    expect(events.whereType<BridgeSseMessageUpdated>(), isEmpty);
    expect(events.whereType<BridgeSseMessageRemoved>().single.messageID, "pi:session:assistant:102:1");
  });

  test("malformed assistant final removes its provisional message", () {
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_start", {"message": _assistant(content: const [], timestamp: 103)}),
    );
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_update", {
        "assistantMessageEvent": {
          "type": "toolcall_end",
          "contentIndex": 0,
          "toolCall": {"id": "orphan", "name": "read", "arguments": <String, Object?>{}},
        },
      }),
    );

    final events = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_end", {
        "message": {"role": "assistant", "content": 123, "timestamp": 103},
      }),
    );

    expect(events.whereType<BridgeSseMessageRemoved>().single.messageID, "pi:session:assistant:103:1");
    expect(
      dispatcher.map(
        sessionId: sessionId,
        event: _event("tool_execution_start", {"toolCallId": "orphan", "toolName": "read"}),
      ),
      isEmpty,
    );
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
    expect(failed.whereType<BridgeSseSessionDiff>(), hasLength(1));
  });

  test("tool-call discriminator is enforced below the dispatcher", () {
    dispatcher.map(
      sessionId: sessionId,
      event: _event("message_start", {"message": _assistant(content: const [], timestamp: 4)}),
    );
    final events = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_update", {
        "assistantMessageEvent": {
          "type": "toolcall_end",
          "contentIndex": 0,
          "toolCall": {"type": "text", "id": "call", "name": "read"},
        },
      }),
    );

    expect(events.whereType<BridgeSseMessagePartUpdated>().single.part.tool, "read");
  });

  test("direct bash final maps to the replay-equivalent tool card", () {
    final events = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_end", {
        "message": {
          "role": "bashExecution",
          "command": "pwd",
          "output": "/project\n",
          "exitCode": 0,
          "cancelled": false,
          "truncated": false,
          "timestamp": 5,
        },
      }),
    );

    expect(events.whereType<BridgeSseMessageUpdated>().single.info["id"] as String, contains(":bashExecution:5:1"));
    final part = events.whereType<BridgeSseMessagePartUpdated>().single.part;
    expect(part.tool, "bash");
    expect(part.state?.title, "pwd");
    expect(part.state?.output, "/project\n");
  });

  test("visible custom final maps to the replay-equivalent text message", () {
    expect(
      dispatcher.map(
        sessionId: sessionId,
        event: _event("message_end", {
          "message": {
            "role": "custom",
            "content": [
              {"type": "text", "text": "hidden"},
            ],
            "display": false,
            "timestamp": 6,
          },
        }),
      ),
      isEmpty,
    );
    final events = dispatcher.map(
      sessionId: sessionId,
      event: _event("message_end", {
        "message": {
          "role": "custom",
          "content": [
            {"type": "text", "text": "Extension result"},
          ],
          "display": true,
          "timestamp": 6,
        },
      }),
    );

    expect(events.whereType<BridgeSseMessageUpdated>().single.info["id"], "pi:session:custom:6:2");
    expect(events.whereType<BridgeSseMessagePartUpdated>().single.part.text, "Extension result");
  });

  test("retry, compaction, and only agent_settled produce status lifecycle", () {
    final retry = dispatcher.map(
      sessionId: sessionId,
      event: _event("auto_retry_start", {"attempt": 2, "delayMs": 500}),
      now: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final autoRetryResumed = dispatcher.map(
      sessionId: sessionId,
      event: _event("auto_retry_end", {"success": true, "attempt": 2}),
    );
    final summarizationResumed = dispatcher.map(
      sessionId: sessionId,
      event: _event("summarization_retry_attempt_start", {"source": "branchSummary"}),
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
    expect((autoRetryResumed.single as BridgeSseSessionStatus).status, {"runtimeType": "busy"});
    expect((summarizationResumed.single as BridgeSseSessionStatus).status, {"runtimeType": "busy"});
    expect(compacted.whereType<BridgeSseSessionCompacted>(), hasLength(1));
    expect(compacted.whereType<BridgeSseMessagePartUpdated>().single.part.state?.title, "Context compacted");
    expect(settled.whereType<BridgeSseSessionIdle>(), hasLength(1));
  });

  test("recovering compaction failures stay local while Pi retries", () {
    final events = dispatcher.map(
      sessionId: sessionId,
      event: _event("compaction_end", {
        "reason": "overflow",
        "errorMessage": "provider detail",
        "aborted": false,
        "willRetry": true,
      }),
    );

    expect(events.whereType<BridgeSseSessionError>(), isEmpty);
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

  test("history hydration advances live identities and reconciles provisional parts", () {
    final hydrated = _assistant(
      content: [
        {"type": "text", "text": "final"},
      ],
      timestamp: 10,
    );
    identities.hydrate(
      sessionId: sessionId,
      map: (identityBuilder) => history.map(
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
        identities: identityBuilder,
      ),
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

    expect(finalized.whereType<BridgeSseMessageUpdated>().single.info["id"], "pi:session:assistant:10:2");
    expect(finalized.whereType<BridgeSseMessagePartRemoved>().single.partID, "pi:session:assistant:10:2-block-1");
    expect(
      compacted.whereType<BridgeSseMessageUpdated>().single.info["id"],
      "pi:session:compaction:compaction:2",
    );
  });

  test("failed identity hydration preserves the live ordinal cursor", () {
    final builder = identities.forSession(sessionId: sessionId);
    expect(builder.next(role: PiMessageIdentityRole.assistant, timestamp: 7), "pi:session:assistant:7:1");

    expect(
      () => identities.hydrate<void>(
        sessionId: sessionId,
        map: (candidate) {
          candidate.next(role: PiMessageIdentityRole.assistant, timestamp: 7);
          throw StateError("mapping failed");
        },
      ),
      throwsStateError,
    );
    expect(builder.next(role: PiMessageIdentityRole.assistant, timestamp: 7), "pi:session:assistant:7:2");
  });

  test("identity hydration merges allocations made after the read begins", () {
    final builder = identities.forSession(sessionId: sessionId);
    expect(builder.next(role: PiMessageIdentityRole.assistant, timestamp: 8), "pi:session:assistant:8:1");
    identities.hydrate<void>(
      sessionId: sessionId,
      map: (candidate) {
        expect(builder.next(role: PiMessageIdentityRole.assistant, timestamp: 8), "pi:session:assistant:8:2");
        expect(candidate.next(role: PiMessageIdentityRole.assistant, timestamp: 8), "pi:session:assistant:8:1");
      },
    );

    expect(builder.next(role: PiMessageIdentityRole.assistant, timestamp: 8), "pi:session:assistant:8:3");
  });

  test("identity hydration drops ordinals from an abandoned active branch", () {
    final builder = identities.forSession(sessionId: sessionId);
    identities.hydrate<void>(
      sessionId: sessionId,
      map: (candidate) {
        candidate
          ..nextCompaction()
          ..nextCompaction();
      },
    );
    expect(builder.nextCompaction(), "pi:session:compaction:compaction:3");

    identities.hydrate<void>(
      sessionId: sessionId,
      map: (candidate) {
        candidate.nextCompaction();
      },
    );

    expect(builder.nextCompaction(), "pi:session:compaction:compaction:2");
  });

  test("older overlapping hydration cannot inflate or replace a newer result", () {
    final builder = identities.forSession(sessionId: sessionId);
    final older = identities.beginHydration(sessionId: sessionId);
    final newer = identities.beginHydration(sessionId: sessionId);
    newer.complete<void>(map: (candidate) => candidate.nextCompaction());
    older.complete<void>(
      map: (candidate) {
        candidate
          ..nextCompaction()
          ..nextCompaction();
      },
    );

    expect(builder.nextCompaction(), "pi:session:compaction:compaction:2");
  });

  test("hydration does not recount a live allocation already in replay", () {
    final builder = identities.forSession(sessionId: sessionId);
    builder.nextCompaction();
    final hydration = identities.beginHydration(sessionId: sessionId);
    builder.nextCompaction();
    hydration.complete<void>(
      map: (candidate) {
        candidate
          ..nextCompaction()
          ..nextCompaction();
      },
    );

    expect(builder.nextCompaction(), "pi:session:compaction:compaction:3");
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
