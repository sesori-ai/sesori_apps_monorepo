import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:grok_plugin/src/grok_approval_registry.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

/// Grok's own prompt before a Sesori tool is answered allow-once in place; any
/// other tool, or a session without Sesori's server, still asks the user.
void main() {
  group("GrokApprovalRegistry", () {
    late FakeAcpProcess fake;
    late AcpStdioClient client;
    late List<BridgeSseEvent> emitted;
    late GrokApprovalRegistry registry;

    setUp(() async {
      fake = FakeAcpProcess();
      client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(includeParentEnvironment: true, command: "grok", args: ["agent", "stdio"]),
        processFactory: (_) async => fake,
      );
      await client.connect();
      emitted = [];
      registry = GrokApprovalRegistry(
        client: client,
        emit: emitted.add,
        idGenerator: null,
        activeSessionResolver: () => null,
        holdsSesoriServer: ({required sessionId}) => sessionId == "with-sesori",
      );
      registry.attach(stream: client.serverRequests);
    });

    tearDown(() async {
      await registry.dispose();
      await client.dispose();
      await fake.close();
    });

    // The shape Grok 1.0.30 sends, captured live.
    void requestPermission({
      required int id,
      required String sessionId,
      required String grokTool,
      required Map<String, Object?> rawInput,
    }) {
      fake.emit({
        "jsonrpc": "2.0",
        "id": id,
        "method": "session/request_permission",
        "params": {
          "sessionId": sessionId,
          "toolCall": {
            "toolCallId": "call_$id",
            "kind": "other",
            "title": "title",
            "rawInput": rawInput,
            "_meta": {
              "x.ai/tool": {"version": 1, "name": grokTool, "namespace": "grok_build"},
            },
          },
          "options": [
            {"optionId": "always-allow", "name": "always allow", "kind": "allow_always"},
            {"optionId": "allow-once", "name": "allow once", "kind": "allow_once"},
            {"optionId": "reject-once", "name": "reject once", "kind": "reject_once"},
          ],
        },
      });
    }

    Map<String, Object?> useTool(String toolName) => {"variant": "UseTool", "tool_name": toolName, "tool_input": {}};

    Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 10));

    test("a Sesori tool in a session given Sesori's server is allowed once without asking", () async {
      requestPermission(
        id: 1,
        sessionId: "with-sesori",
        grokTool: "use_tool",
        rawInput: useTool("sesori_bridge__get_task"),
      );
      await pump();

      expect(emitted, isEmpty);
      expect(fake.written.single, {
        "jsonrpc": "2.0",
        "id": 1,
        "result": {
          "outcome": {"outcome": "selected", "optionId": "allow-once"},
        },
      });
    });

    test("other tools and sessions without Sesori's server still ask", () async {
      requestPermission(
        id: 1,
        sessionId: "without",
        grokTool: "use_tool",
        rawInput: useTool("sesori_bridge__get_task"),
      );
      requestPermission(
        id: 2,
        sessionId: "with-sesori",
        grokTool: "use_tool",
        rawInput: useTool("github__create_issue"),
      );
      requestPermission(
        id: 3,
        sessionId: "with-sesori",
        grokTool: "use_tool",
        rawInput: useTool("sesori_bridge__x__y"),
      );
      requestPermission(
        id: 4,
        sessionId: "with-sesori",
        grokTool: "run_terminal_command",
        rawInput: {"command": "sesori_bridge__get_task", "tool_name": "sesori_bridge__get_task"},
      );
      requestPermission(
        id: 5,
        sessionId: "with-sesori",
        grokTool: "use_tool",
        rawInput: {"tool_name": 42},
      );
      await pump();

      expect(fake.written, isEmpty);
      expect(emitted.whereType<BridgeSsePermissionAsked>(), hasLength(5));
    });
  });
}
