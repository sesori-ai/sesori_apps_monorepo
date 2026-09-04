import "package:sesori_bridge/src/repositories/mappers/plugin_to_shared_mapping.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PluginMessagePartMapping.toShared()", () {
    test("passes through agentName", () {
      const part = PluginMessagePart.agent(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        agentName: "my-agent",
      );

      final shared = part.toShared(sessionId: "stable-session");

      expect(shared, isA<MessagePartAgent>());
      expect((shared as MessagePartAgent).agentName, equals("my-agent"));
      expect(shared.sessionID, equals("stable-session"));
    });

    test("passes through attempt", () {
      const part = PluginMessagePart.retry(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        attempt: 3,
        retryError: "retry",
      );

      final shared = part.toShared(sessionId: "stable-session");

      expect(shared, isA<MessagePartRetry>());
      expect((shared as MessagePartRetry).attempt, equals(3));
    });

    test("passes through retryError", () {
      const part = PluginMessagePart.retry(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        attempt: 1,
        retryError: "connection timeout",
      );

      final shared = part.toShared(sessionId: "stable-session");

      expect(shared, isA<MessagePartRetry>());
      expect((shared as MessagePartRetry).retryError, equals("connection timeout"));
    });

    test("maps text without unrelated variant fields", () {
      const part = PluginMessagePart.text(id: "p1", sessionID: "s1", messageID: "m1", text: "hello");

      final shared = part.toShared(sessionId: "stable-session");

      expect(shared, isA<MessagePartText>());
      expect(shared.toJson(), {
        "id": "p1",
        "sessionID": "stable-session",
        "messageID": "m1",
        "text": "hello",
        "type": "text",
      });
    });

    test("maps normalized remote attachment data", () {
      final part = PluginMessagePart.file(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        attachment: PluginMessageAttachment.remoteUrl(
          mime: "application/pdf",
          url: Uri.parse("https://files.example.com/report.pdf"),
          filename: "report.pdf",
        ),
      );

      expect(
        (part.toShared(sessionId: "s1") as MessagePartFile).attachment,
        equals(
          const MessageAttachment.remoteUrl(
            mime: "application/pdf",
            url: "https://files.example.com/report.pdf",
            filename: "report.pdf",
          ),
        ),
      );
    });

    test("degrades a plugin remote attachment outside HTTP(S) to metadata", () {
      final part = PluginMessagePart.file(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        attachment: PluginMessageAttachment.remoteUrl(
          mime: "text/plain",
          url: Uri.parse("file:///private/secret.txt"),
          filename: "secret.txt",
        ),
      );

      expect(
        (part.toShared(sessionId: "s1") as MessagePartFile).attachment,
        equals(const MessageAttachment.metadata(mime: "text/plain", filename: "secret.txt")),
      );
    });

    test("strips path components from plugin-provided filenames", () {
      const part = PluginMessagePart.file(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        attachment: PluginMessageAttachment.metadata(
          mime: "text/plain",
          filename: "/Users/alice/private/project/secret.txt",
        ),
      );

      expect(
        (part.toShared(sessionId: "s1") as MessagePartFile).attachment,
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
      expect(PluginToolStatus.cancelled.toShared(), equals(ToolStatus.cancelled));
      // Unlike message-part type, unknown is a real renderable state and maps
      // through rather than throwing.
      expect(PluginToolStatus.unknown.toShared(), equals(ToolStatus.unknown));
    });

    test("cancelled keeps a wire value an older client degrades to unknown", () {
      const state = PluginToolState(
        status: PluginToolStatus.cancelled,
        title: null,
        shellCommand: null,
        output: null,
        error: null,
        attachments: [],
      );

      final json = state.toShared().toJson();

      expect(json["status"], equals("cancelled"));
      expect(
        ToolState.fromJson({...json, "status": "a-status-from-a-newer-bridge"}).status,
        equals(ToolStatus.unknown),
      );
    });

    test("only completed, error, cancelled and unknown are terminal", () {
      expect(
        {for (final status in PluginToolStatus.values) status: status.isTerminal},
        equals({
          PluginToolStatus.pending: false,
          PluginToolStatus.running: false,
          PluginToolStatus.completed: true,
          PluginToolStatus.error: true,
          PluginToolStatus.cancelled: true,
          PluginToolStatus.unknown: true,
        }),
      );
    });
  });

  group("PluginMessagePartSubtask.toShared()", () {
    test("carries the subtask lifecycle and its child reference for translation", () {
      const part = PluginMessagePart.subtask(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        prompt: "explore",
        description: "Explore",
        agent: "explore",
        taskState: PluginToolState(
          status: PluginToolStatus.cancelled,
          title: null,
          shellCommand: null,
          output: null,
          error: null,
          attachments: [],
        ),
        childSessionID: "backend-child",
      );

      final shared = part.toShared(sessionId: "stable-session") as MessagePartSubtask;

      expect(shared.taskState?.status, equals(ToolStatus.cancelled));
      expect(shared.childSessionID, equals("backend-child"));
      expect(shared.sessionID, equals("stable-session"));
    });

    test("omits an absent lifecycle and child reference from the wire payload", () {
      const part = PluginMessagePart.subtask(
        id: "p1",
        sessionID: "s1",
        messageID: "m1",
        prompt: "explore",
        description: "Explore",
        agent: "explore",
        taskState: null,
        childSessionID: null,
      );

      final json = part.toShared(sessionId: "stable-session").toJson();

      expect(json.containsKey("childSessionID"), isFalse);
      expect(json.containsKey("taskState"), isFalse);
      expect((MessagePart.fromJson(json) as MessagePartSubtask).childSessionID, isNull);
    });
  });

  group("PluginToolStateMapping.toShared()", () {
    test("strips non-shell title and output while preserving status and attachments", () {
      const state = PluginToolState(
        status: PluginToolStatus.completed,
        title: "Read file",
        shellCommand: null,
        output: "contents",
        error: null,
        attachments: [
          PluginMessageAttachment.metadata(mime: "image/png", filename: "screenshot.png"),
        ],
      );

      final shared = state.toShared();

      expect(shared.status, equals(ToolStatus.completed));
      expect(shared.title, isNull);
      expect(shared.shellCommand, isNull);
      expect(shared.output, isNull);
      expect(shared.error, isNull);
      expect(
        shared.attachments,
        equals([const MessageAttachment.metadata(mime: "image/png", filename: "screenshot.png")]),
      );
    });

    test("preserves shell command results", () {
      const state = PluginToolState(
        status: PluginToolStatus.completed,
        title: "Shell",
        shellCommand: "git status --short",
        output: " M file.dart",
        error: null,
        attachments: [],
      );

      final shared = state.toShared();

      expect(shared.title, equals("git status --short"));
      expect(shared.shellCommand, equals("git status --short"));
      expect(shared.output, equals(" M file.dart"));
      expect(shared.error, isNull);
    });

    test("bounds shell commands by runes", () {
      final command = "😀" * (maxToolOutputLength + 1);
      final shared = PluginToolState(
        status: PluginToolStatus.completed,
        title: null,
        shellCommand: command,
        output: "done",
        error: null,
        attachments: const [],
      ).toShared();

      expect(shared.shellCommand?.runes.length, maxToolOutputLength);
      expect(shared.title, shared.shellCommand);
      expect(shared.output, "done");
    });

    test("round-trips status through JSON using the unchanged wire value", () {
      const state = PluginToolState(
        status: PluginToolStatus.running,
        title: null,
        shellCommand: null,
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
        "output": null,
        "error": null,
      });

      expect(decoded.status, equals(ToolStatus.unknown));
    });
  });
}
