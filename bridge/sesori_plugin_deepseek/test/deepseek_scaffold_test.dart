import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("identity and launch contract are exact", () {
    final spec = DeepSeekBinary.launchSpec(
      binary: "/runtime/deepseek",
      cwd: "/project",
      stateDirectory: "/state",
      environment: const {"TOKEN": "secret", "DSH_TELEMETRY_MODE": "enabled"},
    );
    expect([DeepSeekIdentity.id, DeepSeekIdentity.displayName], ["deepseek", "DeepSeek"]);
    expect(
      [spec.command, spec.args, spec.cwd],
      [
        "/runtime/deepseek",
        ["serve", "--state-dir", "/state"],
        "/project",
      ],
    );
    expect(spec.environment, {"TOKEN": "secret", "DSH_TELEMETRY_MODE": "off"});
  });
  test("event mapper surfaces representable DeepSeek statuses", () async {
    final mapper = DeepSeekEventMapper(
      launchDirectory: "/project",
      pluginId: DeepSeekIdentity.id,
      configurationTracker: AcpSessionConfigurationTracker(),
      childSessions: AcpChildSessionTracker(),
      messageTimeParser: const DeepSeekMessageTimeParser(),
      subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
      api: const DeepSeekAcpApi(pluginId: DeepSeekIdentity.id),
    );
    List<BridgeSseEvent> map(Map<String, dynamic> params) => mapper.map(
      AcpNotification(
        method: DeepSeekAcpApi.sessionStatusMethod,
        params: {"sessionId": "session-1", ...params},
      ),
    );
    expect(map({"kind": "compaction_completed"}), [isA<BridgeSseSessionCompacted>()]);
    final logs = await _captureWarnings(() async {
      expect(map({"kind": "warning", "message": "DeepSeek compaction failed"}), [isA<BridgeSseSessionError>()]);
    });
    expect(logs, contains("DeepSeek compaction failed"));
    expect(map({"kind": "compaction_started"}), isEmpty);
    expect(map({"kind": "retry", "attempt": 1, "limit": 3}), isEmpty);
    expect(map({"kind": "future_status"}), isEmpty);
  });
  test("event mapper retains standard ACP turn projection", () {
    final mapper = DeepSeekEventMapper(
      launchDirectory: "/project",
      pluginId: DeepSeekIdentity.id,
      configurationTracker: AcpSessionConfigurationTracker(),
      childSessions: AcpChildSessionTracker(),
      messageTimeParser: const DeepSeekMessageTimeParser(),
      subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
      api: const DeepSeekAcpApi(pluginId: DeepSeekIdentity.id),
    )..beginTurn(sessionId: "session-1", messageId: null);
    final events = mapper.map(
      const AcpNotification(
        method: AcpMethods.sessionUpdate,
        params: {
          "sessionId": "session-1",
          "update": {
            "sessionUpdate": "agent_message_chunk",
            "messageId": "assistant-1",
            "content": {"type": "text", "text": "hello"},
          },
        },
      ),
    );
    expect(events.whereType<BridgeSseMessageUpdated>(), hasLength(1));
    expect(events.whereType<BridgeSseMessagePartDelta>().single.delta, "hello");
  });
}

Future<String> _captureWarnings(Future<void> Function() action) async {
  final previousLevel = Log.level;
  final stderr = _BufferingStdout();
  try {
    Log.level = LogLevel.warning;
    await IOOverrides.runZoned(action, stderr: () => stderr);
  } finally {
    Log.level = previousLevel;
  }
  return stderr.text;
}

final class _BufferingStdout() implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
