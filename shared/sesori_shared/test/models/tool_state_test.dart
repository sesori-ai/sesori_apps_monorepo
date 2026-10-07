import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const common = {"type": "tool", "id": "part-1", "sessionID": "session-1", "messageID": "message-1", "tool": "bash"};

  test("keyless tool state, from stored rows and v1.9.0 bridges, decodes as full", () {
    final part = MessagePart.fromJson({
      ...common,
      "state": {"status": "completed", "shellCommand": "ls", "output": "a.txt", "error": "warn"},
    });

    expect(
      (part as MessagePartTool).state,
      const ToolState(status: ToolStatus.completed, title: null, shellCommand: "ls", output: "a.txt", error: "warn"),
    );
  });

  test("a full state round-trips and keeps the keys a v1.9.0 app reads", () {
    const part = MessagePart.tool(
      id: "part-1",
      sessionID: "session-1",
      messageID: "message-1",
      tool: "bash",
      state: ToolState(status: ToolStatus.error, title: "t", shellCommand: "ls", output: "o", error: "e"),
    );
    final state = part.toJson()["state"] as Map<String, dynamic>;

    expect(state, containsPair("form", "full"));
    expect(state, containsPair("output", "o"));
    expect(state, containsPair("error", "e"));
    expect(MessagePart.fromJson(part.toJson()), part);
  });

  test("a summary state round-trips without output or error", () {
    const part = MessagePart.tool(
      id: "part-1",
      sessionID: "session-1",
      messageID: "message-1",
      tool: "bash",
      state: ToolState.summary(
        status: ToolStatus.completed,
        title: null,
        shellCommand: "ls",
        attachments: [MessageAttachment.metadata(mime: "image/png", filename: "shot.png")],
      ),
    );
    final state = part.toJson()["state"] as Map<String, dynamic>;

    expect(state, containsPair("form", "summary"));
    expect(state.keys, isNot(contains("output")));
    expect(state.keys, isNot(contains("error")));
    expect(MessagePart.fromJson(part.toJson()), part);
  });

  test("a v1.9.0 app's page request omits the delivery and gets full tool parts", () {
    final request = SessionMessagesRequest.fromJson({"sessionId": "session-1", "limit": 50});

    expect(request.toolOutputDelivery, ToolOutputDelivery.inline);
  });

  test("the delivery round-trips on both history requests", () {
    const page = SessionMessagesRequest(
      sessionId: "session-1",
      limit: 50,
      before: null,
      toolOutputDelivery: ToolOutputDelivery.onExpand,
    );
    const through = SessionMessagesThroughRequest(
      sessionId: "session-1",
      throughSeq: 1,
      before: 9,
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
      storedOnly: false,
      toolOutputDelivery: ToolOutputDelivery.onExpand,
    );

    expect(page.toJson(), containsPair("toolOutputDelivery", "onExpand"));
    expect(SessionMessagesRequest.fromJson(page.toJson()), page);
    expect(SessionMessagesThroughRequest.fromJson(through.toJson()), through);
  });

  test("the tool output request and response round-trip", () {
    const request = SessionToolOutputRequest(sessionId: "session-1", messageId: "message-1", partId: "part-1");
    const response = SessionToolOutputResponse(output: "a.txt", error: null);

    expect(SessionToolOutputRequest.fromJson(request.toJson()), request);
    expect(SessionToolOutputResponse.fromJson(response.toJson()), response);
  });
}
