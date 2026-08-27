import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/src/api/deepseek_acp_api.dart";
import "package:deepseek_plugin/src/deepseek_event_mapper.dart";
import "package:deepseek_plugin/src/deepseek_message_time_parser.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const parser = DeepSeekMessageTimeParser();
  final mapper = DeepSeekEventMapper(
    launchDirectory: "/repo",
    pluginId: "deepseek",
    configurationTracker: AcpSessionConfigurationTracker(),
    api: const DeepSeekAcpApi(pluginId: "deepseek"),
    messageTimeParser: parser,
  );

  AcpNotification notification(Map<String, dynamic> update, [int? createdAt]) => AcpNotification(
    method: AcpMethods.sessionUpdate,
    params: {
      "sessionId": "s1",
      "update": update,
      if (createdAt != null)
        "_meta": {
          "sesori.ai/deepseek": {"messageCreatedAt": createdAt},
        },
    },
  );

  int? liveCreated(List<BridgeSseEvent> events) =>
      (events.whereType<BridgeSseMessageUpdated>().single.info["time"] as Map?)?["created"] as int?;

  test("live assistant and tool envelopes use DeepSeek metadata time", () {
    expect(
      liveCreated(mapper.map(notification({
        "sessionUpdate": "agent_message_chunk",
        "messageId": "a1",
        "content": {"type": "text", "text": "hello"},
      }, 10))),
      10,
    );
    expect(
      liveCreated(mapper.map(notification({
        "sessionUpdate": "tool_call",
        "toolCallId": "t1",
        "kind": "read",
      }, 20))),
      20,
    );
  });

  test("local initial and queued users use accepted creation times", () {
    expect(
      liveCreated(mapper.mapInitialPrompt(
        sessionId: "s1",
        parts: const [PluginPromptPart.text(text: "initial")],
        createdAtMs: 30,
      )),
      30,
    );
    expect(
      liveCreated(mapper.mapSentPrompt(
        sessionId: "s1",
        messageId: "queued-user",
        promptId: "queued",
        parts: const [PluginPromptPart.text(text: "queued")],
        createdAtMs: 40,
      )),
      40,
    );
  });

  test("replay retains earliest user, assistant, and tool creation times", () {
    final collector = AcpReplayCollector(
      sessionId: "s1",
      agentId: "deepseek",
      modelId: null,
      providerId: null,
      initialUserMessageId: null,
      messageIdOverride: ({required acpMessageId}) => acpMessageId,
      messageTimeResolver: ({required params}) => parser.parse(params),
      haltClassifier: null,
    );
    collector.consume(notification({
      "sessionUpdate": "user_message_chunk",
      "messageId": "u1",
      "content": {"type": "text", "text": "user"},
    }, 30).params);
    collector.consume(notification({
      "sessionUpdate": "agent_message_chunk",
      "messageId": "a1",
      "content": {"type": "text", "text": "first"},
    }, 20).params);
    collector.consume(notification({
      "sessionUpdate": "agent_message_chunk",
      "messageId": "a1",
      "content": {"type": "text", "text": "later"},
    }, 50).params);
    collector.consume(notification({
      "sessionUpdate": "tool_call",
      "toolCallId": "t1",
      "kind": "read",
    }, 10).params);
    collector.consume(notification({
      "sessionUpdate": "tool_call_update",
      "toolCallId": "t1",
      "status": "completed",
    }, 60).params);

    final messages = collector.build();
    expect(messages.map((message) => message.info.time?.created), [30, 10]);
  });

  test("replay halt retains draft time and omitted metadata remains null", () {
    AcpReplayCollector collector(AcpHaltNotice? Function({required String text})? classifier) => AcpReplayCollector(
      sessionId: "s1",
      agentId: "deepseek",
      modelId: null,
      providerId: null,
      initialUserMessageId: null,
      messageIdOverride: null,
      messageTimeResolver: ({required params}) => parser.parse(params),
      haltClassifier: classifier,
    );
    final halted = collector(({required text}) => const AcpHaltNotice(errorName: "halt"));
    halted.consume(notification({
      "sessionUpdate": "agent_message_chunk",
      "content": {"type": "text", "text": "halt"},
    }, 70).params);
    expect(halted.build().single.info.time?.created, 70);
    expect(halted.build().single.info.toJson()["errorName"], "halt");

    final old = collector(null)..consume(notification({
      "sessionUpdate": "agent_message_chunk",
      "content": {"type": "text", "text": "old"},
    }).params);
    expect(old.build().single.info.time, isNull);
  });
}
