import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("history paginates oldest page first and preserves message ids", () async {
    final api = _HistoryApi([
      DeepSeekPaginatedHistoryResponseDto(
        updates: [_update("s1", "user_message_chunk", "user-later", "later")],
        nextBeforeSeq: 10,
      ),
      DeepSeekTerminalHistoryResponseDto(
        updates: [
          _update("s1", "user_message_chunk", "user-initial", "initial"),
          _update("s1", "agent_message_chunk", "assistant-reply", "reply"),
        ],
      ),
    ]);
    final repository = _repository(api: api, childSessions: AcpChildSessionTracker());
    final messages = await repository.getMessages(
      client: _unusedClient(),
      sessionId: "s1",
    );

    expect(api.cursors, [null, 10]);
    expect(messages.map((message) => message.info.id), [
      "user-initial",
      "s1-massistant-reply-assistant",
      "user-later",
    ]);
    expect(messages.expand((message) => message.parts).whereType<PluginMessagePartText>().map((part) => part.text), [
      "initial",
      "reply",
      "later",
    ]);
  });

  test("history rejects a non-progressing cursor with preserved cause", () async {
    final repository = _repository(
      api: _HistoryApi([
        const DeepSeekPaginatedHistoryResponseDto(updates: [], nextBeforeSeq: 10),
        const DeepSeekPaginatedHistoryResponseDto(updates: [], nextBeforeSeq: 10),
      ]),
      childSessions: AcpChildSessionTracker(),
    );

    await expectLater(
      repository.getMessages(client: _unusedClient(), sessionId: "s1"),
      throwsA(
        isA<PluginOperationException>()
            .having((error) => error.operation, "operation", DeepSeekAcpApi.historyMethod)
            .having((error) => error.cause, "cause", isA<FormatException>()),
      ),
    );
  });

  test("history preserves an empty user envelope when there are no parts to align", () async {
    final tracker = AcpChildSessionTracker();
    final repository = _repository(
      api: _HistoryApi([
        DeepSeekTerminalHistoryResponseDto(updates: [_update("s1", "user_message_chunk", "user-empty", "")]),
      ]),
      childSessions: tracker,
    );

    final message = (await repository.getMessages(client: _unusedClient(), sessionId: "s1")).single;
    expect(message.info.id, "user-empty");
    expect(message.parts, isEmpty);
    await tracker.dispose();
  });

  test("history replaces a running delegation tool with one child-linked subtask", () async {
    final tracker = AcpChildSessionTracker();
    final repository = _repository(
      api: _HistoryApi([
        DeepSeekTerminalHistoryResponseDto(
          updates: [
            _subagentUpdate(
              sessionId: "s1",
              childSessionId: "child-1",
              sessionUpdate: "tool_call",
              ended: null,
            ),
          ],
        ),
      ]),
      childSessions: tracker,
    );

    final messages = await repository.getMessages(
      client: _unusedClient(),
      sessionId: "s1",
    );
    final tile = messages.single.parts.single as PluginMessagePartSubtask;
    expect(tile.id, "s1-subagent-child-1-subtask");
    expect(tile.sessionID, "s1");
    expect(tile.messageID, "s1-subagent-child-1");
    expect(messages.single.info.id, tile.messageID);
    expect(tile.prompt, "Inspect the synthetic module");
    expect(tile.description, "Research child");
    expect(tile.childSessionID, "child-1");
    expect(tile.taskState?.status, PluginToolStatus.running);
    expect(tracker.childStatuses, isEmpty, reason: "history replay is isolated from live lifecycle state");
    await tracker.dispose();
  });

  test("history preserves ordered unique ordinary runs around multiple child tiles", () async {
    final tracker = AcpChildSessionTracker();
    final repository = _repository(
      api: _HistoryApi([
        DeepSeekTerminalHistoryResponseDto(
          updates: [
            _update("s1", "agent_message_chunk", "assistant", "before"),
            _subagentUpdate(
              sessionId: "s1",
              childSessionId: "child-1",
              sessionUpdate: "tool_call",
              ended: null,
            ),
            _update("s1", "agent_message_chunk", "assistant", "middle"),
            _subagentUpdate(
              sessionId: "s1",
              childSessionId: "child-2",
              sessionUpdate: "tool_call",
              ended: null,
            ),
            _update("s1", "agent_message_chunk", "assistant", "after"),
          ],
        ),
      ]),
      childSessions: tracker,
    );

    final messages = await repository.getMessages(
      client: _unusedClient(),
      sessionId: "s1",
    );

    expect(messages, hasLength(5));
    expect(messages.map((message) => message.info.id), [
      "s1-massistant-assistant",
      "s1-subagent-child-1",
      "s1-massistant-assistant-deepseek-replay-run-2",
      "s1-subagent-child-2",
      "s1-massistant-assistant-deepseek-replay-run-3",
    ]);
    expect(messages.map((message) => message.info.id).toSet(), hasLength(5));
    expect(messages.expand((message) => message.parts).map((part) => part.id).toSet(), hasLength(5));
    for (final message in messages) {
      for (final part in message.parts) {
        expect(part.messageID, message.info.id);
        expect(part.sessionID, message.info.sessionID);
      }
    }
    expect((messages[0].parts.single as PluginMessagePartText).text, "before");
    expect(messages[1].parts.single, isA<PluginMessagePartSubtask>());
    expect((messages[2].parts.single as PluginMessagePartText).text, "middle");
    expect(messages[3].parts.single, isA<PluginMessagePartSubtask>());
    expect((messages[4].parts.single as PluginMessagePartText).text, "after");
    await tracker.dispose();
  });

  test("a running replay and later live end address the same child tile", () async {
    final tracker = AcpChildSessionTracker();
    final liveStart = tracker.spawn(
      sessionId: "s1",
      spawn: const AcpChildSpawn(
        childSessionId: "child-1",
        description: "Research child",
        agent: DeepSeekIdentity.id,
        prompt: "Inspect the synthetic module",
        isBackground: true,
      ),
      directory: "/project",
    )!;
    final liveTile = liveStart.events.whereType<BridgeSseMessagePartUpdated>().single.part;
    final repository = _repository(
      api: _HistoryApi([
        DeepSeekTerminalHistoryResponseDto(
          updates: [
            _subagentUpdate(
              sessionId: "s1",
              childSessionId: "child-1",
              sessionUpdate: "tool_call",
              ended: null,
            ),
          ],
        ),
      ]),
      childSessions: tracker,
    );

    final messages = await repository.getMessages(
      client: _unusedClient(),
      sessionId: "s1",
    );
    final replayTile = messages.single.parts.single;
    final liveEnd = tracker.finish(
      childSessionId: "child-1",
      status: PluginToolStatus.completed,
      output: "Done",
      error: null,
    );
    final endedTile = liveEnd.whereType<BridgeSseMessagePartUpdated>().single.part;

    expect(replayTile.id, liveTile.id);
    expect(replayTile.messageID, liveTile.messageID);
    expect(endedTile.id, replayTile.id);
    expect(endedTile.messageID, replayTile.messageID);
    await tracker.dispose();
  });

  test("nested replay stays in its direct parent's history when live tracking is empty", () async {
    final tracker = AcpChildSessionTracker();
    final repository = _repository(
      api: _HistoryApi([
        DeepSeekTerminalHistoryResponseDto(
          updates: [
            _subagentUpdate(
              sessionId: "child",
              childSessionId: "grandchild",
              sessionUpdate: "tool_call",
              ended: null,
            ),
          ],
        ),
      ]),
      childSessions: tracker,
    );

    final messages = await repository.getMessages(
      client: _unusedClient(),
      sessionId: "child",
    );
    final tile = messages.single.parts.single as PluginMessagePartSubtask;
    expect(messages.single.info.id, "child-subagent-grandchild");
    expect(messages.single.info.sessionID, "child");
    expect(tile.id, "child-subagent-grandchild-subtask");
    expect(tile.sessionID, "child");
    await tracker.dispose();
  });

  test("unbound failed delegation and ordinary tools retain their source identities", () async {
    final tracker = AcpChildSessionTracker();
    final repository = _repository(
      api: _HistoryApi([
        DeepSeekTerminalHistoryResponseDto(
          updates: [
            _subagentUpdate(
              sessionId: "s1",
              childSessionId: null,
              sessionUpdate: "tool_call_update",
              ended: const DeepSeekSubagentReplayEndedDto(
                stopReason: DeepSeekSubagentStopReason.error,
                summary: "Startup failed",
              ),
            ),
            const DeepSeekSessionUpdateEnvelopeDto(
              sessionId: "s1",
              metadata: null,
              update: {
                "sessionUpdate": "tool_call",
                "toolCallId": "ordinary",
                "title": "read_file",
                "status": "completed",
              },
            ),
          ],
        ),
      ]),
      childSessions: tracker,
    );

    final messages = await repository.getMessages(client: _unusedClient(), sessionId: "s1");
    expect(messages.map((message) => message.info.id), ["s1-h0-assistant", "s1-h1-assistant"]);
    final tile = messages.first.parts.single as PluginMessagePartSubtask;
    expect(tile.id, "s1-h0-assistant-tool-call-failed");
    expect(tile.childSessionID, isNull);
    expect(tile.taskState?.status, PluginToolStatus.error);
    expect(tile.taskState?.error, "Startup failed");
    final ordinary = messages.last.parts.single as PluginMessagePartTool;
    expect(ordinary.id, "s1-h1-assistant-tool-ordinary");
    expect(ordinary.state.status, PluginToolStatus.completed);
    for (final message in messages) {
      expect(message.parts.map((part) => part.messageID), everyElement(message.info.id));
    }
    expect(tracker.childStatuses, isEmpty);
    await tracker.dispose();
  });

  test("latest replay metadata across reverse-paginated history settles the same tile", () async {
    final tracker = AcpChildSessionTracker();
    final repository = _repository(
      api: _HistoryApi([
        DeepSeekPaginatedHistoryResponseDto(
          nextBeforeSeq: 10,
          updates: [
            _subagentUpdate(
              sessionId: "s1",
              childSessionId: "child-1",
              sessionUpdate: "tool_call_update",
              ended: const DeepSeekSubagentReplayEndedDto(
                stopReason: DeepSeekSubagentStopReason.completed,
                summary: "Done",
              ),
            ),
          ],
        ),
        DeepSeekTerminalHistoryResponseDto(
          updates: [
            _subagentUpdate(
              sessionId: "s1",
              childSessionId: "child-1",
              sessionUpdate: "tool_call",
              ended: null,
            ),
          ],
        ),
      ]),
      childSessions: tracker,
    );

    final messages = await repository.getMessages(
      client: _unusedClient(),
      sessionId: "s1",
    );
    expect(messages.single.parts, hasLength(1));
    final tile = messages.single.parts.single as PluginMessagePartSubtask;
    expect(tile.id, "s1-subagent-child-1-subtask");
    expect(tile.taskState?.status, PluginToolStatus.completed);
    expect(tile.taskState?.output, "Done");
    expect(tracker.childStatuses, isEmpty);
    await tracker.dispose();
  });
}

