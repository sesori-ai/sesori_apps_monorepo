// Decoding and round-trip tests for the generated OpenCode v2 models
// (lib/src/v2/models/). Payloads follow the OpenCode 2.0.16 wire format.
// They guard the codegen pipeline: regenerating against a new tag must
// keep discriminated unions dispatching to the right variant.

import "package:opencode_plugin/src/v2/models/openapi/form_multiselect_field.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_string_field.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/permission_reply.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/permission_source.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/server_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_inbox_compaction_payload.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_assistant.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_assistant_reasoning.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_assistant_text.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_assistant_tool.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_compaction_completed.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_tool_state_completed.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_user.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_messages_response.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/tool_text_content.g.dart";
import "package:opencode_plugin/src/v2/models/v2_event.g.dart";
import "package:test/test.dart";

const _model = <String, dynamic>{"id": "claude-sonnet-4-5", "providerID": "anthropic"};
const _tokens = <String, dynamic>{
  "input": 1200,
  "output": 340,
  "reasoning": 0,
  "cache": <String, dynamic>{"read": 800, "write": 0},
};

Map<String, dynamic> sessionJson() => <String, dynamic>{
  "id": "ses_01K5ZQ3V9M2E8Y4R6T0W1X2C3D",
  "parentID": "ses_01K5ZQ2A1B2C3D4E5F6G7H8J9K",
  "projectID": "prj_4b1c9e",
  "agent": "build",
  "model": _model,
  "cost": 0.0123,
  "tokens": _tokens,
  "time": <String, dynamic>{"created": 1758800000000, "updated": 1758800100000},
  "title": "Fix login redirect",
  "location": <String, dynamic>{"directory": "/Users/dev/project"},
};

Map<String, dynamic> messagesJson() => <String, dynamic>{
  "data": <Map<String, dynamic>>[
    <String, dynamic>{
      "type": "user",
      "id": "msg_01K5ZQ4A",
      "time": <String, dynamic>{"created": 1758800000000},
      "text": "Fix the login redirect",
    },
    <String, dynamic>{
      "type": "assistant",
      "id": "msg_01K5ZQ4B",
      "time": <String, dynamic>{"created": 1758800001000, "completed": 1758800009000},
      "agent": "build",
      "model": _model,
      "content": <Map<String, dynamic>>[
        <String, dynamic>{"type": "reasoning", "text": "The redirect reads a stale cookie."},
        <String, dynamic>{"type": "text", "text": "I'll check the handler."},
        <String, dynamic>{
          "type": "tool",
          "id": "toolu_01",
          "name": "read",
          "executed": true,
          "state": <String, dynamic>{
            "status": "completed",
            "input": <String, dynamic>{"filePath": "/Users/dev/project/src/login.ts"},
            "content": <Map<String, dynamic>>[
              <String, dynamic>{"type": "text", "text": "export function login() {}"},
            ],
          },
          "time": <String, dynamic>{"created": 1758800002000, "ran": 1758800002100, "completed": 1758800002500},
        },
      ],
      "finish": "stop",
      "cost": 0.01,
      "tokens": _tokens,
    },
    <String, dynamic>{
      "type": "compaction",
      "id": "msg_01K5ZQ4C",
      "time": <String, dynamic>{"created": 1758800010000},
      "status": "completed",
      "reason": "manual",
      "summary": "Fixed the redirect.",
      "recent": "User asked to fix the redirect.",
    },
  ],
  "cursor": <String, dynamic>{"previous": null, "next": "cur_01K5ZQ4D"},
};

