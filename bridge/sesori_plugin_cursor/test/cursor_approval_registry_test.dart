import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorApprovalRegistry", () {
    late FakeAcpProcess fake;
    late AcpStdioClient client;
    late List<BridgeSseEvent> emitted;
    late List<AcpNotification> forwarded;
    late CursorApprovalRegistry registry;
    // The session whose turn is "in flight"; the registry falls back to it for
    // requests that carry no sessionId of their own (e.g. cursor/create_plan).
    String? activeSession;
    // When set, the fire-and-forget forward throws — simulating a bug in the
    // notification mapping path downstream of the registry.
    bool throwOnForward = false;

    setUp(() async {
      fake = FakeAcpProcess();
      client = AcpStdioClient(
        launchSpec: const AcpLaunchSpec(command: "cursor-agent", args: ["acp"]),
        processFactory: (_) async => fake,
      );
      await client.connect();
      emitted = [];
      forwarded = [];
      activeSession = "active-s";
      throwOnForward = false;
      registry = CursorApprovalRegistry(
        client: client,
        emit: emitted.add,
        onFireAndForgetNotification: (notification) {
          if (throwOnForward) throw StateError("notification mapping failure");
          forwarded.add(notification);
        },
        activeSessionResolver: () => activeSession,
      );
      registry.attach(client.serverRequests);
    });

    tearDown(() async {
      await registry.dispose();
      await client.dispose();
      await fake.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test("cursor/ask_question surfaces as a question with options", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "cursor/ask_question",
        "params": {
          "sessionId": "s1",
          "title": "Choose",
          "questions": [
            {
              "id": "q1",
              "prompt": "Pick one",
              "allowMultiple": false,
              "options": [
                {"id": "o1", "label": "Yes"},
                {"id": "o2", "label": "No"},
              ],
            },
          ],
        },
      });
      await pump();

      final asked = emitted.single as BridgeSseQuestionAsked;
      expect(asked.sessionID, "s1");
      expect(asked.displaySessionId, "s1");
      expect(asked.questions.single.question, "Pick one");
      expect(asked.questions.single.header, "Choose");
      expect(
        asked.questions.single.options.map((o) => o.label),
        ["Yes", "No"],
      );

      expect(registry.pendingForSession("s1"), hasLength(1));

      registry.replyQuestion(asked.id, [["Yes"]]);
      final reply = fake.written.last;
      expect(reply["id"], 1);
      final questions = (reply["result"] as Map)["questions"] as List;
      expect((questions.single as Map)["selectedOptionIds"], ["o1"]);
    });

    test("cursor/create_plan surfaces as an accept/reject question", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "cursor/create_plan",
        "params": {"sessionId": "s1", "name": "Plan A", "overview": "Do things"},
      });
      await pump();

      final asked = emitted.single as BridgeSseQuestionAsked;
      expect(asked.questions.single.header, "Plan A");

      registry.replyQuestion(asked.id, [["Accept"]]);
      final reply = fake.written.last;
      expect((reply["result"] as Map)["accepted"], true);
    });

    test("cursor/create_plan with no sessionId is attributed to the active turn", () async {
      // Live cursor-agent sends create_plan with a toolCallId but NO sessionId,
      // so the question must inherit the active turn's session — otherwise it
      // ships with an empty sessionId and the mobile client drops it.
      fake.emit({
        "jsonrpc": "2.0",
        "id": 8,
        "method": "cursor/create_plan",
        "params": {
          "toolCallId": "tc-1",
          "name": "Plan Z",
          "overview": "Do z",
          "todos": <Object?>[],
        },
      });
      await pump();

      final asked = emitted.single as BridgeSseQuestionAsked;
      expect(asked.sessionID, "active-s", reason: "create_plan has no sessionId; falls back to the active turn");
      expect(asked.displaySessionId, "active-s");
      expect(asked.questions.single.header, "Plan Z");
      expect(registry.pendingForSession("active-s"), hasLength(1));
    });

    test("a non-bool allowMultiple does not crash the handler", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 4,
        "method": "cursor/ask_question",
        "params": {
          "sessionId": "s1",
          "questions": [
            {
              "id": "q1",
              "prompt": "Pick",
              "allowMultiple": "yes", // wrong type — must be treated as false
              "options": [
                {"id": "o1", "label": "A"},
              ],
            },
          ],
        },
      });
      await pump();
      final asked = emitted.single as BridgeSseQuestionAsked;
      expect(asked.questions.single.multiple, false);
      expect(registry.pendingForSession("s1"), hasLength(1));
    });

    test("an empty question list is rejected, not registered as blocking", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 5,
        "method": "cursor/ask_question",
        "params": {"sessionId": "s1", "questions": <Object?>[]},
      });
      await pump();
      // No pending question is created, and the agent gets an error reply so it
      // is not left blocked on input that can never be answered.
      expect(emitted, isEmpty);
      expect(registry.pendingForSession("s1"), isEmpty);
      final reply = fake.written.last;
      expect(reply["id"], 5);
      expect(reply.containsKey("error"), isTrue);
    });

    test("ask_question with no resolvable session is rejected, not registered", () async {
      // No sessionId in params and no active turn → resolves to "". A question
      // stamped with "" is dropped by the mobile client, so it must be rejected
      // here rather than left as an invisible pending question that blocks the
      // turn forever.
      activeSession = null;
      fake.emit({
        "jsonrpc": "2.0",
        "id": 8,
        "method": "cursor/ask_question",
        "params": {
          "title": "Choose",
          "questions": [
            {
              "id": "q1",
              "prompt": "Pick one",
              "options": [
                {"id": "o1", "label": "Yes"},
              ],
            },
          ],
        },
      });
      await pump();
      expect(emitted, isEmpty);
      expect(registry.pendingForSession(""), isEmpty);
      final reply = fake.written.last;
      expect(reply["id"], 8);
      expect(reply.containsKey("error"), isTrue);
    });

    test("create_plan with no resolvable session is rejected, not registered", () async {
      activeSession = null;
      fake.emit({
        "jsonrpc": "2.0",
        "id": 9,
        "method": "cursor/create_plan",
        "params": {"name": "Plan", "overview": "Do the thing"},
      });
      await pump();
      expect(emitted, isEmpty);
      expect(registry.pendingForSession(""), isEmpty);
      final reply = fake.written.last;
      expect(reply["id"], 9);
      expect(reply.containsKey("error"), isTrue);
    });

    test("duplicate option labels are disambiguated so the reply maps 1:1", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 10,
        "method": "cursor/ask_question",
        "params": {
          "sessionId": "s1",
          "questions": [
            {
              "id": "q1",
              "prompt": "Pick one",
              "options": [
                {"id": "o1", "label": "Option"},
                {"id": "o2", "label": "Option"},
              ],
            },
          ],
        },
      });
      await pump();
      final pending = registry.pendingForSession("s1").single;
      final labels = pending.questions.single.options.map((o) => o.label).toList();
      expect(labels, ["Option", "Option (2)"],
          reason: "duplicate labels are made unique so label->id stays 1:1");
    });

    test("questions with no usable text are dropped", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 6,
        "method": "cursor/ask_question",
        "params": {
          "sessionId": "s1",
          "questions": [
            {"id": "q1", "prompt": 123}, // non-string prompt -> dropped
          ],
        },
      });
      await pump();
      expect(registry.pendingForSession("s1"), isEmpty);
      expect(fake.written.last.containsKey("error"), isTrue);
    });

    test("standard permission requests still work via the base", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 3,
        "method": "session/request_permission",
        "params": {
          "sessionId": "s1",
          "toolCall": {"kind": "execute", "title": "Run"},
          "options": [
            {"optionId": "ok", "kind": "allow_once"},
          ],
        },
      });
      await pump();
      expect(emitted.single, isA<BridgeSsePermissionAsked>());
    });

    test("cursor/generate_image request is acked and forwarded as a notification", () async {
      // Live cursor-agent calls connection.extMethod("cursor/generate_image", …)
      // which is a JSON-RPC *request* (with id), not a notification — despite the
      // local helper name sendNonBlockingExtensionNotification. The registry
      // acks immediately and re-injects the payload unchanged; mapping happens
      // in CursorEventMapper (see cursor_event_mapper_test.dart).
      fake.emit({
        "jsonrpc": "2.0",
        "id": 42,
        "method": "cursor/generate_image",
        "params": {
          "toolCallId": "img-1",
          "filePath": "/tmp/out.png",
          "description": "test",
        },
      });
      await pump();

      final reply = fake.written.last;
      expect(reply["id"], 42);
      expect(reply["result"], isA<Map<String, Object?>>());
      expect(reply.containsKey("error"), isFalse);
      final forwardedNotification = forwarded.single;
      expect(forwardedNotification.method, "cursor/generate_image");
      expect(forwardedNotification.params["filePath"], "/tmp/out.png");
      expect(forwardedNotification.params.containsKey("sessionId"), isFalse);
    });

    test("cursor/update_todos request is acked and forwarded as a notification", () async {
      fake.emit({
        "jsonrpc": "2.0",
        "id": 43,
        "method": "cursor/update_todos",
        "params": {"toolCallId": "todo-1", "todos": <Object?>[]},
      });
      await pump();

      final reply = fake.written.last;
      expect(reply["id"], 43);
      expect(reply.containsKey("error"), isFalse);
      expect(forwarded.single.method, "cursor/update_todos");
      expect(forwarded.single.params["toolCallId"], "todo-1");
    });

    test("a throwing notification forward never breaks the approval channel", () async {
      // The forward runs on the serverRequests subscription that also answers
      // permissions; a throw in the mapping path must be contained to the one
      // payload — the request is still acked and later approvals still surface.
      throwOnForward = true;
      fake.emit({
        "jsonrpc": "2.0",
        "id": 44,
        "method": "cursor/generate_image",
        "params": {"filePath": "/tmp/out.png"},
      });
      await pump();

      final ack = fake.written.last;
      expect(ack["id"], 44);
      expect(ack.containsKey("error"), isFalse);

      throwOnForward = false;
      fake.emit({
        "jsonrpc": "2.0",
        "id": 45,
        "method": "session/request_permission",
        "params": {
          "sessionId": "s1",
          "toolCall": {"kind": "execute", "title": "Run"},
          "options": [
            {"optionId": "ok", "kind": "allow_once"},
          ],
        },
      });
      await pump();
      expect(emitted.single, isA<BridgeSsePermissionAsked>());
    });
  });
}
