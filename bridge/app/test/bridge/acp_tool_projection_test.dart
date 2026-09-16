import "package:acp_plugin/acp_plugin.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:grok_plugin/src/grok_event_mapper.dart";
import "package:sesori_bridge/src/repositories/mappers/plugin_to_shared_mapping.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

AcpEventMapper _mapper({required String harness}) => switch (harness) {
  "antigravity" => AntigravityEventMapper(
    launchDirectory: "/synthetic",
    pluginId: harness,
    configurationTracker: AcpSessionConfigurationTracker(),
    childSessions: AcpChildSessionTracker(),
    protocolMapper: const AntigravityProtocolMapper(),
  ),
  "grok" => GrokEventMapper(
    launchDirectory: "/synthetic",
    pluginId: harness,
    configurationTracker: AcpSessionConfigurationTracker(),
    childSessions: AcpChildSessionTracker(),
  ),
  _ => AcpEventMapper(
    launchDirectory: "/synthetic",
    pluginId: harness,
    configurationTracker: AcpSessionConfigurationTracker(),
    childSessions: AcpChildSessionTracker(),
  ),
};

Map<String, dynamic> _command({required String harness, required String command}) => switch (harness) {
  "antigravity" => {
    "rawInput": {"CommandLine": command},
  },
  _ => {
    "rawInput": {"command": command},
    "_meta": {
      "x.ai/tool": {"name": "run_terminal_command", "kind": "execute"},
    },
  },
};

ToolState _parity({required AcpEventMapper mapper, required List<Map<String, dynamic>> updates}) {
  final replay = AcpReplayCollector(
    sessionId: "s",
    agentId: mapper.pluginId,
    initialUserMessageId: null,
    sessionUpdateNormalizer: mapper.normalizeSessionUpdate,
    shellCommandResolver: mapper.shellCommandForToolUpdate,
    messageIdOverride: null,
    messageTimeResolver: null,
    haltClassifier: null,
    toolPartReplacement: null,
    toolPartSuppression: null,
  );
  MessagePartTool? live;
  for (final update in updates) {
    final params = {
      "sessionId": "s",
      "update": {"toolCallId": "t", ...update},
    };
    replay.consume(params);
    live =
        mapper
                .map(AcpNotification(method: AcpMethods.sessionUpdate, params: params))
                .whereType<BridgeSseMessagePartUpdated>()
                .last
                .part
                .toShared(sessionId: "s")
            as MessagePartTool;
    final recorded =
        replay
                .build()
                .expand((message) => message.parts)
                .whereType<PluginMessagePartTool>()
                .single
                .toShared(sessionId: "s")
            as MessagePartTool;
    expect(recorded.state, live.state);
  }
  return live!.state;
}

void main() {
  for (final harness in ["antigravity", "grok"]) {
    for (final status in ["completed", "failed"]) {
      test("$harness live/replay retains updated command with $status output and image", () {
        final state = _parity(
          mapper: _mapper(harness: harness),
          updates: [
            {
              "sessionUpdate": "tool_call",
              "title": "not command authority",
              ..._command(harness: harness, command: "echo old"),
            },
            {"sessionUpdate": "tool_call_update", ..._command(harness: harness, command: "echo new")},
            {
              "sessionUpdate": "tool_call_update",
              "status": status,
              "content": [
                {
                  "type": "content",
                  "content": {"type": "text", "text": "result"},
                },
                {
                  "type": "content",
                  "content": {"type": "image", "mimeType": "image/png", "data": "aGVsbG8="},
                },
              ],
            },
          ],
        );
        expect(state.shellCommand, "echo new");
        expect(state.title, state.shellCommand);
        expect(state.output, "result");
        expect(state.error, status == "failed" ? "result" : null);
        expect(state.status, status == "failed" ? ToolStatus.error : ToolStatus.completed);
        expect(state.attachments, hasLength(1));
      });
    }
    test("$harness reordered initial call does not overwrite newer command or status", () {
      final state = _parity(
        mapper: _mapper(harness: harness),
        updates: [
          {"sessionUpdate": "tool_call_update", "status": "completed", ..._command(harness: harness, command: "new")},
          {"sessionUpdate": "tool_call", "status": "pending", ..._command(harness: harness, command: "old")},
        ],
      );
      expect(state.shellCommand, "new");
      expect(state.status, ToolStatus.completed);
    });
  }
  for (final alias in ["CommandLine", "command_line", "commandLine", "command"]) {
    test("Antigravity native $alias survives projection and exit-only deltas", () {
      final state = _parity(
        mapper: _mapper(harness: "antigravity"),
        updates: [
          {
            "sessionUpdate": "tool_call",
            "rawInput": {alias: "  true  "},
          },
          {
            "sessionUpdate": "tool_call_update",
            "status": "completed",
            "rawOutput": {"stdout": "done", "exitCode": 2},
          },
          {
            "sessionUpdate": "tool_call_update",
            "rawOutput": {"exitCode": 2},
          },
        ],
      );
      expect(state.shellCommand, "true");
      expect(state.output, contains("done"));
      expect(state.output, contains("Process exit code: 2"));
      expect(state.status, ToolStatus.completed, reason: "native nonzero exit does not rewrite ACP status");
    });
  }
  for (final harness in ["acp", "grok"]) {
    for (final evidence in <Map<String, dynamic>>[
      {"title": "run_terminal_command"},
      {"kind": "execute"},
      {
        "title": "run_terminal_command",
        "kind": "execute",
        "rawInput": {"command": "private"},
      },
      {
        "rawInput": {"command": "private"},
        "_meta": {
          "x.ai/tool": {"name": "read", "kind": "execute"},
        },
      },
      {
        "_meta": {
          "x.ai/tool": {"name": "run_terminal_command", "kind": "execute"},
        },
      },
    ]) {
      test("$harness rejects unverified evidence $evidence", () {
        final state = _parity(
          mapper: _mapper(harness: harness),
          updates: [
            {"sessionUpdate": "tool_call", ...evidence},
            {"sessionUpdate": "tool_call_update", "status": "failed", "rawOutput": "private"},
          ],
        );
        expect(state.shellCommand, isNull);
        // The agent's title stays a display label; it never becomes a command.
        // A title-only call drops it because it already names the tool.
        expect(state.title, evidence.containsKey("kind") ? evidence["title"] : null);
        expect(state.output, isNull);
        expect(state.error, isNull);
        expect(state.status, ToolStatus.error);
      });
    }
  }
}
