// ignore_for_file: cast_nullable_to_non_nullable

import "dart:async";

import "package:codex_plugin/codex_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ApprovalRegistry", () {
    late StreamController<CodexServerRequest> requests;
    late List<BridgeSseEvent> emitted;
    late List<_RespondCall> respondCalls;
    late List<_RespondError> errorCalls;
    late ApprovalRegistry registry;

    setUp(() {
      requests = StreamController<CodexServerRequest>.broadcast();
      emitted = [];
      respondCalls = [];
      errorCalls = [];
      registry = ApprovalRegistry(
        emit: emitted.add,
        respond: (id, result) => respondCalls.add(_RespondCall(id, result)),
        respondError: (id, code, message) =>
            errorCalls.add(_RespondError(id, code, message)),
      );
      registry.attach(requests.stream);
    });

    tearDown(() async {
      await registry.dispose();
      await requests.close();
    });

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test(
      "execCommandApproval surfaces as BridgeSsePermissionAsked(tool=exec)",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 42,
            method: "execCommandApproval",
            params: {
              "conversationId": "t-1",
              "callId": "c-1",
              "command": ["rm", "-rf", "/tmp/scratch"],
              "cwd": "/repo/app",
              "reason": "delete scratch dir",
              "parsedCmd": <Object?>[],
            },
          ),
        );
        await pump();

        expect(emitted, hasLength(1));
        final event = emitted.single as BridgeSsePermissionAsked;
        expect(event.tool, equals("exec"));
        expect(event.sessionID, equals("t-1"));
        expect(event.description, equals("delete scratch dir"));
        expect(event.requestID, isNotEmpty);
      },
    );

    test(
      "applyPatchApproval surfaces as BridgeSsePermissionAsked(tool=patch)",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 43,
            method: "applyPatchApproval",
            params: {
              "conversationId": "t-2",
              "callId": "c-2",
              "fileChanges": {
                "/repo/app/foo.dart": {"op": "edit"},
              },
              "reason": null,
              "grantRoot": null,
            },
          ),
        );
        await pump();

        final event = emitted.single as BridgeSsePermissionAsked;
        expect(event.tool, equals("patch"));
        expect(event.sessionID, equals("t-2"));
        expect(event.description, contains("/repo/app/foo.dart"));
      },
    );

    test(
      "replyPermission(once) responds with approved decision and emits replied",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 100,
            method: "execCommandApproval",
            params: {
              "conversationId": "t-1",
              "callId": "c-1",
              "command": ["ls"],
              "cwd": "/repo",
              "reason": "list files",
              "parsedCmd": <Object?>[],
            },
          ),
        );
        await pump();
        final askedId = (emitted.single as BridgeSsePermissionAsked).requestID;
        emitted.clear();

        final ok = registry.replyPermission(askedId, PluginPermissionReply.once);
        expect(ok, isTrue);
        expect(respondCalls, hasLength(1));
        expect(respondCalls.single.id, equals(100));
        expect(
          (respondCalls.single.result as Map)["decision"],
          equals("approved"),
        );
        expect(emitted.single, isA<BridgeSsePermissionReplied>());
      },
    );

    test("replyPermission(always) maps to approved_for_session", () async {
      requests.add(
        const CodexServerRequest(
          id: 101,
          method: "applyPatchApproval",
          params: {
            "conversationId": "t-1",
            "callId": "c-1",
            "fileChanges": <String, Object?>{},
            "reason": null,
            "grantRoot": null,
          },
        ),
      );
      await pump();
      final askedId = (emitted.single as BridgeSsePermissionAsked).requestID;

      registry.replyPermission(askedId, PluginPermissionReply.always);
      expect(
        (respondCalls.single.result as Map)["decision"],
        equals("approved_for_session"),
      );
    });

    test("replyPermission(reject) maps to denied", () async {
      requests.add(
        const CodexServerRequest(
          id: 102,
          method: "execCommandApproval",
          params: {
            "conversationId": "t-1",
            "callId": "c-1",
            "command": ["whoami"],
            "cwd": "/repo",
            "reason": null,
            "parsedCmd": <Object?>[],
          },
        ),
      );
      await pump();
      final askedId = (emitted.single as BridgeSsePermissionAsked).requestID;

      registry.replyPermission(askedId, PluginPermissionReply.reject);
      expect(
        (respondCalls.single.result as Map)["decision"],
        equals("denied"),
      );
    });

    test(
      "replyPermission for an unknown id returns false and emits nothing",
      () {
        final ok = registry.replyPermission(
          "br-bogus",
          PluginPermissionReply.once,
        );
        expect(ok, isFalse);
        expect(respondCalls, isEmpty);
      },
    );

    test(
      "elicitation surfaces as BridgeSseQuestionAsked and is visible in pending",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 200,
            method: "mcpServerElicitationRequest",
            params: {
              "threadId": "t-3",
              "serverName": "filesystem-mcp",
              "mode": "form",
              "message": "Where should I write the result?",
              "requestedSchema": {"type": "string"},
            },
          ),
        );
        await pump();

        final asked = emitted.single as BridgeSseQuestionAsked;
        expect(asked.sessionID, equals("t-3"));

        final pending = registry.pendingForSession("t-3");
        expect(pending, hasLength(1));
        expect(pending.single.id, equals(asked.id));
      },
    );

    test("replyQuestion responds with an answers payload", () async {
      requests.add(
        const CodexServerRequest(
          id: 201,
          method: "toolRequestUserInput",
          params: {"threadId": "t-3", "prompt": "Name?"},
        ),
      );
      await pump();
      final askedId = (emitted.single as BridgeSseQuestionAsked).id;

      final ok = registry.replyQuestion(askedId, const [
        ["Daniil"],
      ]);
      expect(ok, isTrue);
      expect(respondCalls.single.id, equals(201));
      expect(
        ((respondCalls.single.result as Map)["answers"] as List).first,
        equals(["Daniil"]),
      );
    });

    test("rejectQuestion sends an error response to codex", () async {
      requests.add(
        const CodexServerRequest(
          id: 202,
          method: "toolRequestUserInput",
          params: {"threadId": "t-3"},
        ),
      );
      await pump();
      final askedId = (emitted.single as BridgeSseQuestionAsked).id;

      final ok = registry.rejectQuestion(askedId);
      expect(ok, isTrue);
      expect(respondCalls, isEmpty);
      expect(errorCalls.single.id, equals(202));
    });

    test(
      "unhandled method gets a -32601 error so codex doesn't hang",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 999,
            method: "bridge/somethingNew",
            params: <String, Object?>{},
          ),
        );
        await pump();
        expect(emitted, isEmpty);
        expect(errorCalls.single.code, equals(-32601));
      },
    );

    test(
      "dispose denies every pending approval so codex isn't left waiting",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 300,
            method: "execCommandApproval",
            params: {
              "conversationId": "t-1",
              "callId": "c-1",
              "command": ["ls"],
              "cwd": "/repo",
              "reason": null,
              "parsedCmd": <Object?>[],
            },
          ),
        );
        await pump();
        respondCalls.clear();

        await registry.dispose();
        expect(respondCalls, hasLength(1));
        expect(
          (respondCalls.single.result as Map)["decision"],
          equals("denied"),
        );
      },
    );
  });
}

class _RespondCall {
  _RespondCall(this.id, this.result);
  final Object id;
  final Object? result;
}

class _RespondError {
  _RespondError(this.id, this.code, this.message);
  final Object id;
  final int code;
  final String message;
}
