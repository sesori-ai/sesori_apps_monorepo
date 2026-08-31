import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("message attachment compatibility", () {
    test("older message and tool payloads decode with omitted optional data", () {
      final part = MessagePart.fromJson(const {
        "id": "part-1",
        "sessionID": "session-1",
        "messageID": "message-1",
        "type": "text",
        "text": "hello",
      });
      final state = ToolState.fromJson(const {"status": "completed", "title": "git status"});

      expect(
        part,
        equals(const MessagePart.text(id: "part-1", sessionID: "session-1", messageID: "message-1", text: "hello")),
      );
      expect(state.title, "git status");
      expect(state.shellCommand, isNull);
      expect(state.attachments, isEmpty);
    });

    test("malformed attachment values do not reject their enclosing models", () {
      final part = MessagePart.fromJson(const {
        "id": "part-1",
        "sessionID": "session-1",
        "messageID": "message-1",
        "type": "file",
        "attachment": "not-an-object",
      });
      final state = ToolState.fromJson(const {
        "status": "completed",
        "attachments": [
          "not-an-object",
          {"source": "metadata", "mime": "image/png", "filename": "valid.png"},
          {"source": "inline_image", "mime": 42, "base64": false},
        ],
      });

      expect(part, isA<MessagePartFile>());
      expect((part as MessagePartFile).attachment, isA<MessageAttachmentUnknown>());
      expect(
        state.attachments,
        equals([const MessageAttachment.metadata(mime: "image/png", filename: "valid.png")]),
      );
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

  group("message part compatibility", () {
    const common = {"id": "part-1", "sessionID": "session-1", "messageID": "message-1"};
    const variants = <String, MessagePart>{
      "text": MessagePart.text(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "reasoning": MessagePart.reasoning(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "tool": MessagePart.tool(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "subtask": MessagePart.subtask(
        id: "part-1",
        sessionID: "session-1",
        messageID: "message-1",
      ),
      "step-start": MessagePart.stepStart(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "step-finish": MessagePart.stepFinish(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "file": MessagePart.file(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "snapshot": MessagePart.snapshot(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "patch": MessagePart.patch(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "agent": MessagePart.agent(id: "part-1", sessionID: "session-1", messageID: "message-1"),
      "retry": MessagePart.retry(
        id: "part-1",
        sessionID: "session-1",
        messageID: "message-1",
      ),
      "compaction": MessagePart.compaction(id: "part-1", sessionID: "session-1", messageID: "message-1"),
    };

    for (final MapEntry(key: type, value: expected) in variants.entries) {
      test("decodes a legacy $type payload with omitted variant fields", () {
        final json = {...common, "type": type};
        final decoded = MessagePart.fromJson(json);
        final encoded = decoded.toJson();

        expect(decoded, expected);
        expect(encoded["type"], type);
        expect(encoded.values, everyElement(isNotNull));
        expect(MessagePart.fromJson(encoded), expected);
      });
    }

    test("decodes through the enclosing SSE wire event", () {
      final event = SesoriSseEvent.fromJson(const {
        "type": "message.part.updated",
        "part": {...common, "type": "text", "text": "hello"},
      });

      expect(event, isA<SesoriMessagePartUpdated>());
      expect(
        (event as SesoriMessagePartUpdated).part,
        equals(const MessagePart.text(id: "part-1", sessionID: "session-1", messageID: "message-1", text: "hello")),
      );
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
      const roundedUpEncodedLength = ((maxInlineMessageAttachmentBytes + 2) ~/ 3) * 4;

      expect(attachment.toString(), isNot(contains("sensitive-file-content")));
      expect(isInlineMessageAttachmentWithinSizeLimit(base64Length: roundedUpEncodedLength), isFalse);
      expect(
        conservativeDecodedBase64Length(base64Length: roundedUpEncodedLength),
        greaterThan(maxInlineMessageAttachmentBytes),
      );
    });

    test("transcript retention limits remain independent from inline delivery", () {
      const exactLimitLength = ((maxTranscriptImageBytes + 2) ~/ 3) * 4;

      expect(maxTranscriptImageBytes, 20 * 1024 * 1024);
      expect(maxTranscriptImageCollectionBytes, 50 * 1024 * 1024);
      expect(maxTranscriptImageCandidates, 4);
      expect(maxTranscriptImageBytes, greaterThan(maxInlineMessageAttachmentBytes));
      expect(isTranscriptImageBase64LengthWithinSizeLimit(base64Length: exactLimitLength), isTrue);
      expect(isTranscriptImageBase64LengthWithinSizeLimit(base64Length: exactLimitLength + 1), isFalse);
    });

    test("inline attachments round-trip through the wire shape", () {
      const attachment = MessageAttachment.inlineImage(
        mime: "image/png",
        base64: "aGVsbG8=",
        filename: "image.png",
      );

      expect(MessageAttachment.fromJson(attachment.toJson()), attachment);
    });

    test("stored images round-trip with scoped opaque identity", () {
      const attachment = MessageAttachment.storedImage(
        attachmentId: "sha256-opaque",
        bridgeId: "bridge-1",
        mime: "image/png",
        filename: "image.png",
        byteLength: 1234,
      );

      expect(attachment.safeRemoteUri, isNull);
      expect(attachment.toJson(), {
        "source": "stored_image",
        "attachmentId": "sha256-opaque",
        "bridgeId": "bridge-1",
        "mime": "image/png",
        "filename": "image.png",
        "byteLength": 1234,
      });
      expect(MessageAttachment.fromJson(attachment.toJson()), attachment);
    });
  });
}
