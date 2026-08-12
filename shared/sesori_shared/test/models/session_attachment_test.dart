import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("older history and SSE requests default to inline attachments", () {
    final history = SessionMessagesRequest.fromJson(const {
      "sessionId": "session-1",
      "limit": 20,
      "before": 40,
    });
    final subscription = RelayMessage.fromJson(const {
      "type": "sse_subscribe",
      "path": "/events",
    });

    expect(history.attachmentDelivery, MessageAttachmentDelivery.inline);
    expect(
      subscription,
      const RelayMessage.sseSubscribe(
        path: "/events",
        attachmentDelivery: MessageAttachmentDelivery.inline,
      ),
    );
  });

  test("stored-reference delivery serializes on both request surfaces", () {
    const history = SessionMessagesRequest(
      sessionId: "session-1",
      limit: 20,
      before: null,
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
    );
    const subscription = RelayMessage.sseSubscribe(
      path: "/events",
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
    );

    expect(history.toJson()["attachmentDelivery"], "storedReference");
    expect(subscription.toJson()["attachmentDelivery"], "storedReference");
  });

  test("attachment rendition request and response round-trip", () {
    const request = SessionAttachmentRequest(
      sessionId: "session-1",
      attachmentId: "attachment-1",
      rendition: SessionAttachmentRendition.thumbnail,
    );
    const response = SessionAttachmentResponse(
      mime: "image/jpeg",
      base64: "aGVsbG8=",
      byteLength: 5,
    );

    expect(SessionAttachmentRequest.fromJson(request.toJson()), request);
    expect(SessionAttachmentResponse.fromJson(response.toJson()), response);
    expect(response.toString(), isNot(contains("aGVsbG8=")));
  });
}