void main() {
  test("retains free-form object compaction payloads", () {
    const payload = <String, dynamic>{
      "budget": 100,
      "nested": <String, dynamic>{"keep": true},
      "items": <Object?>["summary", null],
    };
    final decoded = SessionInboxCompactionPayload.fromJson(payload);

    expect(decoded.toJson(), payload);
    expect(SessionInboxCompactionPayload.fromJson(decoded.toJson()!), decoded);
  });

  test("retains nulls in unconstrained compaction arrays", () {
    const payload = <Object?>[
      null,
      "summary",
      <String, dynamic>{"keep": true},
      <Object?>[null],
    ];
    final decoded = SessionInboxCompactionPayload.fromJson(payload);

    expect(decoded.toJson(), payload);
    expect(SessionInboxCompactionPayload.fromJson(decoded.toJson()!), decoded);
  });

  test("preserves unrecognized permission source discriminators", () {
    const payload = <String, dynamic>{"type": "future-source", "context": "value"};
    final source = PermissionSource.fromJson(payload);

    expect(source, isA<PermissionSourceUnknown>());
    expect(source.toJson(), payload);
    expect(
      () => PermissionSource.fromJson(const <String, dynamic>{"type": "tool"}),
      throwsA(isA<TypeError>()),
    );
  });

  test("requires the server identity version", () {
    final payload = <String, dynamic>{
      "version": "2.0.16",
      "pid": 123,
      "urls": <String>["http://127.0.0.1:4096"],
      "paths": <String, dynamic>{"tmp": "/tmp/opencode-fixture"},
    };
    expect(ServerInfo.fromJson(payload).version, "2.0.16");
    payload.remove("version");
    expect(() => ServerInfo.fromJson(payload), throwsA(isA<TypeError>()));
  });

  group("SessionInfo", () {
    test("decodes a 2.0.16 session and round-trips", () {
      final session = SessionInfo.fromJson(sessionJson());

      expect(session.id, "ses_01K5ZQ3V9M2E8Y4R6T0W1X2C3D");
      expect(session.parentID, "ses_01K5ZQ2A1B2C3D4E5F6G7H8J9K");
      expect(session.location.directory, "/Users/dev/project");
      expect(session.model?.providerID, "anthropic");
      expect(session.cost, 0.0123);
      expect(session.tokens.cache.read, 800);
      expect(session.time.created, 1758800000000);
      expect(session.time.archived, isNull);
      expect(SessionInfo.fromJson(session.toJson()), session);
    });
  });

  group("SessionMessagesResponse", () {
    test("dispatches message and assistant content variants", () {
      final response = SessionMessagesResponse.fromJson(messagesJson());

      expect(response.cursor.next, "cur_01K5ZQ4D");
      expect(response.cursor.previous, isNull);
      final [user, assistant, compaction] = response.data;
      expect((user as SessionMessageUser).text, "Fix the login redirect");
      expect((compaction as SessionMessageCompactionCompleted).summary, "Fixed the redirect.");

      final [reasoning, text, tool] = (assistant as SessionMessageAssistant).content;
      expect((reasoning as SessionMessageAssistantReasoning).text, "The redirect reads a stale cookie.");
      expect((text as SessionMessageAssistantText).text, "I'll check the handler.");
      final toolCall = tool as SessionMessageAssistantTool;
      expect(toolCall.id, "toolu_01");
      final state = toolCall.state as SessionMessageToolStateCompleted;
      expect(state.input["filePath"], "/Users/dev/project/src/login.ts");
      expect((state.content.single as ToolTextContent).text, "export function login() {}");
    });

    test("round-trips through toJson", () {
      final response = SessionMessagesResponse.fromJson(messagesJson());

      expect(SessionMessagesResponse.fromJson(response.toJson()), response);
    });

    test("keeps unknown message types as the Unknown variant", () {
      final message = SessionMessageInfo.fromJson(const <String, dynamic>{"type": "future-kind", "id": "msg_x"});

      expect(message, isA<SessionMessageInfoUnknown>());
    });
  });

  group("V2EventData", () {
    test("decodes streaming text and tool events", () {
      final delta = V2EventData.fromJson(<String, dynamic>{
        "type": "session.text.delta",
        "sessionID": "ses_1",
        "assistantMessageID": "msg_2",
        "ordinal": 1,
        "delta": "Hel",
      });
      final success = V2EventData.fromJson(<String, dynamic>{
        "type": "session.tool.success",
        "sessionID": "ses_1",
        "assistantMessageID": "msg_2",
        "id": "toolu_01",
        "content": <Map<String, dynamic>>[
          <String, dynamic>{"type": "text", "text": "ok"},
        ],
        "executed": true,
      });

      expect(delta, isA<V2SessionEventData>());
      expect((delta as V2SessionTextDelta).ordinal, 1);
      expect(delta.delta, "Hel");
      final tool = success as V2SessionToolSuccess;
      expect((tool.content.single as ToolTextContent).text, "ok");
      expect(tool.metadata, isNull);
    });

    test("decodes execution failure, permission and form events", () {
      final failed = V2EventData.fromJson(<String, dynamic>{
        "type": "session.execution.failed",
        "sessionID": "ses_1",
        "error": <String, dynamic>{"type": "provider", "message": "Rate limited", "status": 429},
      });
      final asked = V2EventData.fromJson(<String, dynamic>{
        "type": "permission.asked",
        "id": "per_01",
        "sessionID": "ses_1",
        "action": "bash",
        "resources": <String>["git status"],
        "source": <String, dynamic>{"type": "tool", "messageID": "msg_2", "id": "toolu_02"},
      });
      final replied = V2EventData.fromJson(<String, dynamic>{
        "type": "permission.replied",
        "sessionID": "ses_1",
        "requestID": "per_01",
        "reply": "always",
      });
      final form = V2EventData.fromJson(<String, dynamic>{
        "type": "form.created",
        "form": <String, dynamic>{
          "id": "frm_01",
          "sessionID": "ses_1",
          "title": "Deployment target",
          "fields": <Map<String, dynamic>>[
            <String, dynamic>{
              "type": "string",
              "key": "env",
              "title": "Environment",
              "options": <Map<String, dynamic>>[
                <String, dynamic>{"value": "prod", "label": "Production"},
              ],
              "custom": true,
            },
            <String, dynamic>{
              "type": "multiselect",
              "key": "regions",
              "options": <Map<String, dynamic>>[
                <String, dynamic>{"value": "eu", "label": "Europe"},
                <String, dynamic>{"value": "us", "label": "United States"},
              ],
            },
          ],
        },
      });

      expect((failed as V2SessionExecutionFailed).error.status, 429);
      final permission = asked as V2PermissionAsked;
      expect(permission.resources, <String>["git status"]);
      expect((permission.source as PermissionSource00Inline?)?.id, "toolu_02");
      expect((replied as V2PermissionReplied).reply, PermissionReply.always);
      expect(form, isA<V2SessionEventData>());
      final [env, regions] = (form as V2FormCreated).form.fields.items;
      expect((env as FormStringField).options?.single.label, "Production");
      expect((regions as FormMultiselectField).options.map((option) => option.value), <String>["eu", "us"]);
    });

    test("round-trips an event through toJson", () {
      final event = V2EventData.fromJson(<String, dynamic>{
        "type": "session.created",
        "sessionID": "ses_1",
        "projectID": "prj_1",
        "location": <String, dynamic>{"directory": "/Users/dev/project"},
        "slug": "brave-otter",
        "model": _model,
        "version": "2.0.16",
      });

      final decoded = V2EventData.fromJson(event.toJson()) as V2SessionCreated;
      expect(decoded.location.directory, "/Users/dev/project");
      expect(decoded.model?.id, "claude-sonnet-4-5");
      expect(decoded.parentID, isNull);
    });

    test("rejects unknown event types", () {
      expect(
        () => V2EventData.fromJson(<String, dynamic>{"type": "session.unknown"}),
        throwsFormatException,
      );
    });
  });
}
