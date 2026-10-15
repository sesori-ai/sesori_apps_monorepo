import "package:codex_plugin/src/api/models/codex_pending_input.dart";
import "package:codex_plugin/src/api/parsers/codex_question_parser.dart";
import "package:codex_plugin/src/approval_registry.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/mappers/codex_form_schema.dart";
import "package:codex_plugin/src/repositories/mappers/codex_question_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _schema = {
  "type": "object",
  "properties": {
    "native_text": {"type": "string", "default": "private-default", "minLength": 1, "maxLength": 30},
    "native_integer": {"type": "integer", "minimum": 1.0, "maximum": 3.0},
    "native_number": {"type": "number", "minimum": 0, "maximum": 2},
    "native_boolean": {"type": "boolean"},
    "native_choice": {
      "type": "string",
      "oneOf": [
        {"const": "private-choice", "title": "Visible label"},
      ],
    },
    "native_choices": {
      "type": "array",
      "items": {
        "type": "string",
        "enum": ["private-a", "private-b"],
      },
      "minItems": 1,
    },
  },
  "required": ["native_integer"],
};

void main() {
  late ApprovalRegistry registry;
  late List<BridgeSseEvent> events;
  late List<({Object id, Object? result})> replies;
  setUp(() {
    events = [];
    replies = [];
    registry = ApprovalRegistry(
      emit: events.add,
      respond: (id, result) => replies.add((id: id, result: result)),
      respondError: (id, code, message) => fail("Unexpected RPC error $code"),
      sendAsyncAnswer: ({required sessionId, required text}) async => fail("No model turn"),
      resolvePendingInputScope: ({required sessionId}) => (
        displaySessionId: "parent",
        sourceSessionIds: sessionId == "parent" ? ["child"] : [sessionId],
      ),
      questionParser: const CodexQuestionParser(),
      questionMapper: const CodexQuestionMapper(),
    );
  });
  tearDown(() => registry.dispose());

  void request({String mode = "form", Object? schema = _schema, int id = 8}) => registry.handleRequest(
    CodexPendingRequest(
      request: CodexServerRequest(
        id: id,
        method: "mcpServer/elicitation/request",
        params: {
          "threadId": "child",
          "turnId": "turn",
          "serverName": "fixture",
          "message": "Fixture request",
          "mode": mode,
          if (mode == "form") "requestedSchema": schema,
          if (mode == "url") ...{"url": "https://fixture.example/setup?private=secret", "elicitationId": "native-only"},
        },
      ),
    ),
  );

  test("typed snapshot retains draft metadata while SSE carries only cancel notice", () {
    request();
    final notice = events.single as BridgeSseQuestionAsked;
    expect(notice.interactionKind, PluginQuestionInteractionKind.form);
    expect(notice.questions.single.custom, isFalse);
    expect(notice.questions.single.options.single.label, "Cancel");
    expect(notice.toString(), isNot(contains("private-default")));
    final form = registry.pendingFormsForSession(sessionId: "parent").single;
    expect(form.sessionID, "child");
    expect(form.displaySessionId, "parent");
    expect((form.fields.first.schema as PluginFormTextSchema).defaultValue, "private-default");
    expect(registry.pendingFormsForSession(sessionId: "foreign"), isEmpty);
    expect(registry.pendingNativeTurnIdForSession(sessionId: "child"), "turn");
  });

  test("typed replies preserve native scalar types, property keys and choice values", () {
    request();
    final form = registry.pendingFormsForSession(sessionId: "child").single;
    final result = registry.replyForm(
      requestId: form.id,
      sessionId: "child",
      values: {
        "field-0": const PluginFormTextValue(value: "typed text"),
        "field-1": const PluginFormIntegerValue(value: 2),
        "field-2": const PluginFormNumberValue(value: 1.5),
        "field-3": const PluginFormBooleanValue(value: false),
        "field-4": const PluginFormChoiceValue(optionId: "option-0"),
        "field-5": PluginFormChoicesValue(optionIds: ["option-1"]),
      },
    );
    expect(result, isA<PluginFormAccepted>());
    expect(replies.single.id, 8);
    expect(replies.single.result, {
      "action": "accept",
      "content": {
        "native_text": "typed text",
        "native_integer": 2,
        "native_number": 1.5,
        "native_boolean": false,
        "native_choice": "private-choice",
        "native_choices": ["private-b"],
      },
    });
    expect(registry.pendingForSession(sessionId: "child"), isEmpty);
    expect(registry.pendingNativeTurnIdForSession(sessionId: "child"), isNull);
    expect(
      registry.replyForm(requestId: form.id, sessionId: "child", values: const {}),
      isA<PluginFormAlreadySettled>(),
    );
    expect(replies, hasLength(1));
  });

  test("validation preserves the pending form and optional omission stays absent", () {
    request();
    final id = registry.pendingFormsForSession(sessionId: "child").single.id;
    expect(registry.replyForm(requestId: id, sessionId: "foreign", values: const {}), isA<PluginFormAlreadySettled>());
    for (final values in [
      <String, PluginFormValue>{},
      {"field-1": const PluginFormTextValue(value: "2")},
      {"field-1": const PluginFormIntegerValue(value: 4)},
      {"field-1": const PluginFormIntegerValue(value: 2), "field-4": const PluginFormChoiceValue(optionId: "forged")},
    ]) {
      expect(registry.replyForm(requestId: id, sessionId: "child", values: values), isA<PluginFormValidationFailed>());
      expect(registry.hasPendingInput(sessionId: "child"), isTrue);
      expect(replies, isEmpty);
    }
    expect(
      registry.replyForm(
        requestId: id,
        sessionId: "child",
        values: const {
          "field-1": PluginFormIntegerValue(value: 2),
        },
      ),
      isA<PluginFormAccepted>(),
    );
    expect(replies.single.result, {
      "action": "accept",
      "content": {"native_integer": 2},
    });
  });

  for (final choice in PluginFormDismissalChoice.values) {
    test("native form $choice sends exact action once", () {
      request();
      final id = registry.pendingFormsForSession(sessionId: "child").single.id;
      expect(
        registry.declineForm(requestId: id, sessionId: "foreign", choice: choice),
        PluginFormDismissalResult.alreadySettled,
      );
      expect(
        registry.declineForm(requestId: id, sessionId: "child", choice: choice),
        PluginFormDismissalResult.accepted,
      );
      expect(replies.single.result, {"action": choice.name});
      expect(events.last, isA<BridgeSseQuestionRejected>());
    });
  }

  for (final choice in PluginExternalActionChoice.values) {
    test("URL $choice retains destination only in exact request snapshot", () {
      request(mode: "url");
      final notice = events.single as BridgeSseQuestionAsked;
      expect(notice.interactionKind, PluginQuestionInteractionKind.externalAction);
      expect(notice.toString(), isNot(contains("secret")));
      final action = registry.pendingExternalActionsForSession(sessionId: "parent").single;
      expect(action.authorizationUrl, contains("private=secret"));
      expect(
        registry.replyExternalAction(requestId: action.id, sessionId: "foreign", choice: choice),
        PluginExternalActionReply.alreadySettled,
      );
      expect(
        registry.replyExternalAction(requestId: action.id, sessionId: "child", choice: choice),
        PluginExternalActionReply.accepted,
      );
      expect(replies.single.result, {"action": choice.name});
      expect(registry.pendingExternalActionsForSession(sessionId: "parent"), isEmpty);
    });
  }

  for (final mode in ["form", "url"]) {
    test("legacy reply and cancellation retire the same $mode owner", () async {
      request(mode: mode);
      final id = registry.pendingForSession(sessionId: "child").single.id;
      expect(registry.cancelLegacyMcpRequest(requestId: id, sessionId: "foreign"), isFalse);
      expect(
        await registry.replyQuestion(
          requestId: id,
          answers: const [
            ["Accept"],
          ],
        ),
        isTrue,
      );
      expect(replies.single.result, {"action": "cancel"});
      request(mode: mode, id: 9);
      registry.cancelForSession(sessionId: "child");
      expect(replies.last.id, 9);
      expect(replies.last.result, {"action": "cancel"});
      request(mode: mode, id: 10);
      await registry.dispose();
      expect(replies.last.id, 10);
      expect(replies.last.result, {"action": "cancel"});
      expect(registry.hasAnyPendingInput, isFalse);
    });
  }

  test("unsupported schema and unknown mode explicitly decline instead of generic text fallback", () {
    for (final schema in [
      null,
      {"type": "string"},
      {
        "type": "object",
        "properties": {
          "secret": {"type": "string", "format": "email"},
        },
      },
    ]) {
      request(schema: schema);
      expect(replies.last.result, {"action": "decline"});
      expect(events.last, isA<BridgeSseTuiToastShow>());
      expect((events.last as BridgeSseTuiToastShow).sessionID, "parent");
      expect(registry.hasAnyPendingInput, isFalse);
    }
    request(mode: "future");
    expect(replies.last.result, {"action": "decline"});
  });

  test("malformed requests without a session retain a global warning", () {
    registry.handleRequest(
      const CodexPendingRequest(
        request: CodexServerRequest(id: 8, method: "mcpServer/elicitation/request", params: {}),
      ),
    );
    expect(replies.single.result, {"action": "decline"});
    expect((events.single as BridgeSseTuiToastShow).sessionID, isNull);
  });

  test("ambiguous field and option labels decline without creating a pending owner", () {
    for (final properties in [
      {
        "a": {"type": "string", "title": "Same"},
        "b": {"type": "boolean", "title": "Same"},
      },
      for (final representation in ["oneOf", "anyOf"])
        {
          "choice": {
            "type": representation == "oneOf" ? "string" : "array",
            if (representation == "oneOf")
              "oneOf": [
                {"const": "a", "title": "Same", "description": "Same description"},
                {"const": "b", "title": "Same", "description": "Same description"},
              ]
            else
              "items": {
                "anyOf": [
                  {"const": "a", "title": "Same"},
                  {"const": "b", "title": "Same"},
                ],
              },
          },
        },
    ]) {
      request(schema: {"type": "object", "properties": properties});
      expect(replies.last.result, {"action": "decline"});
      expect((events.last as BridgeSseTuiToastShow).sessionID, "parent");
      expect(registry.hasAnyPendingInput, isFalse);
    }
  });

  test("legacy titled enums preserve display names and encode native values", () {
    CodexFormSchema? parse({required Object? names}) => CodexFormSchema.parse(
      schema: {
        "type": "object",
        "properties": {
          "plan": {
            "type": "string",
            "enum": ["basic", "pro"],
            "enumNames": names,
            "default": "pro",
          },
        },
      },
    );
    final form = parse(names: ["Basic plan", "Pro plan"])!;
    final choice = form.fields.single.schema as PluginFormChoiceSchema;
    expect(choice.options.map((option) => option.label), ["Basic plan", "Pro plan"]);
    expect(choice.defaultOptionId, "option-1");
    expect(form.encode(values: const {"field-0": PluginFormChoiceValue(optionId: "option-1")}), {"plan": "pro"});
    expect((parse(names: null)!.fields.single.schema as PluginFormChoiceSchema).options.first.label, "basic");
    for (final names in [
      <String>[],
      ["Only one"],
      ["Same", "Same"],
      [1, 2],
      "wrong",
    ]) {
      expect(parse(names: names), isNull);
    }
  });

  test("schema bounds, unknown fields and invalid defaults fail explicitly", () {
    final schema = CodexFormSchema.parse(schema: _schema)!;
    expect(
      schema.validate(values: const {"foreign": PluginFormBooleanValue(value: true)}),
      containsPair("foreign", PluginFormValidationIssue.invalidChoice),
    );
    expect(
      schema.validate(
        values: {
          "field-1": const PluginFormIntegerValue(value: 1),
          "field-2": const PluginFormNumberValue(value: double.nan),
        },
      ),
      containsPair("field-2", PluginFormValidationIssue.outOfRange),
    );
    expect(
      CodexFormSchema.parse(
        schema: {
          "type": "object",
          "properties": {
            "n": {"type": "integer", "default": 4, "maximum": 3},
          },
        },
      ),
      isNull,
    );
  });

  test("native fractional integer bounds constrain the available integral values", () {
    final form = CodexFormSchema.parse(
      schema: {
        "type": "object",
        "properties": {
          "count": {"type": "integer", "minimum": 1.5, "maximum": 3.5, "default": 2.0},
        },
      },
    )!;
    final schema = form.fields.single.schema as PluginFormIntegerSchema;
    expect((schema.minimum, schema.maximum, schema.defaultValue), (2, 3, 2));
    expect(
      form.validate(values: const {"field-0": PluginFormIntegerValue(value: 1)}),
      containsPair("field-0", PluginFormValidationIssue.outOfRange),
    );
    expect(form.validate(values: const {"field-0": PluginFormIntegerValue(value: 2)}), isEmpty);
    expect(form.encode(values: const {"field-0": PluginFormIntegerValue(value: 2)}), {"count": 2});
  });

  test("integral JSON count constraints retain text and choice array validation", () {
    final form = CodexFormSchema.parse(
      schema: {
        "type": "object",
        "properties": {
          "note": {"type": "string", "minLength": 2.0, "maxLength": 3.0},
          "tags": {
            "type": "array",
            "minItems": 1.0,
            "maxItems": 2.0,
            "items": {
              "anyOf": [
                {"const": "native-a", "title": "Visible A"},
                {"const": "native-b", "title": "Visible B"},
              ],
            },
          },
        },
      },
    )!;
    final choices = form.fields.last.schema as PluginFormChoicesSchema;
    expect(choices.options.map((option) => option.label), ["Visible A", "Visible B"]);
    expect(
      form.validate(
        values: {
          "field-0": const PluginFormTextValue(value: "a"),
          "field-1": PluginFormChoicesValue(optionIds: []),
        },
      ),
      {"field-0": PluginFormValidationIssue.invalidLength, "field-1": PluginFormValidationIssue.invalidLength},
    );
    final values = {
      "field-0": const PluginFormTextValue(value: "ok"),
      "field-1": PluginFormChoicesValue(optionIds: ["option-1"]),
    };
    expect(form.validate(values: values), isEmpty);
    expect(form.encode(values: values), {
      "note": "ok",
      "tags": ["native-b"],
    });
    for (final count in [-1, 1.5, double.nan]) {
      expect(
        CodexFormSchema.parse(
          schema: {
            "type": "object",
            "properties": {
              "text": {"type": "string", "minLength": count},
            },
          },
        ),
        isNull,
      );
    }
    expect(
      CodexFormSchema.parse(
        schema: {
          "type": "object",
          "properties": {
            "choice": {
              "type": "string",
              "anyOf": [
                {"const": "a"},
              ],
            },
          },
        },
      ),
      isNull,
    );
  });
}
