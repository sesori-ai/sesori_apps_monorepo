import "package:sesori_bridge/src/routing/get_session_tool_output_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionToolOutputHandler", () {
    late TestChatHistory history;
    late GetSessionToolOutputHandler handler;

    setUp(() async {
      history = createTestChatHistory();
      handler = GetSessionToolOutputHandler(chatHistoryService: history.service);
      await history.service.captureMessage(
        sessionId: "s1",
        message: const Message.assistant(
          id: "m1",
          sessionID: "s1",
          agent: null,
          modelID: null,
          providerID: null,
          sender: MessageSender.agent,
          time: null,
        ),
      );
      await history.service.capturePart(
        sessionId: "s1",
        part: const MessagePart.tool(
          id: "p1",
          sessionID: "s1",
          messageID: "m1",
          tool: "bash",
          state: ToolState(status: ToolStatus.error, title: null, shellCommand: "ls", output: null, error: "denied"),
        ),
      );
    });

    Future<SessionToolOutputResponse> handle({required String partId}) => handler.handle(
      makeRequest("POST", "/session/tool-output"),
      body: SessionToolOutputRequest(sessionId: "s1", messageId: "m1", partId: partId),
    );

    test("handles POST /session/tool-output only", () {
      expect(handler.canHandle(makeRequest("POST", "/session/tool-output")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/session/tool-output")), isFalse);
    });

    test("returns the stored tool's output and error", () async {
      expect(await handle(partId: "p1"), const SessionToolOutputResponse(output: null, error: "denied"));
    });

    test("returns 404 when the part is missing", () async {
      await expectLater(
        () => handle(partId: "gone"),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 404)),
      );
    });

    test("returns 400 when an id is empty", () async {
      await expectLater(
        () => handle(partId: ""),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 400)),
      );
    });
  });
}
