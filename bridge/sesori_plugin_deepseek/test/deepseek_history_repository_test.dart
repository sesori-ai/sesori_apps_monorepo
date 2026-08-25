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
    final repository = _repository(api);
    final messages = await repository.getMessages(client: _unusedClient(), sessionId: "s1");

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
      _HistoryApi([
        const DeepSeekPaginatedHistoryResponseDto(updates: [], nextBeforeSeq: 10),
        const DeepSeekPaginatedHistoryResponseDto(updates: [], nextBeforeSeq: 10),
      ]),
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
}

DeepSeekHistoryRepository _repository(DeepSeekAcpApi api) => DeepSeekHistoryRepository(
  api: api,
  eventMapper: DeepSeekEventMapper(
    launchDirectory: "/project",
    pluginId: DeepSeekIdentity.id,
    configurationTracker: AcpSessionConfigurationTracker(),
    api: api,
  ),
  pluginId: DeepSeekIdentity.id,
);

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
