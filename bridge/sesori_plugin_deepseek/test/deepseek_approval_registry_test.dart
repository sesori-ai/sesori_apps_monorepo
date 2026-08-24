import "dart:async";
import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";
void main() {
  late FakeAcpProcess fake;
  late AcpStdioClient client;
  late DeepSeekApprovalRegistry registry;
  late List<BridgeSseEvent> events;
  AcpServerRequest questionRequest(int id, Map<String, dynamic> params) => AcpServerRequest(
    id: id,
    method: DeepSeekAcpApi.askUserQuestionMethod,
    params: params,
  );
  setUp(() async {
    fake = FakeAcpProcess();
    client = AcpStdioClient(
      launchSpec: const AcpLaunchSpec(command: "deepseek", args: ["serve"]),
      processFactory: (_) async => fake,
    );
    await client.connect();
    events = [];
    registry = DeepSeekApprovalRegistry(
      client: client,
      emit: events.add,
      onFireAndForgetNotification: (_) {},
      api: const DeepSeekAcpApi(),
      idGenerator: () => "request-1",
    );
  });
  tearDown(() async {
    await registry.dispose();
    await client.dispose();
    await fake.close();
  });
  test("option and free-form answers preserve ordered question IDs", () {
    registry.handleExtensionRequest(
      questionRequest(7, const {
        "sessionId": "session-1",
        "questions": [
          {
            "id": "q-option",
            "text": "Proceed?",
            "options": ["Yes", "No"],
          },
          {"id": "q-free", "text": "Why?"},
        ],
      }),
    );
    expect(events.single, isA<BridgeSseQuestionAsked>());
    expect(
      registry.replyQuestion("request-1", const [
        ["Yes"],
        ["Because"],
      ]),
      isTrue,
    );
    expect(fake.written.single, {
      "jsonrpc": "2.0",
      "id": 7,
      "result": {
        "answers": [
          {
            "questionId": "q-option",
            "selectedLabels": ["Yes"],
          },
          {"questionId": "q-free", "selectedLabels": <String>[], "customAnswer": "Because"},
        ],
      },
    });
  });
  test("question cancellation uses base error response", () async {
    registry.handleExtensionRequest(
      questionRequest(8, const {
        "sessionId": "session-1",
        "questions": [
          {
            "id": "q1",
            "text": "Proceed?",
            "options": ["Yes", "No"],
          },
        ],
      }),
    );
    registry.cancelForSession("session-1");
    await Future<void>.delayed(Duration.zero);
    expect(fake.written.single, {
      "jsonrpc": "2.0",
      "id": 8,
      "error": {"code": -32603, "message": "aborted"},
    });
  });
  test("malformed question rejects without pending state", () {
    registry.handleExtensionRequest(questionRequest(9, const {"questions": <Object>[]}));
    expect(fake.written.single, {
      "jsonrpc": "2.0",
      "id": 9,
      "error": {"code": -32602, "message": "Invalid DeepSeek question request"},
    });
    expect(registry.hasAnyPendingInput, isFalse);
  });
}