DeepSeekHistoryRepository _repository({
  required DeepSeekAcpApi api,
  required AcpChildSessionTracker childSessions,
}) {
  const subagentMapper = DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id);
  return DeepSeekHistoryRepository(
    api: api,
    messageTimeParser: const DeepSeekMessageTimeParser(),
    subagentMapper: subagentMapper,
    eventMapper: DeepSeekEventMapper(
      messageTimeParser: const DeepSeekMessageTimeParser(),
      subagentMapper: subagentMapper,
      launchDirectory: "/project",
      pluginId: DeepSeekIdentity.id,
      configurationTracker: AcpSessionConfigurationTracker(),
      childSessions: childSessions,
      api: api,
      delegationTracker: DeepSeekDelegationTracker(),
    ),
    pluginId: DeepSeekIdentity.id,
  );
}

AcpStdioClient _unusedClient() => AcpStdioClient(
  launchSpec: const AcpLaunchSpec(command: "unused", args: [], cwd: "/", environment: {}),
  processFactory: (_) => throw UnimplementedError(),
);

DeepSeekSessionUpdateEnvelopeDto _update(String sessionId, String kind, String messageId, String text) =>
    DeepSeekSessionUpdateEnvelopeDto(
      metadata: null,
      sessionId: sessionId,
      update: {
        "sessionUpdate": kind,
        "messageId": messageId,
        "content": {"type": "text", "text": text},
      },
    );

