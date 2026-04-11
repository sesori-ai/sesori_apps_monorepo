import "package:opencode_plugin/src/models/message_with_parts.dart";
import "package:test/test.dart";

void main() {
  group("MessageWithParts", () {
    test("ignores UserMessage.variant relocation during decode", () {
      final payloads = <Map<String, Object?>>[
        {
          "info": {
            "role": "user",
            "id": "msg-1",
            "sessionID": "ses-1",
          },
          "parts": [
            {
              "id": "part-1",
              "sessionID": "ses-1",
              "messageID": "msg-1",
              "type": "text",
              "text": "hello",
            },
          ],
        },
        {
          "variant": "user",
          "info": {
            "role": "user",
            "id": "msg-1",
            "sessionID": "ses-1",
          },
          "parts": [
            {
              "id": "part-1",
              "sessionID": "ses-1",
              "messageID": "msg-1",
              "type": "text",
              "text": "hello",
            },
          ],
        },
        {
          "info": {
            "role": "user",
            "id": "msg-1",
            "sessionID": "ses-1",
            "variant": "user",
          },
          "parts": [
            {
              "id": "part-1",
              "sessionID": "ses-1",
              "messageID": "msg-1",
              "type": "text",
              "text": "hello",
            },
          ],
        },
      ];

      for (final payload in payloads) {
        final decoded = MessageWithParts.fromJson(payload);

        expect(decoded.info.role, equals("user"));
        expect(decoded.info.id, equals("msg-1"));
        expect(decoded.info.sessionID, equals("ses-1"));
        expect(decoded.parts, hasLength(1));
        expect(decoded.parts.single.type, equals("text"));
        expect(decoded.parts.single.text, equals("hello"));
      }
    });
  });
}
