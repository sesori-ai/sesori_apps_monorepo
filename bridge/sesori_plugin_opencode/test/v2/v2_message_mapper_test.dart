import "package:opencode_plugin/src/v2/models/openapi/session_message_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_tool_state.g.dart";
import "package:opencode_plugin/src/v2/models/v2_agent_names.dart";
import "package:opencode_plugin/src/v2/repositories/v2_message_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageBytes;
import "package:test/test.dart";

const mapper = V2MessageMapper();
const names = V2AgentNames(namesById: {"build": "Build", "explore": "Explore"});

Map<String, dynamic> assistant({required List<Object> content}) => <String, dynamic>{
  "type": "assistant",
  "id": "message",
  "agent": "build",
  "model": <String, dynamic>{"providerID": "fixture", "id": "model", "variant": "high"},
  "time": <String, int>{"created": 1, "completed": 2},
  "content": content,
};

Map<String, dynamic> image() => <String, dynamic>{
  "type": "file",
  "mime": "image/png",
  "uri": "data:image/png;base64,AQID",
  "name": "fixture.png",
};

PluginMessageWithParts mapped({required Map<String, dynamic> json}) =>
    mapper.mapMessage(sessionId: "session", message: SessionMessageInfo.fromJson(json), agentNames: names)!;