DeepSeekSessionUpdateEnvelopeDto _subagentUpdate({
  required String sessionId,
  required String? childSessionId,
  required String sessionUpdate,
  required DeepSeekSubagentReplayEndedDto? ended,
}) => DeepSeekSessionUpdateEnvelopeDto(
  metadata: DeepSeekEnvelopeMetadataDto.fromJson({
    DeepSeekAcpApi.initializeMetadataKey: DeepSeekEnvelopeDeepSeekMetadataDto(
      messageCreatedAt: 1,
      subagent: DeepSeekSubagentReplayDto(
        prompt: "Inspect the synthetic module",
        label: "Research child",
        mode: DeepSeekSubagentMode.background,
        childSessionId: childSessionId,
        ended: ended,
      ),
    ).toJson(),
  }),
  sessionId: sessionId,
  update: {
    "sessionUpdate": sessionUpdate,
    "toolCallId": "call-${childSessionId ?? 'failed'}",
    "title": "subagent",
    "status": ended == null ? "in_progress" : "completed",
  },
);

class _HistoryApi(final List<DeepSeekHistoryResponseDto> responses) extends DeepSeekAcpApi {
  this : super(pluginId: DeepSeekIdentity.id);

  final List<int?> cursors = [];

  @override
  Future<DeepSeekHistoryResponseDto> history({
    required AcpStdioClient client,
    required String sessionId,
    required int? beforeSeq,
    required int maxMessages,
    required Duration timeout,
  }) async {
    cursors.add(beforeSeq);
    return responses.removeAt(0);
  }
}
