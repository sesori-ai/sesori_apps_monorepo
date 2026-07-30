import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("message attachment compatibility", () {
    test("older message and tool payloads decode with no attachments", () {
      final part = MessagePart.fromJson(const {
        "id": "part-1",
        "sessionID": "session-1",
        "messageID": "message-1",
        "type": "text",
        "text": "hello",
      });
      final state = ToolState.fromJson(const {"status": "completed"});

      expect(part.attachment, isNull);
      expect(state.attachments, isEmpty);
    });

    test("unknown future sources degrade without rejecting the message", () {
      final attachment = MessageAttachment.fromJson(const {
        "source": "future_source",
        "opaque": "value",
      });

      expect(attachment, isA<MessageAttachmentUnknown>());
      expect(attachment.safeRemoteUri, isNull);
    });
  });

  group("message attachment safety", () {
    test("only host-qualified HTTP(S) remote URLs are launchable", () {
      const https = MessageAttachment.remoteUrl(
        mime: "image/png",
        url: "https://cdn.example.com/image.png?token=secret",
        filename: "image.png",
      );
      const userInfo = MessageAttachment.remoteUrl(
        mime: "image/png",
        url: "https://user:password@cdn.example.com/image.png",
        filename: "image.png",
      );
      const customScheme = MessageAttachment.remoteUrl(
        mime: "image/png",
        url: "intent://open/image.png",
        filename: "image.png",
      );

      expect(https.safeRemoteUri, Uri.parse("https://cdn.example.com/image.png?token=secret"));
      expect(userInfo.safeRemoteUri, isNull);
      expect(customScheme.safeRemoteUri, isNull);
    });

    test("inline payloads are redacted and bounded by encoded length", () {
      const attachment = MessageAttachment.inlineImage(
        mime: "image/png",
        base64: "sensitive-file-content",
        filename: "image.png",
      );
      const maxEncodedLength = ((maxInlineMessageAttachmentBytes + 2) ~/ 3) * 4;

      expect(attachment.toString(), isNot(contains("sensitive-file-content")));
      expect(isInlineMessageAttachmentWithinSizeLimit(base64Length: maxEncodedLength), isTrue);
      expect(isInlineMessageAttachmentWithinSizeLimit(base64Length: maxEncodedLength + 1), isFalse);
    });

    test("inline attachments round-trip through the wire shape", () {
      const attachment = MessageAttachment.inlineImage(
        mime: "image/png",
        base64: "aGVsbG8=",
        filename: "image.png",
      );

      expect(MessageAttachment.fromJson(attachment.toJson()), attachment);
    });
  });
}
