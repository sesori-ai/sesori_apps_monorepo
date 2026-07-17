import "package:sesori_bridge/src/bridge/services/command_timeline_mutation.dart";
import "package:sesori_bridge/src/bridge/sse/command_timeline_sse_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("maps every command timeline mutation at the SSE boundary", () {
    const part = MessagePart(
      id: "part",
      sessionID: "session",
      messageID: "message",
      type: MessagePartType.text,
      text: "result",
      tool: null,
      state: null,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
    );
    const mapper = CommandTimelineSseMapper();

    final events = mapper.mapAll(const [
      CommandTimelineEnvelopeUpdated(
        info: Message.user(
          id: "message",
          sessionID: "session",
          agent: null,
          time: null,
        ),
      ),
      CommandTimelinePartUpdated(part: part),
      CommandTimelinePartDelta(
        sessionId: "session",
        messageId: "message",
        partId: "part",
        field: "text",
        delta: "more",
      ),
      CommandTimelinePartRemoved(
        sessionId: "session",
        messageId: "message",
        partId: "part",
      ),
    ]);

    expect(events, [
      isA<SesoriMessageUpdated>().having((event) => event.info.id, "message id", "message"),
      isA<SesoriMessagePartUpdated>().having((event) => event.part, "part", part),
      isA<SesoriMessagePartDelta>()
          .having((event) => event.sessionID, "session id", "session")
          .having((event) => event.messageID, "message id", "message")
          .having((event) => event.partID, "part id", "part")
          .having((event) => event.field, "field", "text")
          .having((event) => event.delta, "delta", "more"),
      isA<SesoriMessagePartRemoved>()
          .having((event) => event.sessionID, "session id", "session")
          .having((event) => event.messageID, "message id", "message")
          .having((event) => event.partID, "part id", "part"),
    ]);
  });
}
