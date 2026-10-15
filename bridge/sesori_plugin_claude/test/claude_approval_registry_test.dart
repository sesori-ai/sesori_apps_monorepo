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

    bool handle({required String sessionId, required ClaudeControlRequestMessage message}) =>
        registry.handle(sessionId: sessionId, message: message);

    test("native URL elicitation exposes only a typed cancel notice in broadcasts", () {
      expect(
        handle(
          sessionId: "session-1",
          message: _urlElicitation(),
        ),
        isTrue,
      );
      final notice = registry.pendingQuestionsForSession(sessionId: "session-1").single;
      expect(notice.interactionKind, PluginQuestionInteractionKind.externalAction);
      expect(notice.questions.single.custom, isFalse);
      expect(notice.questions.single.options.map((option) => option.label), ["Cancel"]);
      expect(notice.toString(), isNot(contains("https://fixture.example")));
      final event = events.whereType<BridgeSseQuestionAsked>().single;
      expect(event.interactionKind, PluginQuestionInteractionKind.externalAction);
      expect(event.questions.toString(), isNot(contains("https://fixture.example")));
      expect(responses, isEmpty);
    });

    for (final choice in PluginExternalActionChoice.values) {
      test("URL ${choice.name} preserves the native request and exact reply", () {
        handle(sessionId: "session-1", message: _urlElicitation());
        final pending = registry.pendingExternalActionsForSession(sessionId: "session-1").single;
        expect(pending.authorizationUrl, "https://fixture.example/setup?private=fixture-only");
        expect(pending.purpose, PluginExternalActionPurpose.authorization);
        expect(pending.choices, PluginExternalActionChoice.values);
        expect(pending.toString(), isNot(contains("https://fixture.example")));
        expect(
          registry.replyExternalAction(id: pending.id, sessionId: "other-session", choice: choice),
          PluginExternalActionReply.alreadySettled,
        );
        expect(responses, isEmpty);
        expect(registry.pendingExternalActionsForSession(sessionId: "session-1"), hasLength(1));
        expect(
          registry.replyExternalAction(id: pending.id, sessionId: "session-1", choice: choice),
          PluginExternalActionReply.accepted,
        );
        expect(responses.single.requestId, "native-url-request");
        expect(responses.single.sessionId, "session-1");
        expect(responses.single.payload, {"action": choice.name});
        expect(registry.pendingExternalActionsForSession(sessionId: "session-1"), isEmpty);
        expect(registry.pendingQuestionsForSession(sessionId: "session-1"), isEmpty);
        expect(
          registry.replyExternalAction(id: pending.id, sessionId: "session-1", choice: choice),
          PluginExternalActionReply.alreadySettled,
        );
        expect(responses, hasLength(1));
      });
    }

    test("failed URL reply remains pending and teardown uses native cancellation", () {
      var available = false;
      registry = ClaudeApprovalRegistry(
        emit: events.add,
        respond: ({required sessionId, required requestId, required payload}) {
          if (!available) return false;
          responses.add((sessionId: sessionId, requestId: requestId, payload: payload));
          return true;
        },
      );
      handle(sessionId: "session-1", message: _urlElicitation());
      events.clear();
      expect(
        registry.replyExternalAction(id: "br-1", sessionId: "session-1", choice: PluginExternalActionChoice.accept),
        PluginExternalActionReply.unavailable,
      );
      expect(registry.pendingExternalActionsForSession(sessionId: "session-1"), hasLength(1));
      expect(events, isEmpty);
      available = true;
      registry.cancelForSession(sessionId: "session-1");
      expect(responses.single.payload, {"action": "cancel"});
      expect(responses.single.requestId, "native-url-request");
      expect(registry.hasPendingInput(sessionId: "session-1"), isFalse);
      expect(events.whereType<BridgeSseQuestionRejected>(), hasLength(1));
    });

    for (final mode in [null, "form"]) {
      test("form mode $mode retains typed fields and only broadcasts a static notice", () {
        handle(
          sessionId: "session-1",
          message: _formElicitation(mode: mode),
        );
        final pending = registry.pendingFormsForSession(sessionId: "session-1").single;
        expect(pending.title, "Fixture server");
        expect(pending.fields, hasLength(5));
        expect(registry.pendingFormsForSession(sessionId: "other"), isEmpty);
        final notice = registry.pendingQuestionsForSession(sessionId: "session-1").single;
        expect(notice.interactionKind, PluginQuestionInteractionKind.form);
        expect(notice.questions.single.custom, isFalse);
        expect(notice.questions.single.options.single.label, "Cancel");
        expect(events.whereType<BridgeSseQuestionAsked>().single.interactionKind, PluginQuestionInteractionKind.form);
        expect(events.toString(), isNot(contains("private-default")));
        expect(notice.toString(), isNot(contains("private-default")));
        expect(responses, isEmpty);
        expect(
          registry.replyQuestion(
            id: pending.id,
            answers: [
              ["true"],
            ],
          ),
          isFalse,
        );
        expect(registry.rejectQuestion(id: pending.id), isFalse);
        expect(registry.replyForm(id: pending.id, sessionId: "other", values: {}), isA<PluginFormAlreadySettled>());
        expect(responses, isEmpty);
        expect(
          registry.replyForm(
            id: pending.id,
            sessionId: "session-1",
            values: {
              "field-0": const PluginFormBooleanValue(value: false),
              "field-1": const PluginFormIntegerValue(value: 0),
              "field-2": const PluginFormChoiceValue(optionId: "option-1"),
              "field-3": PluginFormChoicesValue(optionIds: ["option-0", "option-1"]),
            },
          ),
          isA<PluginFormAccepted>(),
        );
        expect(responses.single.requestId, "native-form");
        expect(responses.single.sessionId, "session-1");
        expect(responses.single.payload, {
          "action": "accept",
          "content": {
            "approved": false,
            "count": 0,
            "plan": "pro",
            "tags": ["a", "b"],
          },
        });
        expect(registry.pendingFormsForSession(sessionId: "session-1"), isEmpty);
        expect(registry.pendingQuestionsForSession(sessionId: "session-1"), isEmpty);
        expect(registry.replyForm(id: pending.id, sessionId: "session-1", values: {}), isA<PluginFormAlreadySettled>());
        expect(events.whereType<BridgeSseQuestionReplied>(), hasLength(1));
      });
    }

    test("form validation and failed writes retain the pending request for correction", () {
      var available = false;
      registry = ClaudeApprovalRegistry(
        emit: events.add,
        respond: ({required sessionId, required requestId, required payload}) {
          if (!available) return false;
          responses.add((sessionId: sessionId, requestId: requestId, payload: payload));
          return true;
        },
      );
      handle(
        sessionId: "session-1",
        message: _formElicitation(mode: "form"),
      );
      final invalid = registry.replyForm(
        id: "br-1",
        sessionId: "session-1",
        values: {
          "field-0": const PluginFormTextValue(value: "false"),
          "field-1": const PluginFormIntegerValue(value: 10),
        },
      ) as PluginFormValidationFailed;
      expect(invalid.fieldErrors, {
        "field-0": PluginFormValidationIssue.invalidType,
        "field-1": PluginFormValidationIssue.outOfRange,
        "field-2": PluginFormValidationIssue.required,
      });
      expect(responses, isEmpty);
      expect(
        registry.replyForm(
          id: "br-1",
          sessionId: "session-1",
          values: {
            "field-0": const PluginFormBooleanValue(value: true),
            "field-1": const PluginFormIntegerValue(value: 1),
            "field-2": const PluginFormChoiceValue(optionId: "option-0"),
          },
        ),
        isA<PluginFormUnavailable>(),
      );
      expect(
        registry.declineForm(id: "br-1", sessionId: "session-1", choice: PluginFormDismissalChoice.cancel),
        PluginFormDismissalResult.unavailable,
      );
      expect(registry.pendingFormsForSession(sessionId: "session-1"), hasLength(1));
      available = true;
      registry.cancelForSession(sessionId: "session-1");
      expect(responses.single.payload, {"action": "cancel"});
      expect(registry.hasPendingInput(sessionId: "session-1"), isFalse);
      expect(events.whereType<BridgeSseQuestionRejected>(), hasLength(1));
    });

    for (final choice in PluginFormDismissalChoice.values) {
      test("form ${choice.name} preserves the exact native negative response", () {
        handle(
          sessionId: "session-1",
          message: _formElicitation(mode: "form"),
        );
        expect(
          registry.declineForm(id: "br-1", sessionId: "other", choice: choice),
          PluginFormDismissalResult.alreadySettled,
        );
        expect(responses, isEmpty);
        expect(
          registry.declineForm(id: "br-1", sessionId: "session-1", choice: choice),
          PluginFormDismissalResult.accepted,
        );
        expect(responses.single.payload, {"action": choice.name});
        expect(
          registry.declineForm(id: "br-1", sessionId: "session-1", choice: choice),
          PluginFormDismissalResult.alreadySettled,
        );
      });
    }

    test("unsupported native schemas are declined with a visible capability explanation", () {
      expect(
        handle(
          sessionId: "session-1",
          message: _request(requestId: "native-form", request: {"subtype": "elicitation", "mode": "form"}),
        ),
        isTrue,
      );
      expect(responses.single.payload, {"action": "decline"});
      expect(events.whereType<BridgeSseTuiToastShow>().single.message, contains("not supported"));
      expect(registry.hasPendingInput(sessionId: "session-1"), isFalse);
    });

    test("verified MCP server context enriches permission detail without changing native grants", () {
      handle(
        sessionId: "session-1",
        message: _request(
          requestId: "permission",
          request: {
            "tool_name": "mcp__fixture__echo",
            "title": "Run echo",
            "input": {},
            "mcp_server": {"name": "\u001b[31mFixture server\u001b[0m", "source": "dynamic"},
          },
        ),
      );
      final permission = registry.pendingPermissionsForSession(sessionId: "session-1").single;
      expect(permission.tool, "mcp__fixture__echo");
      expect(permission.description, "MCP server Fixture server: Run echo");
      expect(registry.replyPermission(id: permission.id, reply: PluginPermissionReply.once), isTrue);
      expect(responses.single.payload, {"behavior": "allow", "updatedInput": <String, Object?>{}});
    });

    test("surfaces a permission with sanitized detail and capability", () {
      expect(
        handle(
          sessionId: "session-1",
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

      final asked = events.whereType<BridgeSsePermissionAsked>().single;
      expect(asked.requestID, "br-1");
      expect(asked.sessionID, "session-1");
      expect(asked.tool, "Write");
      expect(asked.description, "Review this write");
      expect(asked.allowAlways, isFalse);
      final pending = registry.pendingPermissionsForSession(sessionId: "session-1").single;
      expect(pending.allowAlways, isFalse);
    });

    test("once allows only the current input", () {
      handle(sessionId: "session-1", message: _permission());

      expect(registry.replyPermission(id: "br-1", reply: PluginPermissionReply.once), isTrue);

      expect(responses.single.payload, {
        "behavior": "allow",
        "updatedInput": {"file_path": "a.dart"},
      });
      expect(events.whereType<BridgeSsePermissionReplied>(), hasLength(1));
    });

    test("every approval transition invalidates the activity summary", () {
      handle(sessionId: "session-1", message: _permission());
      expect(events.whereType<BridgeSseProjectUpdated>(), hasLength(1));

      expect(registry.replyPermission(id: "br-1", reply: PluginPermissionReply.once), isTrue);
      expect(registry.hasPendingInput(sessionId: "session-1"), isFalse);
      expect(events.whereType<BridgeSseProjectUpdated>(), hasLength(2));
    });

    test("always sends only session-scoped addRules suggestions", () {
      handle(
        sessionId: "session-1",
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
        handle(
          sessionId: "session-1",
          message: _permission(suggestions: [suggestion]),
        );

        registry.replyPermission(id: "br-1", reply: PluginPermissionReply.always);

        expect(responses.single.payload, {
          "behavior": "allow",
          "updatedInput": {"file_path": "a.dart"},
        });
      });
    }

    test("suppressed always degrades safely even if an older client sends it", () {
      handle(
        sessionId: "session-1",
        message: _permission(
          suppressAlways: true,
          suggestions: const [
            {
              "type": "addRules",
              "destination": "session",
              "rules": [
                {"toolName": "Write"},
              ],
            },
          ],
        ),
      );

      registry.replyPermission(id: "br-1", reply: PluginPermissionReply.always);

      expect(responses.single.payload, {
        "behavior": "allow",
        "updatedInput": {"file_path": "a.dart"},
      });
      expect(registry.allowedToolsForSession(sessionId: "session-1"), isEmpty);
    });

    test("AskUserQuestion maps answers by full question text", () {
      handle(
        sessionId: "session-1",
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

      final asked = events.whereType<BridgeSseQuestionAsked>().single;
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
      handle(
        sessionId: "session-1",
        message: _request(
          requestId: "plan-request",
          request: {
            "tool_name": "ExitPlanMode",
            "requires_user_interaction": true,
            "input": {"plan": "# Plan\n\n1. Implement it."},
          },
        ),
      );

      final asked = events.whereType<BridgeSseQuestionAsked>().single;
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
      handle(sessionId: "session-1", message: _permission());
      handle(
        sessionId: "session-1",
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
      expect(
        registry.consumeHandledPermissionDenials(
          sessionId: "session-1",
          denials: const [
            {"tool_use_id": "toolu-permission-request"},
            {"tool_use_id": "toolu-question-request"},
          ],
        ),
        isTrue,
      );
      expect(
        registry.consumeHandledPermissionDenials(
          sessionId: "session-1",
          denials: const [
            {"tool_use_id": "toolu-unprompted"},
          ],
        ),
        isFalse,
      );

      handle(sessionId: "session-1", message: _permission());
      handle(
        sessionId: "session-1",
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
      handle(sessionId: "session-1", message: _permission());
      handle(
        sessionId: "session-2",
        message: _request(
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
      handle(sessionId: "session-1", message: _permission());
      events.clear();

      expect(registry.replyPermission(id: "br-1", reply: PluginPermissionReply.once), isFalse);

      expect(registry.pendingPermissionsForSession(sessionId: "session-1"), hasLength(1));
      expect(events, isEmpty);
    });
  });
}

ClaudeControlRequestMessage _formElicitation({required String? mode}) => _request(
  requestId: "native-form",
  request: {
    "subtype": "elicitation",
    "mode": ?mode,
    "mcp_server_name": "Fixture server",
    "message": "Complete the fixture form",
    "requested_schema": {
      "type": "object",
      "required": ["approved", "count", "plan"],
      "properties": {
        "approved": {"type": "boolean"},
        "count": {"type": "integer", "minimum": 0, "maximum": 3},
        "plan": {
          "type": "string",
          "oneOf": [
            {"const": "basic", "title": "Basic plan"},
            {"const": "pro", "title": "Pro plan"},
          ],
        },
        "tags": {
          "type": "array",
          "minItems": 1,
          "maxItems": 2,
          "items": {
            "type": "string",
            "enum": ["a", "b"],
          },
        },
        "note": {"type": "string", "default": "private-default"},
      },
    },
  },
);

ClaudeControlRequestMessage _urlElicitation() => _request(
  requestId: "native-url-request",
  request: {
    "subtype": "elicitation",
    "mode": "url",
    "mcp_server_name": "Fixture server",
    "message": "Authorize the fixture connection",
    "url": "https://fixture.example/setup?private=fixture-only",
    "elicitation_id": "native-elicitation",
  },
);

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
  required String requestId,
  required Map<String, Object?> request,
}) => ClaudeStreamMessage.parse({
  "type": "control_request",
  "request_id": requestId,
  "request": {
    "subtype": "can_use_tool",
    "tool_use_id": "toolu-$requestId",
    ...request,
  },
}) as ClaudeControlRequestMessage;
