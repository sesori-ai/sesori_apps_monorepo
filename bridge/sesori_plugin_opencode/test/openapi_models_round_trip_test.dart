// Round-trip, value-semantics, and leniency tests for the GENERATED
// v2 OpenAPI models (lib/src/models/openapi/). These guard the codegen
// pipeline: when `make opencode-codegen` is re-run against a new
// OpenCode tag, these tests fail loudly if decoding, encoding,
// equality, or unknown-value fallback behavior regresses.

import "package:opencode_plugin/src/models/openapi/command.g.dart";
import "package:opencode_plugin/src/models/openapi/part.g.dart";
import "package:opencode_plugin/src/models/openapi/permission_action.g.dart";
import "package:opencode_plugin/src/models/openapi/permission_ruleset.g.dart";
import "package:opencode_plugin/src/models/openapi/project.g.dart";
import "package:opencode_plugin/src/models/openapi/session.g.dart";
import "package:opencode_plugin/src/models/openapi/session_status.g.dart";
import "package:opencode_plugin/src/models/openapi/text_part.g.dart";
import "package:opencode_plugin/src/models/openapi/tool_part.g.dart";
import "package:opencode_plugin/src/models/openapi/tool_state_pending.g.dart";
import "package:test/test.dart";

Map<String, dynamic> sessionJson() => <String, dynamic>{
  "id": "ses_1",
  "slug": "fix-auth",
  "projectID": "prj_1",
  "directory": "/repo",
  "title": "Fix auth flow",
  "version": "1.16.2",
  "time": <String, dynamic>{"created": 100, "updated": 200},
};

Map<String, dynamic> projectJson() => <String, dynamic>{
  "id": "prj_1",
  "worktree": "/repo",
  "time": <String, dynamic>{"created": 10, "updated": 20},
  "sandboxes": <String>["sb-a", "sb-b"],
};

void main() {
  group("Session", () {
    test("decodes inline objects into typed nested classes", () {
      final session = Session.fromJson(sessionJson());

      expect(session.id, "ses_1");
      // `time` must be a synthesized SessionTime, not a raw map.
      expect(session.time, isA<SessionTime>());
      expect(session.time.created, 100);
      expect(session.time.updated, 200);
      expect(session.time.archived, isNull);
    });

    test("round-trips through toJson", () {
      final session = Session.fromJson(sessionJson());
      expect(session.toJson(), equals(sessionJson()));
    });

    test("two decodes of the same JSON are equal (deep equality)", () {
      final a = Session.fromJson(sessionJson());
      final b = Session.fromJson(sessionJson());
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test("sessions with different nested time are not equal", () {
      final a = Session.fromJson(sessionJson());
      final other = sessionJson();
      (other["time"] as Map<String, dynamic>)["updated"] = 999;
      final b = Session.fromJson(other);
      expect(a, isNot(equals(b)));
    });
  });

  group("Project", () {
    test("decodes typed ProjectTime and list fields", () {
      final project = Project.fromJson(projectJson());
      expect(project.time, isA<ProjectTime>());
      expect(project.time.created, 10);
      expect(project.sandboxes, <String>["sb-a", "sb-b"]);
    });

    test("round-trips and compares list fields structurally", () {
      final a = Project.fromJson(projectJson());
      final b = Project.fromJson(projectJson());
      expect(a.toJson(), equals(projectJson()));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group("Command", () {
    test("round-trips required and optional fields", () {
      final json = <String, dynamic>{
        "name": "deploy",
        "template": "deploy {target}",
        "hints": <String>["target"],
      };
      final command = Command.fromJson(json);
      expect(command.name, "deploy");
      expect(command.hints, <String>["target"]);
      expect(command.toJson(), equals(json));
      expect(command, equals(Command.fromJson(json)));
    });
  });

  group("Part union", () {
    test("dispatches on the type discriminator", () {
      final part = Part.fromJson(const <String, dynamic>{
        "type": "text",
        "id": "prt_1",
        "sessionID": "ses_1",
        "messageID": "msg_1",
        "text": "hello",
      });
      expect(part, isA<TextPart>());
      expect((part as TextPart).text, "hello");
    });

    test("decodes tool parts with nested ToolState union", () {
      final part = Part.fromJson(const <String, dynamic>{
        "type": "tool",
        "id": "prt_2",
        "sessionID": "ses_1",
        "messageID": "msg_1",
        "callID": "call_1",
        "tool": "bash",
        "state": <String, dynamic>{
          "status": "pending",
          "input": <String, dynamic>{"command": "ls"},
          "raw": "ls",
        },
      });
      expect(part, isA<ToolPart>());
      final state = (part as ToolPart).state;
      expect(state, isA<ToolStatePending>());
      expect((state as ToolStatePending).raw, "ls");
    });

    test("unknown part types decode to PartUnknown and round-trip raw", () {
      final raw = <String, dynamic>{"type": "hologram", "shape": "cube"};
      final part = Part.fromJson(raw);
      expect(part, isA<PartUnknown>());
      expect(part.toJson(), equals(raw));
    });
  });

  group("SessionStatus union", () {
    test("dispatches known variants", () {
      final status = SessionStatus.fromJson(const <String, dynamic>{"type": "idle"});
      expect(status.toJson(), equals(<String, dynamic>{"type": "idle"}));
    });

    test("unknown status types decode to SessionStatusUnknown", () {
      final raw = <String, dynamic>{"type": "paused", "reason": "lunch"};
      final status = SessionStatus.fromJson(raw);
      expect(status, isA<SessionStatusUnknown>());
      expect(status.toJson(), equals(raw));
    });

    test("unknown variants compare structurally", () {
      final raw = <String, dynamic>{"type": "paused"};
      expect(
        SessionStatus.fromJson(raw),
        equals(
          SessionStatus.fromJson(const <String, dynamic>{"type": "paused"}),
        ),
      );
    });
  });

  group("Generated enums", () {
    test("decode known wire values", () {
      expect(PermissionAction.fromJson("allow"), PermissionAction.allow);
    });

    test("fall back to unknown for new wire values instead of throwing", () {
      expect(PermissionAction.fromJson("trace"), PermissionAction.unknown);
    });

    test("the unknown member encodes as the literal string unknown", () {
      expect(PermissionAction.unknown.toJson(), "unknown");
    });
  });

  group("Array wrapper", () {
    test("PermissionRuleset round-trips a raw JSON array", () {
      final raw = <dynamic>[
        <String, dynamic>{
          "permission": "bash",
          "pattern": "git status",
          "action": "allow",
        },
      ];
      final ruleset = PermissionRuleset.fromJson(raw);
      expect(ruleset.items, hasLength(1));
      expect(ruleset.items.first.pattern, "git status");
      expect(ruleset.toJson(), equals(raw));
      expect(ruleset, equals(PermissionRuleset.fromJson(raw)));
    });
  });
}
