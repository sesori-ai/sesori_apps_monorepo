import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ClaudeApprovalRegistry", () {
    late List<BridgeSseEvent> events;
    late List<({String sessionId, String requestId, Map<String, Object?> payload})> responses;
    late ClaudeApprovalRegistry registry;

    setUp(() {
      events = [];
      responses = [];
      registry = ClaudeApprovalRegistry(
        emit: events.add,
        respond: ({required sessionId, required requestId, required payload}) {
          responses.add((sessionId: sessionId, requestId: requestId, payload: payload));
          return true;
        },
      );
    });

    test("surfaces a permission with sanitized detail and capability", () {
      expect(
        registry.handle(
          message: _request(
            requestId: "request-1",
            request: {
              "tool_name": "Write",
              "input": {"file_path": "a.dart"},
              "decision_reason": "\u001b[31mReview this write\u001b[0m",
              "suppress_always_allow_rule": true,
            },
          ),
        ),
        isTrue,
      );

      final asked = events.single as BridgeSsePermissionAsked;
      expect(asked.requestID, "br-1");
      expect(asked.sessionID, "session-1");
      expect(asked.tool, "Write");
      expect(asked.description, "Review this write");
      expect(asked.allowAlways, isFalse);
      final pending = registry.pendingPermissionsForSession(sessionId: "session-1").single;
      expect(pending.allowAlways, isFalse);
    });

    test("once allows only the current input", () {
      registry.handle(message: _permission());

      expect(registry.replyPermission(id: "br-1", reply: PluginPermissionReply.once), isTrue);

      expect(responses.single.payload, {
        "behavior": "allow",
        "updatedInput": {"file_path": "a.dart"},
      });
      expect(events.last, isA<BridgeSsePermissionReplied>());
    });

    test("always sends only session-scoped addRules suggestions", () {
      registry.handle(
        message: _permission(
          suggestions: const [
            {
              "type": "addRules",
              "destination": "session",
              "behavior": "allow",
              "rules": [
                {"toolName": "Write"},
              ],
            },
            {"type": "addRules", "destination": "userSettings", "rules": []},
            {"type": "setMode", "destination": "session", "mode": "acceptEdits"},
          ],
        ),
      );

      registry.replyPermission(id: "br-1", reply: PluginPermissionReply.always);

      expect(responses.single.payload["updatedPermissions"], [
        {
          "type": "addRules",
          "destination": "session",
          "behavior": "allow",
          "rules": [
            {"toolName": "Write"},
          ],
        },
      ]);
      expect(registry.allowedToolsForSession(sessionId: "session-1"), ["Write"]);
    });

    for (final suggestion in const <Map<String, Object?>>[
      {"type": "setMode", "destination": "session"},
      {"type": "addDirectories", "destination": "session"},
      {"type": "removeDirectories", "destination": "session"},
      {"type": "replaceRules", "destination": "session"},
      {"type": "removeRules", "destination": "session"},
      {"type": "addRules", "destination": "userSettings"},
      {"type": "addRules", "destination": "projectSettings"},
      {"type": "addRules", "destination": "localSettings"},
      {"type": "addRules", "destination": "cliArg"},
    ]) {
      test("always rejects ${suggestion["type"]}/${suggestion["destination"]}", () {
        registry.handle(message: _permission(suggestions: [suggestion]));

        registry.replyPermission(id: "br-1", reply: PluginPermissionReply.always);

        expect(responses.single.payload, {
          "behavior": "allow",
          "updatedInput": {"file_path": "a.dart"},
        });
      });
    }

    test("suppressed always degrades safely even if an older client sends it", () {
      registry.handle(
        message: _permission(
          suppressAlways: true,
          suggestions: const [
            {"type": "addRules", "destination": "session", "rules": []},
          ],
        ),
      );

      registry.replyPermission(id: "br-1", reply: PluginPermissionReply.always);

      expect(responses.single.payload, {
        "behavior": "allow",
        "updatedInput": {"file_path": "a.dart"},
      });
    });

    test("AskUserQuestion maps answers by full question text", () {
      registry.handle(
        message: _request(
          requestId: "question-request",
          request: {
            "tool_name": "AskUserQuestion",
            "requires_user_interaction": true,
            "input": {
              "questions": [
                {
                  "question": "Which strategy?",
                  "header": "Strategy",
                  "options": [
                    {"label": "Unit", "description": "Isolated tests"},
                    {"label": "Integration", "description": "Connected tests"},
                  ],
                  "multiSelect": false,
                },
              ],
            },
          },
        ),
      );

      final asked = events.single as BridgeSseQuestionAsked;
      expect(asked.questions.single.question, "Which strategy?");
      expect(asked.questions.single.options.map((option) => option.label), ["Unit", "Integration"]);
      expect(
        registry.replyQuestion(
          id: "br-1",
          answers: const [
            ["Unit"],
          ],
        ),
        isTrue,
      );
      expect(responses.single.payload, {
        "behavior": "allow",
        "updatedInput": {
          "questions": isA<List<Object?>>(),
          "answers": {"Which strategy?": "Unit"},
        },
      });
    });

    test("ExitPlanMode approval preserves the plan input", () {
      registry.handle(
        message: _request(
          requestId: "plan-request",
          request: {
            "tool_name": "ExitPlanMode",
            "requires_user_interaction": true,
            "input": {"plan": "# Plan\n\n1. Implement it."},
          },
        ),
      );

      final asked = events.single as BridgeSseQuestionAsked;
      expect(asked.questions.single.question, contains("Implement it"));
      registry.replyQuestion(
        id: "br-1",
        answers: const [
          ["Approve"],
        ],
      );
      expect(responses.single.payload, {
        "behavior": "allow",
        "updatedInput": {"plan": "# Plan\n\n1. Implement it."},
      });
    });

    test("reject and teardown deny requests and emit clearing events", () {
      registry.handle(message: _permission());
      registry.handle(
        message: _request(
          requestId: "question-request",
          request: {
            "tool_name": "ExitPlanMode",
            "requires_user_interaction": true,
            "input": {"plan": "plan"},
          },
        ),
      );
      events.clear();

      expect(registry.replyPermission(id: "br-1", reply: PluginPermissionReply.reject), isTrue);
      expect(registry.rejectQuestion(id: "br-2"), isTrue);

      expect(responses, hasLength(2));
      expect(responses.every((response) => response.payload["behavior"] == "deny"), isTrue);
      expect(events.whereType<BridgeSsePermissionReplied>(), hasLength(1));
      expect(events.whereType<BridgeSseQuestionRejected>(), hasLength(1));

      registry.handle(message: _permission());
      registry.handle(
        message: _request(
          requestId: "question-request-2",
          request: {
            "tool_name": "ExitPlanMode",
            "requires_user_interaction": true,
            "input": {"plan": "plan"},
          },
        ),
      );
      events.clear();
      responses.clear();

      registry.cancelForSession(sessionId: "session-1");

      expect(responses, hasLength(2));
      expect(registry.pendingPermissionsForSession(sessionId: "session-1"), isEmpty);
      expect(registry.pendingQuestionsForSession(sessionId: "session-1"), isEmpty);
      expect(events.whereType<BridgeSsePermissionReplied>(), hasLength(1));
      expect(events.whereType<BridgeSseQuestionRejected>(), hasLength(1));
    });

    test("dispose cancels pending requests across sessions", () {
      registry.handle(message: _permission());
      registry.handle(
        message: _request(
          sessionId: "session-2",
          requestId: "request-2",
          request: {"tool_name": "Read", "input": <String, Object?>{}},
        ),
      );
      events.clear();

      registry.dispose();

      expect(responses, hasLength(2));
      expect(events.whereType<BridgeSsePermissionReplied>(), hasLength(2));
    });

    test("a failed response remains pending and emits no clearing event", () {
      registry = ClaudeApprovalRegistry(
        emit: events.add,
        respond: ({required sessionId, required requestId, required payload}) => false,
      );
      registry.handle(message: _permission());
      events.clear();

      expect(registry.replyPermission(id: "br-1", reply: PluginPermissionReply.once), isFalse);

      expect(registry.pendingPermissionsForSession(sessionId: "session-1"), hasLength(1));
      expect(events, isEmpty);
    });
  });
}

ClaudeControlRequestMessage _permission({
  List<Map<String, Object?>> suggestions = const [],
  bool suppressAlways = false,
}) => _request(
  requestId: "permission-request",
  request: {
    "tool_name": "Write",
    "description": "Write a.dart",
    "input": {"file_path": "a.dart"},
    "permission_suggestions": suggestions,
    "suppress_always_allow_rule": suppressAlways,
  },
);

ClaudeControlRequestMessage _request({
  String sessionId = "session-1",
  required String requestId,
  required Map<String, Object?> request,
}) =>
    ClaudeStreamMessage.parse({
          "type": "control_request",
          "session_id": sessionId,
          "uuid": "frame-$requestId",
          "request_id": requestId,
          "request": {"subtype": "can_use_tool", ...request},
        })
        as ClaudeControlRequestMessage;
