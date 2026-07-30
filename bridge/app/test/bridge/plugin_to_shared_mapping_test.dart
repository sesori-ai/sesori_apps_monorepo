import "package:sesori_bridge/src/bridge/plugin_to_shared_mapping.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PluginMessagePartTypeMapping.toShared()", () {
    test("maps patch to MessagePartType.patch", () {
      expect(PluginMessagePartType.patch.toShared(), equals(MessagePartType.patch));
    });

    test("maps agent to MessagePartType.agent", () {
      expect(PluginMessagePartType.agent.toShared(), equals(MessagePartType.agent));
    });

    test("maps retry to MessagePartType.retry", () {
      expect(PluginMessagePartType.retry.toShared(), equals(MessagePartType.retry));
    });

    test("maps compaction to MessagePartType.compaction", () {
      expect(PluginMessagePartType.compaction.toShared(), equals(MessagePartType.compaction));
    });

    test("throws StateError for unknown", () {
      expect(() => PluginMessagePartType.unknown.toShared(), throwsStateError);
    });
  });

  group("PluginMessagePartMapping.toShared()", () {
    test("passes through agentName", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.agent,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: "my-agent",
        attempt: null,
        retryError: null,
        attachment: null,
      );

      final shared = part.toShared(sessionId: "stable-session");

      expect(shared.agentName, equals("my-agent"));
      expect(shared.sessionID, equals("stable-session"));
    });

    test("passes through attempt", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.retry,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: 3,
        retryError: null,
        attachment: null,
      );

      final shared = part.toShared(sessionId: "stable-session");

      expect(shared.attempt, equals(3));
    });

    test("passes through retryError", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.retry,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: 1,
        retryError: "connection timeout",
        attachment: null,
      );

      final shared = part.toShared(sessionId: "stable-session");

      expect(shared.retryError, equals("connection timeout"));
    });

    test("passes through null values for new fields", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.text,
        text: "hello",
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
        attachment: null,
      );

      final shared = part.toShared(sessionId: "stable-session");

      expect(shared.agentName, isNull);
      expect(shared.attempt, isNull);
      expect(shared.retryError, isNull);
    });

    test("maps normalized remote attachment data", () {
      final part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.file,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
        attachment: PluginMessageAttachment.remoteUrl(
          mime: "application/pdf",
          url: Uri.parse("https://files.example.com/report.pdf"),
          filename: "report.pdf",
        ),
      );

      expect(
        part.toShared(sessionId: "s1").attachment,
        equals(
          const MessageAttachment.remoteUrl(
            mime: "application/pdf",
            url: "https://files.example.com/report.pdf",
            filename: "report.pdf",
          ),
        ),
      );
    });

    test("rejects a plugin remote attachment outside HTTP(S)", () {
      final part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.file,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
        attachment: PluginMessageAttachment.remoteUrl(
          mime: "text/plain",
          url: Uri.parse("file:///private/secret.txt"),
          filename: "secret.txt",
        ),
      );

      expect(() => part.toShared(sessionId: "s1"), throwsStateError);
    });

    test("strips path components from plugin-provided filenames", () {
      const part = PluginMessagePart(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        type: PluginMessagePartType.file,
        text: null,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
        attachment: PluginMessageAttachment.metadata(
          mime: "text/plain",
          filename: "/Users/alice/private/project/secret.txt",
        ),
      );

      expect(
        part.toShared(sessionId: "s1").attachment,
        equals(const MessageAttachment.metadata(mime: "text/plain", filename: "secret.txt")),
      );
    });
  });

  group("PluginToolStatusMapping.toShared()", () {
    test("maps every plugin status to the matching shared ToolStatus", () {
      expect(PluginToolStatus.pending.toShared(), equals(ToolStatus.pending));
      expect(PluginToolStatus.running.toShared(), equals(ToolStatus.running));
      expect(PluginToolStatus.completed.toShared(), equals(ToolStatus.completed));
      expect(PluginToolStatus.error.toShared(), equals(ToolStatus.error));
      // Unlike message-part type, unknown is a real renderable state and maps
      // through rather than throwing.
      expect(PluginToolStatus.unknown.toShared(), equals(ToolStatus.unknown));
    });
  });

  group("PluginToolStateMapping.toShared()", () {
    test("carries status as a typed ToolStatus enum, not a wire string", () {
      const state = PluginToolState(
        status: PluginToolStatus.completed,
        title: "Read file",
        output: "contents",
        error: null,
        attachments: [
          PluginMessageAttachment.metadata(mime: "image/png", filename: "screenshot.png"),
        ],
      );

      final shared = state.toShared();

      expect(shared.status, equals(ToolStatus.completed));
      expect(shared.title, equals("Read file"));
      expect(shared.output, equals("contents"));
      expect(shared.error, isNull);
      expect(
        shared.attachments,
        equals([const MessageAttachment.metadata(mime: "image/png", filename: "screenshot.png")]),
      );
    });

    test("round-trips status through JSON using the unchanged wire value", () {
      const state = PluginToolState(
        status: PluginToolStatus.running,
        title: null,
        output: null,
        error: null,
        attachments: [],
      );

      final json = state.toShared().toJson();

      expect(json["status"], equals("running"));
      expect(ToolState.fromJson(json).status, equals(ToolStatus.running));
    });

    test("decodes an unrecognized wire status to ToolStatus.unknown", () {
      final decoded = ToolState.fromJson(const {
        "status": "some-future-status",
        "title": null,
        "output": null,
        "error": null,
      });

      expect(decoded.status, equals(ToolStatus.unknown));
    });
  });
}