void main() {
  test("keeps content ordinals and native tool IDs stable", () {
    final result = mapped(
      json: assistant(
        content: <Object>[
          <String, dynamic>{"type": "text", "text": "Fixture"},
          <String, dynamic>{"type": "future-content"},
          <String, dynamic>{"type": "reasoning", "text": "Reasoning"},
          <String, dynamic>{
            "type": "tool",
            "id": "tool-1",
            "name": "bash",
            "time": <String, int>{"created": 1},
            "state": <String, dynamic>{
              "status": "completed",
              "input": <String, dynamic>{"command": "printf fixture"},
              "metadata": <String, dynamic>{"title": "Fixture command"},
              "content": <Object>[
                <String, dynamic>{"type": "text", "text": "x" * 600},
              ],
            },
          },
        ],
      ),
    );
    expect(result.parts.map((part) => part.id), <String>["message:0", "message:2", "tool-1"]);
    final info = result.info as PluginMessageAssistant;
    expect(info.sender, PluginMessageSender.agent);
    expect(info.agent, "Build");
    expect(info.variant, "high");
    expect(info.time!.completed, 2);
    final tool = result.parts.last.asTool;
    expect(tool.state.title, "Fixture command");
    expect(tool.state.shellCommand, "printf fixture");
    expect(tool.state.output!.length, maxToolOutputLength);
  });

  test("truncates tool output by Unicode scalar without splitting surrogate pairs", () {
    final prefix = "x" * (maxToolOutputLength - 1);
    for (final (text, expected) in [
      ("$prefix🌈!", "$prefix🌈"),
      ("🌈" * (maxToolOutputLength + 1), "🌈" * maxToolOutputLength),
    ]) {
      final result = mapper.mapToolState(
        toolName: "read",
        state: SessionMessageToolState.fromJson(<String, dynamic>{
          "status": "completed",
          "input": const <String, dynamic>{},
          "content": <Object>[
            <String, dynamic>{"type": "text", "text": text},
          ],
        }),
      );
      expect(result.output, expected);
      expect(result.output!.runes.length, maxToolOutputLength);
    }
  });

  test("retains retry metadata without shifting content identities", () {
    for (final count in [1, 2]) {
      final result = mapped(
        json: <String, dynamic>{
          ...assistant(
            content: <Object>[
              for (var i = 0; i < count; i++) <String, dynamic>{"type": "text", "text": "Fixture"},
            ],
          ),
          "time": <String, int>{"created": 1},
          "retry": <String, dynamic>{
            "attempt": 2,
            "at": 3,
            "error": <String, dynamic>{"type": "fixture", "message": "Retry fixture"},
          },
        },
      );
      expect(result.parts.take(count).map((part) => part.id), [for (var i = 0; i < count; i++) "message:$i"]);
      final retry = result.parts.last as PluginMessagePartRetry;
      expect(retry.id, "message:retry");
      expect(retry.attempt, 2);
      expect(retry.retryError, "Retry fixture");
    }
  });

  test("projects agent switches as system-authored display names", () {
    final result = mapped(
      json: const <String, dynamic>{
        "type": "agent-switched",
        "id": "switch",
        "agent": "explore",
        "previous": "build",
        "time": <String, int>{"created": 42},
      },
    );
    final info = result.info as PluginMessageAssistant;
    expect(info.sender, PluginMessageSender.system);
    expect(info.agent, isNull);
    expect(info.time!.completed, 42);
    expect(result.parts.single.id, "switch:0");
    expect(result.parts.single.agentName, "Explore");
  });

  test("maps streaming, running and failed tool states without parsing partial JSON", () {
    for (final (raw, expected) in <(Map<String, dynamic>, PluginToolStatus)>[
      (<String, dynamic>{"status": "streaming", "input": '{"command":'}, PluginToolStatus.pending),
      (
        <String, dynamic>{"status": "running", "input": <String, dynamic>{}, "metadata": <String, dynamic>{}},
        PluginToolStatus.running,
      ),
      (
        <String, dynamic>{
          "status": "error",
          "input": <String, dynamic>{},
          "error": <String, dynamic>{"type": "fixture", "message": "Exact failure"},
        },
        PluginToolStatus.error,
      ),
    ]) {
      final result = mapper.mapToolState(toolName: "bash", state: SessionMessageToolState.fromJson(raw));
      expect(result.status, expected);
      if (expected == PluginToolStatus.error) expect(result.error, "Exact failure");
    }
  });

  test("only recognized shell tools expose command input as shell commands", () {
    final state = SessionMessageToolState.fromJson(const <String, dynamic>{
      "status": "running",
      "input": <String, dynamic>{"command": "fixture command"},
      "metadata": <String, dynamic>{"title": "Native task"},
    });
    for (final (name, expected) in const <(String, String?)>[
      ("bash", "fixture command"),
      ("shell", "fixture command"),
      ("mcp-command", null),
    ]) {
      final result = mapper.mapToolState(toolName: name, state: state);
      expect(result.shellCommand, expected);
      expect(result.title, "Native task");
    }
  });

  test("retains assistant failures and system-authored synthetic messages", () {
    final failed =
        mapped(
              json: <String, dynamic>{
                ...assistant(content: const []),
                "error": <String, dynamic>{"type": "provider", "message": "Exact provider failure"},
              },
            ).info
            as PluginMessageError;
    expect(failed.errorMessage, "Exact provider failure");
    expect(failed.agent, "Build");
    final synthetic = mapped(
      json: const <String, dynamic>{
        "type": "synthetic",
        "id": "synthetic",
        "time": <String, int>{"created": 1},
        "text": "Fixture context",
        "description": "Fixture display summary",
      },
    );
    expect((synthetic.info as PluginMessageAssistant).sender, PluginMessageSender.system);
    expect(synthetic.parts.single.text, "Fixture display summary");
  });

  test("does not mark in-progress or failed compaction as completed", () {
    Map<String, dynamic> compact({required String status}) => <String, dynamic>{
      "type": "compaction",
      "id": "compaction",
      "time": <String, int>{"created": 1},
      "status": status,
      "reason": "manual",
      "summary": "Fixture summary",
      "recent": "Fixture recent context",
      if (status == "failed") "error": <String, dynamic>{"type": "fixture", "message": "Compaction failed"},
    };
    expect(mapped(json: compact(status: "running")).parts, isEmpty);
    expect(mapped(json: compact(status: "failed")).info, isA<PluginMessageError>());
    expect(
      (mapped(json: compact(status: "completed")).parts.single as PluginMessagePartCompaction).summary,
      "Fixture summary",
    );
  });

  test("maps shell outcomes and never treats an unknown exit as success", () {
    for (final (status, exit, expected) in <(String, Object?, PluginToolStatus)>[
      ("running", null, PluginToolStatus.running),
      ("exited", 0, PluginToolStatus.completed),
      ("exited", 2, PluginToolStatus.error),
      ("exited", null, PluginToolStatus.unknown),
      ("killed", null, PluginToolStatus.cancelled),
      ("timeout", null, PluginToolStatus.error),
    ]) {
      final result = mapped(
        json: <String, dynamic>{
          "type": "shell",
          "id": "shell-message",
          "shellID": "shell-id",
          "time": <String, int>{"created": 1},
          "command": "printf fixture",
          "status": status,
          "exit": exit,
        },
      );
      expect(result.parts.single.asTool.state.status, expected);
      expect((result.info as PluginMessageAssistant).sender, PluginMessageSender.system);
    }
  });

  test("preserves user attachment order and bounds inline image candidates", () {
    final result = mapped(
      json: <String, dynamic>{
        "type": "user",
        "id": "user",
        "text": "Fixture",
        "time": <String, int>{"created": 1},
        "files": <Object>[
          for (var i = 0; i < 5; i++)
            <String, dynamic>{
              "data": "AQID",
              "mime": "image/png",
              "name": "/fixture/image-$i.png",
              "source": <String, dynamic>{"type": "inline"},
            },
        ],
        "agents": <Object>[
          <String, dynamic>{"name": "explore"},
        ],
      },
    );
    expect(result.info, isA<PluginMessageUser>());
    expect(result.parts.map((part) => part.id), <String>[
      "user:0",
      "user:1",
      "user:2",
      "user:3",
      "user:4",
      "user:5",
      "user:6",
    ]);
    expect(result.parts[1].attachment, isA<PluginMessageAttachmentInlineImage>());
    expect((result.parts[1].attachment as PluginMessageAttachmentInlineImage).filename, "image-0.png");
    expect(result.parts[5].attachment, isA<PluginMessageAttachmentMetadata>());
    expect(result.parts.last.agentName, "Explore");
  });

  test("bounds standalone tool images and excludes local or credentialed URLs", () {
    final result = mapper.mapToolState(
      toolName: "bash",
      state: SessionMessageToolState.fromJson(<String, dynamic>{
        "status": "completed",
        "input": const <String, dynamic>{"command": 42},
        "metadata": const <String, dynamic>{"title": <Object>[]},
        "content": <Object>[
          const <String, dynamic>{"type": "file", "mime": "image/png", "uri": "https://fixture.invalid/image.png"},
          for (var i = 0; i < 5; i++) image(),
          const <String, dynamic>{"type": "file", "mime": "image/png", "uri": "file:///fixture/private.png"},
          const <String, dynamic>{
            "type": "file",
            "mime": "image/png",
            "uri": "https://user:password@fixture.invalid/image.png",
          },
        ],
      }),
    );
    expect(result.attachments.first, isA<PluginMessageAttachmentRemoteUrl>());
    expect(result.attachments.skip(1).take(3), everyElement(isA<PluginMessageAttachmentInlineImage>()));
    expect((result.attachments[1] as PluginMessageAttachmentInlineImage).base64, "AQID");
    expect(result.attachments.skip(4), everyElement(isA<PluginMessageAttachmentMetadata>()));
    expect(result.shellCommand, isNull);
    expect(result.title, isNull);
  });

  test("shares the image count budget across multiple tool parts", () {
    final result = mapped(
      json: assistant(
        content: <Object>[
          for (var i = 0; i < 2; i++)
            <String, dynamic>{
              "type": "tool",
              "id": "tool-$i",
              "name": "read",
              "time": <String, int>{"created": 1},
              "state": <String, dynamic>{
                "status": "completed",
                "input": <String, dynamic>{},
                "content": <Object>[image(), image(), image()],
              },
            },
        ],
      ),
    );
    final attachments = result.parts.expand((part) => part.asTool.state.attachments).toList();
    expect(attachments.whereType<PluginMessageAttachmentInlineImage>(), hasLength(4));
    expect(attachments.whereType<PluginMessageAttachmentMetadata>(), hasLength(2));
  });

  test("enforces decoded byte limits and degrades malformed image data", () {
    PluginMessageWithParts userImages({required String data, required int count}) => mapped(
      json: <String, dynamic>{
        "type": "user",
        "id": "images",
        "text": "Fixture",
        "time": <String, int>{"created": 1},
        "files": <Object>[
          for (var i = 0; i < count; i++)
            <String, dynamic>{
              "mime": "image/png",
              "data": data,
              "source": <String, dynamic>{"type": "inline"},
            },
        ],
      },
    );
    final combined = userImages(data: "AAAA" * (18 * 1024 * 1024 ~/ 3), count: 3);
    expect(combined.parts[1].attachment, isA<PluginMessageAttachmentInlineImage>());
    expect(combined.parts[2].attachment, isA<PluginMessageAttachmentInlineImage>());
    expect(combined.parts[3].attachment, isA<PluginMessageAttachmentMetadata>());
    final oversized = userImages(data: "AAAA" * (maxTranscriptImageBytes ~/ 3 + 1), count: 1);
    expect(oversized.parts[1].attachment, isA<PluginMessageAttachmentMetadata>());
    expect(
      userImages(data: "malformed fixture!", count: 1).parts[1].attachment,
      isA<PluginMessageAttachmentMetadata>(),
    );
  });

  test("omits unsupported messages rather than inventing attribution", () {
    expect(
      mapper.mapMessage(
        sessionId: "session",
        message: SessionMessageInfo.fromJson(const <String, dynamic>{"type": "future"}),
        agentNames: names,
      ),
      isNull,
    );
  });
}
