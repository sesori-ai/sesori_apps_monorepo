import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorApprovalRegistry", () {
    late FakeAcpProcess fake;
    late AcpStdioClient client;
    late List<BridgeSseEvent> emitted;
    late CursorApprovalRegistry registry;

    setUp(() async {
      fake = FakeAcpProcess();
      client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();
      emitted = [];
      registry = CursorApprovalRegistry(client: client, emit: emitted.add);
      registry.attach(client.serverRequests);
    });

    tearDown(() async {
      await registry.dispose();
      await client.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test("cursor/ask_question surfaces as a question with options", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "cursor/ask_question",
        "params": {
          "sessionId": "s1",
          "title": "Choose",
          "questions": [
            {
              "id": "q1",
              "prompt": "Pick one",
              "allowMultiple": false,
              "options": [
                {"id": "o1", "label": "Yes"},
                {"id": "o2", "label": "No"},
              ],
            },
          ],
        },
      });
      await pump();

      final asked = emitted.single as BridgeSseQuestionAsked;
      expect(asked.sessionID, "s1");
      expect(asked.questions.single["question"], "Pick one");
      expect(asked.questions.single["header"], "Choose");

      expect(registry.pendingForSession("s1"), hasLength(1));

      registry.replyQuestion(asked.id, [["Yes"]]);
      final reply = fake.written.last;
      expect(reply["id"], 1);
      final questions = (reply["result"] as Map)["questions"] as List;
      expect((questions.single as Map)["selectedOptionIds"], ["o1"]);
    });

    test("cursor/create_plan surfaces as an accept/reject question", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "cursor/create_plan",
        "params": {"sessionId": "s1", "name": "Plan A", "overview": "Do things"},
      });
      await pump();

      final asked = emitted.single as BridgeSseQuestionAsked;
      expect(asked.questions.single["header"], "Plan A");

      registry.replyQuestion(asked.id, [["Accept"]]);
      final reply = fake.written.last;
      expect((reply["result"] as Map)["accepted"], true);
    });

    test("standard permission requests still work via the base", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 3,
        "method": "session/request_permission",
        "params": {
          "sessionId": "s1",
          "toolCall": {"kind": "execute", "title": "Run"},
          "options": [
            {"optionId": "ok", "kind": "allow_once"},
          ],
        },
      });
      await pump();
      expect(emitted.single, isA<BridgeSsePermissionAsked>());
    });
  });
}
