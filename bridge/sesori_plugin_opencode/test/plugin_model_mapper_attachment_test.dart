import "package:opencode_plugin/src/message_part_mapper.dart";
import "package:opencode_plugin/src/models/openapi/assistant_message.g.dart";
import "package:opencode_plugin/src/models/openapi/file_part.g.dart";
import "package:opencode_plugin/src/models/openapi/part.g.dart";
import "package:opencode_plugin/src/models/openapi/session_messages_response_item.g.dart";
import "package:opencode_plugin/src/models/openapi/text_part.g.dart";
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
      compactionAuto: null,
    );

    expect(mapped.parts[0].attachment, isA<PluginMessageAttachmentInlineImage>());
    expect(
      mapped.parts[1].attachment,
      equals(const PluginMessageAttachment.metadata(mime: "image/png", filename: "second.png")),
    );
  });

  test("maps a compaction summary message's text in the state of its message", () {
    const mapper = PluginModelMapper(
      messagePartMapper: MessagePartMapper(),
      maxTranscriptAttachmentBytes: 5,
    );
    PluginMessageWithParts summary({
      required int? completed,
      required Object? error,
      required bool? auto,
      required List<Part> parts,
    }) => mapper.mapMessageWithParts(
      SessionMessagesResponseItem(
        info: AssistantMessage(
          id: "message-1",
          sessionID: "session-1",
          time: AssistantMessageTime(created: 100, completed: completed),
          error: error,
          parentID: "parent-1",
          modelID: "gpt-4",
          providerID: "openai",
          mode: "compaction",
          agent: "compaction",
          path: const AssistantMessagePath(cwd: "/repo", root: "/repo"),
          summary: true,
          cost: 0,
          tokens: const AssistantMessageTokens(
            total: 0,
            input: 0,
            output: 0,
            reasoning: 0,
            cache: AssistantMessageTokensCache(read: 0, write: 0),
          ),
          structured: null,
          variant: null,
          finish: null,
        ),
        parts: parts,
      ),
      compactionAuto: auto,
    );
    const text = TextPart(
      id: "part-1",
      sessionID: "session-1",
      messageID: "message-1",
      text: "## Goal\nShip the row.",
      synthetic: null,
      ignored: null,
      time: null,
      metadata: null,
    );
    PluginCompactionState? state(PluginMessageWithParts message) => switch (message.parts.single) {
      PluginMessagePartCompaction(:final compactionState) => compactionState,
      _ => null,
    };
    const fixtureError = {
      "name": "MessageAbortedError",
      "data": {"message": "Fixture failure"},
    };

    expect(
      state(summary(completed: null, error: null, auto: true, parts: const [text])),
      const PluginCompactionState.running(summary: "## Goal\nShip the row."),
    );
    for (final (auto, trigger) in const [
      (true, PluginCompactionTrigger.auto),
      (false, PluginCompactionTrigger.manual),
      (null, null),
    ]) {
      expect(
        state(summary(completed: 200, error: null, auto: auto, parts: const [text])),
        PluginCompactionState.completed(summary: "## Goal\nShip the row.", freedTokens: null, trigger: trigger),
      );
    }
    final failed = summary(completed: 200, error: fixtureError, auto: true, parts: const [text]);
    expect(state(failed), const PluginCompactionState.failed(reason: PluginCompactionFailureReason.cancelled));
    expect(failed.info, isA<PluginMessageAssistant>());
    expect(
      summary(completed: 200, error: fixtureError, auto: true, parts: const []).info,
      isA<PluginMessageError>().having((message) => message.errorMessage, "error", "Fixture failure"),
    );
    final empty = summary(
      completed: 200,
      error: fixtureError,
      auto: true,
      parts: const [
        TextPart(
          id: "part-1",
          sessionID: "session-1",
          messageID: "message-1",
          text: "",
          synthetic: null,
          ignored: null,
          time: null,
          metadata: null,
        ),
      ],
    );
    expect(empty.info, isA<PluginMessageError>().having((message) => message.errorMessage, "error", "Fixture failure"));
    expect(empty.parts.single, isA<PluginMessagePartText>());
  });
}
