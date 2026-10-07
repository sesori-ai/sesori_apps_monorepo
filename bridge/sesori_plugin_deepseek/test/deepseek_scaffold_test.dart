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
      delegationTracker: DeepSeekDelegationTracker(),
      compactionTracker: DeepSeekCompactionTracker(clock: const ServerClock()),
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
    expect(map({"kind": "retry", "attempt": 1, "limit": 3}), isEmpty);
    expect(map({"kind": "future_status"}), isEmpty);
  });
  group("compaction", () {
    late _FakeClock clock;
    late DeepSeekEventMapper mapper;
    setUp(() {
      clock = _FakeClock(DateTime.fromMillisecondsSinceEpoch(5000));
      mapper = DeepSeekEventMapper(
        launchDirectory: "/project",
        pluginId: DeepSeekIdentity.id,
        configurationTracker: AcpSessionConfigurationTracker(),
        childSessions: AcpChildSessionTracker(),
        messageTimeParser: const DeepSeekMessageTimeParser(),
        subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
        delegationTracker: DeepSeekDelegationTracker(),
        compactionTracker: DeepSeekCompactionTracker(clock: clock),
        api: const DeepSeekAcpApi(pluginId: DeepSeekIdentity.id),
      );
    });
    List<BridgeSseEvent> status(String kind) => mapper.map(
      AcpNotification(method: DeepSeekAcpApi.sessionStatusMethod, params: {"sessionId": "session-1", "kind": kind}),
    );
    Matcher row({required PluginCompactionState state}) => containsAllInOrder([
      isA<BridgeSseMessageUpdated>().having(
        (event) => event.info,
        "info",
        isA<PluginMessageAssistant>()
            .having((info) => info.id, "id", "session-1-compaction-5000")
            .having((info) => info.sender, "sender", PluginMessageSender.system)
            .having((info) => info.time, "time", const PluginMessageTime(created: 5000, completed: null)),
      ),
      isA<BridgeSseMessagePartUpdated>().having(
        (event) => event.part,
        "part",
        isA<PluginMessagePartCompaction>()
            .having((part) => part.id, "id", "session-1-compaction-5000-part")
            .having((part) => part.compactionState, "compactionState", state),
      ),
    ]);

    test("a start shows the running row, and the completion settles it in place", () {
      final started = status("compaction_started");
      clock.current = DateTime.fromMillisecondsSinceEpoch(9000);
      final repeated = status("compaction_started");
      final completed = status("compaction_completed");

      expect(started, hasLength(2));
      expect(started, row(state: const .running(summary: null)));
      expect(repeated, row(state: const .running(summary: null)));
      expect(completed, hasLength(3));
      expect(completed, row(state: const .completed(summary: null, freedTokens: null, trigger: null)));
      expect(completed.last, isA<BridgeSseSessionCompacted>());
    });

    test("a completion without a start reports only the session event", () {
      expect(status("compaction_completed"), [isA<BridgeSseSessionCompacted>()]);
    });

    test("the next turn drops a compaction that never completed", () {
      status("compaction_started");
      mapper.beginTurn(sessionId: "session-1", messageId: null);

      expect(status("compaction_completed"), [isA<BridgeSseSessionCompacted>()]);
    });
  });
  test("event mapper retains standard ACP turn projection", () {
    final mapper = DeepSeekEventMapper(
      launchDirectory: "/project",
      pluginId: DeepSeekIdentity.id,
      configurationTracker: AcpSessionConfigurationTracker(),
      childSessions: AcpChildSessionTracker(),
      messageTimeParser: const DeepSeekMessageTimeParser(),
      subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
      delegationTracker: DeepSeekDelegationTracker(),
      compactionTracker: DeepSeekCompactionTracker(clock: const ServerClock()),
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

final class _FakeClock(var DateTime current) implements ServerClock {
  @override
  DateTime now() => current;

  @override
  Future<void> delay({required Duration duration}) async {}
}

final class _BufferingStdout() implements Stdout {
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
