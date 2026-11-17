import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/src/api/deepseek_acp_api.dart";
import "package:deepseek_plugin/src/deepseek_event_mapper.dart";
import "package:deepseek_plugin/src/deepseek_message_time_parser.dart";
import "package:deepseek_plugin/src/repositories/mappers/deepseek_subagent_mapper.dart";
import "package:deepseek_plugin/src/repositories/trackers/deepseek_compaction_tracker.dart";
import "package:deepseek_plugin/src/repositories/trackers/deepseek_delegation_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const refusal = "DeepSeek refused to answer under its content safety review: image 1 was blocked";

  DeepSeekEventMapper mapper() => DeepSeekEventMapper(
    launchDirectory: "/repo",
    pluginId: "deepseek",
    configurationTracker: AcpSessionConfigurationTracker(),
    childSessions: AcpChildSessionTracker(),
    api: const DeepSeekAcpApi(pluginId: "deepseek"),
    messageTimeParser: const DeepSeekMessageTimeParser(),
    subagentMapper: const DeepSeekSubagentMapper(agentId: "deepseek"),
    delegationTracker: DeepSeekDelegationTracker(),
    compactionTracker: DeepSeekCompactionTracker(clock: const ServerClock()),
  );

  AcpNotification chunk({required String messageId, required String text}) => AcpNotification(
    method: AcpMethods.sessionUpdate,
    params: {
      "sessionId": "s1",
      "update": {
        "sessionUpdate": "agent_message_chunk",
        "messageId": messageId,
        "content": {"type": "text", "text": text},
      },
    },
  );

  test("a live content refusal is one failed-turn notice with DeepSeek's explanation", () {
    final events = mapper().map(chunk(messageId: "deepseek-refusal-abc", text: refusal));

    final notice = events.whereType<BridgeSseMessageUpdated>().single.info.toJson();
    expect(notice["role"], "error");
    expect(notice["errorName"], "deepseek_content_refused");
    expect(notice["errorMessage"], refusal);
    expect(events.whereType<BridgeSseMessagePartDelta>(), isEmpty);
  });

  test("an ordinary reply in the refusal wording stays assistant text", () {
    final events = mapper().map(chunk(messageId: "deepseek-assistant-abc", text: refusal));

    expect(events.whereType<BridgeSseMessageUpdated>().single.info.toJson()["role"], "assistant");
    expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, refusal);
  });
}
