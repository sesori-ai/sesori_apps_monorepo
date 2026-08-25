import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ACP form elicitations", () {
    late StreamController<AcpServerRequest> requests;
    late List<BridgeSseEvent> emitted;
    late List<(Object, Object?)> responses;
    late List<(Object, int, String)> errors;
    late AcpApprovalRegistry registry;

    setUp(() {
      requests = StreamController<AcpServerRequest>.broadcast();
      emitted = [];
      responses = [];
      errors = [];
      registry = AcpApprovalRegistry(
        emit: emitted.add,
        respond: (id, result) => responses.add((id, result)),
        respondError: (id, code, message) => errors.add((id, code, message)),
      );
      registry.attach(stream: requests.stream);
    });

    tearDown(() async {
      await registry.dispose();
      await requests.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    AcpServerRequest form({
      Object id = 41,
      String? sessionId = "session-1",
      Object? mode = "form",
      required Map<String, Object?> properties,
      List<String> requiredKeys = const [],
    }) => AcpServerRequest(
      id: id,
      method: AcpMethods.elicitationCreate,
      params: {
        "sessionId": ?sessionId,
        "mode": mode,
        "message": "Configure extension",
        "requestedSchema": {
          "type": "object",
          "title": "Extension options",
          "properties": properties,
          if (requiredKeys.isNotEmpty) "required": requiredKeys,
        },
      },
    );

    test("maps enum, boolean, and string fields to typed accepted content", () async {
      final suggested = List.filled(120, "draft ").join();
      requests.add(
        form(
          properties: {
            "strategy": {
              "type": "string",
              "title": "Strategy",
              "enum": ["safe", "fast"],
            },
            "confirm": {
              "type": "boolean",
              "title": "Continue?",
            },
            "notes": {
              "type": "string",
              "title": "Notes",
              "default": suggested,
            },
          },
        ),
      );
      await pump();

      final asked = emitted.single as BridgeSseQuestionAsked;
      expect(asked.sessionID, "session-1");
      expect(asked.questions, hasLength(3));
      expect(asked.questions[0].options.map((option) => option.label), ["safe", "fast"]);
      expect(asked.questions[1].options.map((option) => option.label), ["Yes", "No"]);
      expect(asked.questions[2].custom, isTrue);
      expect(asked.questions[2].options.single.description.length, lessThan(suggested.length));

      expect(
        registry.replyQuestion(
          requestId: asked.id,
          answers: [
            ["fast"],
            ["Yes"],
            ["Use suggested text"],
          ],
        ),
        isTrue,
      );
      expect(responses.single.$2, {
        "action": "accept",
        "content": {
          "strategy": "fast",
          "confirm": true,
          "notes": suggested,
        },
      });
      expect(errors, isEmpty);
    });

    test("maps titled oneOf choices back to their const values", () async {
      requests.add(
        form(
          properties: {
            "plan": {
              "type": "string",
              "oneOf": [
                {"const": "accept", "title": "Approve", "description": "Run it"},
                {"const": "refine", "title": "Approve", "description": "Change it"},
              ],
            },
          },
        ),
      );
      await pump();

      final asked = emitted.single as BridgeSseQuestionAsked;
      expect(asked.questions.single.options.map((option) => option.label), ["Approve", "Approve (2)"]);
      registry.replyQuestion(
        requestId: asked.id,
        answers: [
          ["Approve (2)"],
        ],
      );

      expect(responses.single.$2, {
        "action": "accept",
        "content": {"plan": "refine"},
      });
    });

    test("omits unanswered optional properties", () async {
      requests.add(
        form(
          properties: {
            "first": {"type": "string"},
            "second": {"type": "string"},
          },
        ),
      );
      await pump();
      final asked = emitted.single as BridgeSseQuestionAsked;

      registry.replyQuestion(
        requestId: asked.id,
        answers: [
          ["value"],
          const <String>[],
        ],
      );

      expect(responses.single.$2, {
        "action": "accept",
        "content": {"first": "value"},
      });
    });

    test("declines the form when a required property is unanswered", () async {
      requests.add(
        form(
          properties: {
            "requiredName": {"type": "string"},
            "optionalNote": {"type": "string"},
          },
          requiredKeys: const ["requiredName"],
        ),
      );
      await pump();
      final asked = emitted.single as BridgeSseQuestionAsked;

      registry.replyQuestion(
        requestId: asked.id,
        answers: [
          const <String>[],
          ["optional"],
        ],
      );

      expect(responses.single.$2, const {"action": "decline"});
    });

    test("maps an empty-string enum value through a non-empty label", () async {
      requests.add(
        form(
          properties: {
            "value": {
              "type": "string",
              "enum": [""],
            },
          },
        ),
      );
      await pump();
      final asked = emitted.single as BridgeSseQuestionAsked;
      final label = asked.questions.single.options.single.label;
      expect(label, isNotEmpty);

      registry.replyQuestion(
        requestId: asked.id,
        answers: [
          [label],
        ],
      );
      expect(responses.single.$2, {
        "action": "accept",
        "content": {"value": ""},
      });
    });

    test("declines unsupported modes and property schemas without pending state", () async {
      requests.add(
        form(
          id: 1,
          mode: "url",
          properties: {
            "url": {"type": "string"},
          },
        ),
      );
      requests.add(
        form(
          id: 2,
          properties: {
            "count": {"type": "integer", "default": "private-value"},
          },
        ),
      );
      await pump();

      expect(responses, [
        (1, const {"action": "decline"}),
        (2, const {"action": "decline"}),
      ]);
      expect(emitted, isEmpty);
      expect(registry.pendingForSession(sessionId: "session-1"), isEmpty);
    });

    test("cancels a form that has no resolvable session", () async {
      requests.add(
        form(
          sessionId: null,
          properties: {
            "name": {"type": "string"},
          },
        ),
      );
      await pump();

      expect(responses.single.$2, const {"action": "cancel"});
      expect(emitted, isEmpty);
    });

    test("cancels a form with a non-string session id", () async {
      await registry.dispose();
      registry = AcpApprovalRegistry(
        emit: emitted.add,
        respond: (id, result) => responses.add((id, result)),
        respondError: (id, code, message) => errors.add((id, code, message)),
        activeSessionResolver: () => "active-session",
      );
      registry.attach(stream: requests.stream);

      requests.add(
        const AcpServerRequest(
          id: 42,
          method: AcpMethods.elicitationCreate,
          params: {
            "sessionId": 7,
            "mode": "form",
            "requestedSchema": {
              "type": "object",
              "properties": {
                "name": {"type": "string"},
              },
            },
          },
        ),
      );
      await pump();

      expect(responses.single, (42, const {"action": "cancel"}));
      expect(emitted, isEmpty);
    });

    test("attributes a sessionless form to the active turn", () async {
      await registry.dispose();
      registry = AcpApprovalRegistry(
        emit: emitted.add,
        respond: (id, result) => responses.add((id, result)),
        respondError: (id, code, message) => errors.add((id, code, message)),
        activeSessionResolver: () => "active-session",
      );
      registry.attach(stream: requests.stream);

      requests.add(
        form(
          sessionId: null,
          properties: {
            "name": {"type": "string"},
          },
        ),
      );
      await pump();

      expect((emitted.single as BridgeSseQuestionAsked).sessionID, "active-session");
    });

    test("reject declines while abort and disposal cancel", () async {
      Future<String> ask({required Object id}) async {
        requests.add(
          form(
            id: id,
            properties: {
              "name": {"type": "string"},
            },
          ),
        );
        await pump();
        return emitted.whereType<BridgeSseQuestionAsked>().last.id;
      }

      final rejected = await ask(id: 1);
      registry.rejectQuestion(requestId: rejected);
      expect(responses.last.$2, const {"action": "decline"});

      final aborted = await ask(id: 2);
      registry.cancelForSession(sessionId: "session-1");
      expect(responses.last.$2, const {"action": "cancel"});
      expect(registry.replyQuestion(requestId: aborted, answers: const []), isFalse);

      await ask(id: 3);
      await registry.dispose();
      expect(responses.last.$2, const {"action": "cancel"});
      expect(emitted.whereType<BridgeSseQuestionRejected>(), hasLength(3));
    });
  });
}
