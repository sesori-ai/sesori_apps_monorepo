import "package:opencode_plugin/src/message_part_mapper.dart";
import "package:opencode_plugin/src/models/openapi/file_part.g.dart";
import "package:opencode_plugin/src/models/openapi/part.g.dart";
import "package:opencode_plugin/src/models/openapi/session_messages_response_item.g.dart";
import "package:opencode_plugin/src/models/openapi/user_message.g.dart";
import "package:opencode_plugin/src/plugin_model_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("bounds total inline attachment bytes per message", () {
    const mapper = PluginModelMapper(
      messagePartMapper: MessagePartMapper(),
      maxTranscriptAttachmentBytes: 5,
    );
    final mapped = mapper.mapMessageWithParts(
      SessionMessagesResponseItem(
        info: UserMessage.fromJson(const {
          "role": "user",
          "id": "message-1",
          "sessionID": "session-1",
          "time": {"created": 0},
          "agent": "agent",
          "model": {"providerID": "provider", "modelID": "model"},
        }),
        parts: const <Part>[
          FilePart(
            id: "file-1",
            sessionID: "session-1",
            messageID: "message-1",
            mime: "image/png",
            filename: "first.png",
            url: "data:image/png;base64,aGVsbG8=",
            source: null,
          ),
          FilePart(
            id: "file-2",
            sessionID: "session-1",
            messageID: "message-1",
            mime: "image/png",
            filename: "second.png",
            url: "data:image/png;base64,aGVsbG8=",
            source: null,
          ),
        ],
      ),
    );

    expect(mapped.parts[0].attachment, isA<PluginMessageAttachmentInlineImage>());
    expect(
      mapped.parts[1].attachment,
      equals(const PluginMessageAttachment.metadata(mime: "image/png", filename: "second.png")),
    );
  });
}
