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

    // --- v2 command-execution approval (the live turn/start path) ---

    test(
      "item/commandExecution/requestApproval surfaces as PermissionAsked(tool=exec)",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 42,
            method: "item/commandExecution/requestApproval",
            params: {
              "threadId": "t-1",
              "turnId": "turn-1",
              "itemId": "i-1",
              "startedAtMs": 0,
              "command": "rm -rf /tmp/scratch",
              "reason": "delete scratch dir",
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
      "command approval falls back to the command string when reason is absent",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 43,
            method: "item/commandExecution/requestApproval",
            params: {
              "threadId": "t-1",
              "turnId": "turn-1",
              "itemId": "i-1",
              "startedAtMs": 0,
              "command": "ls -la",
            },
          ),
        );
        await pump();
        expect(
          (emitted.single as BridgeSsePermissionAsked).description,
          equals("ls -la"),
        );
      },
    );

    test(
      "item/fileChange/requestApproval surfaces as PermissionAsked(tool=patch)",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 44,
            method: "item/fileChange/requestApproval",
            params: {
              "threadId": "t-2",
              "turnId": "turn-1",
              "itemId": "i-2",
              "startedAtMs": 0,
              "reason": "write foo.dart",
            },
          ),
        );
        await pump();
        final event = emitted.single as BridgeSsePermissionAsked;
        expect(event.tool, equals("patch"));
        expect(event.sessionID, equals("t-2"));
        expect(event.description, equals("write foo.dart"));
      },
    );

    test("replyPermission(once) sends the v2 'accept' decision", () async {
      requests.add(
        const CodexServerRequest(
          id: 100,
          method: "item/commandExecution/requestApproval",
          params: {
            "threadId": "t-1",
            "turnId": "turn-1",
            "itemId": "i-1",
            "startedAtMs": 0,
            "command": "ls",
          },
        ),
      );
      await pump();
      final askedId = (emitted.single as BridgeSsePermissionAsked).requestID;
      emitted.clear();

      final ok = registry.replyPermission(askedId, PluginPermissionReply.once);
      expect(ok, isTrue);
      expect(respondCalls.single.id, equals(100));
      expect((respondCalls.single.result as Map)["decision"], equals("accept"));
      expect(emitted.single, isA<BridgeSsePermissionReplied>());
    });

    test("replyPermission(always) sends 'acceptForSession'", () async {
      requests.add(
        const CodexServerRequest(
          id: 101,
          method: "item/fileChange/requestApproval",
          params: {
            "threadId": "t-1",
            "turnId": "turn-1",
            "itemId": "i-1",
            "startedAtMs": 0,
          },
        ),
      );
      await pump();
      final askedId = (emitted.single as BridgeSsePermissionAsked).requestID;

      registry.replyPermission(askedId, PluginPermissionReply.always);
      expect(
        (respondCalls.single.result as Map)["decision"],
        equals("acceptForSession"),
      );
    });

    test("replyPermission(reject) sends 'decline'", () async {
      requests.add(
        const CodexServerRequest(
          id: 102,
          method: "item/commandExecution/requestApproval",
          params: {
            "threadId": "t-1",
            "turnId": "turn-1",
            "itemId": "i-1",
            "startedAtMs": 0,
            "command": "whoami",
          },
        ),
      );
      await pump();
      final askedId = (emitted.single as BridgeSsePermissionAsked).requestID;

      registry.replyPermission(askedId, PluginPermissionReply.reject);
      expect(
        (respondCalls.single.result as Map)["decision"],
        equals("decline"),
      );
    });

    // --- v2 permissions escalation (decision-less; grants a profile) ---

    test(
      "item/permissions/requestApproval grants the requested profile on approve",
      () async {
        const requested = {
          "fileSystem": {"writableRoots": <String>["/repo"]},
        };
        requests.add(
          const CodexServerRequest(
            id: 110,
            method: "item/permissions/requestApproval",
            params: {
              "threadId": "t-1",
              "turnId": "turn-1",
              "itemId": "i-1",
              "startedAtMs": 0,
              "cwd": "/repo",
              "permissions": requested,
              "reason": "needs write access",
            },
          ),
        );
        await pump();
        final event = emitted.single as BridgeSsePermissionAsked;
        expect(event.tool, equals("permissions"));

        registry.replyPermission(event.requestID, PluginPermissionReply.always);
        final result = respondCalls.single.result as Map;
        expect(result["permissions"], equals(requested));
        expect(result["scope"], equals("session"));
        expect(result.containsKey("decision"), isFalse);
      },
    );

    test(
      "item/permissions/requestApproval grants nothing on reject",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 111,
            method: "item/permissions/requestApproval",
            params: {
              "threadId": "t-1",
              "turnId": "turn-1",
              "itemId": "i-1",
              "startedAtMs": 0,
              "cwd": "/repo",
              "permissions": {"network": true},
            },
          ),
        );
        await pump();
        final askedId = (emitted.single as BridgeSsePermissionAsked).requestID;

        registry.replyPermission(askedId, PluginPermissionReply.reject);
        final result = respondCalls.single.result as Map;
        expect(result["permissions"], isEmpty);
        expect(result["scope"], equals("turn"));
      },
    );

    // --- legacy (sendUserTurn) approvals stay supported ---

    test(
      "legacy execCommandApproval still maps to the v1 'approved' decision",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 120,
            method: "execCommandApproval",
            params: {
              "conversationId": "t-9",
              "callId": "c-1",
              "command": ["ls"],
              "cwd": "/repo",
              "reason": "list",
            },
          ),
        );
        await pump();
        final event = emitted.single as BridgeSsePermissionAsked;
        expect(event.tool, equals("exec"));
        expect(event.sessionID, equals("t-9"));

        registry.replyPermission(event.requestID, PluginPermissionReply.once);
        expect(
          (respondCalls.single.result as Map)["decision"],
          equals("approved"),
        );
      },
    );

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

    // --- v2 elicitation + user input questions ---

    test(
      "mcpServer/elicitation/request surfaces as QuestionAsked and is pending",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 200,
            method: "mcpServer/elicitation/request",
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

    test(
      "replyQuestion(item/tool/requestUserInput) keys answers by question id",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 201,
            method: "item/tool/requestUserInput",
            params: {
              "threadId": "t-3",
              "turnId": "turn-1",
              "itemId": "i-1",
              "questions": [
                {"id": "name", "header": "Name", "question": "Your name?"},
              ],
            },
          ),
        );
        await pump();
        final askedId = (emitted.single as BridgeSseQuestionAsked).id;

        final ok = registry.replyQuestion(askedId, const [
          ["Daniil"],
        ]);
        expect(ok, isTrue);
        expect(respondCalls.single.id, equals(201));
        final answers = (respondCalls.single.result as Map)["answers"] as Map;
        expect(answers["name"], equals({"answers": ["Daniil"]}));
      },
    );

    test(
      "replyQuestion(mcpServer/elicitation/request) sends an accept action",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 202,
            method: "mcpServer/elicitation/request",
            params: {
              "threadId": "t-3",
              "serverName": "fs",
              "mode": "form",
              "message": "Path?",
              "requestedSchema": {"type": "string"},
            },
          ),
        );
        await pump();
        final askedId = (emitted.single as BridgeSseQuestionAsked).id;

        registry.replyQuestion(askedId, const [
          ["/tmp/out"],
        ]);
        final result = respondCalls.single.result as Map;
        expect(result["action"], equals("accept"));
        expect((result["content"] as Map)["answers"], equals(["/tmp/out"]));
      },
    );

    test(
      "rejectQuestion declines an MCP elicitation with an action result",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 203,
            method: "mcpServer/elicitation/request",
            params: {
              "threadId": "t-3",
              "serverName": "fs",
              "mode": "form",
              "message": "Path?",
              "requestedSchema": {"type": "string"},
            },
          ),
        );
        await pump();
        final askedId = (emitted.single as BridgeSseQuestionAsked).id;

        final ok = registry.rejectQuestion(askedId);
        expect(ok, isTrue);
        expect((respondCalls.single.result as Map)["action"], equals("decline"));
        expect(errorCalls, isEmpty);
      },
    );

    test(
      "rejectQuestion errors a user-input request (no decline variant)",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 204,
            method: "item/tool/requestUserInput",
            params: {
              "threadId": "t-3",
              "turnId": "turn-1",
              "itemId": "i-1",
              "questions": <Object?>[],
            },
          ),
        );
        await pump();
        final askedId = (emitted.single as BridgeSseQuestionAsked).id;

        final ok = registry.rejectQuestion(askedId);
        expect(ok, isTrue);
        expect(respondCalls, isEmpty);
        expect(errorCalls.single.id, equals(204));
      },
    );

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
      "dispose declines every pending v2 approval so codex isn't left waiting",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 300,
            method: "item/commandExecution/requestApproval",
            params: {
              "threadId": "t-1",
              "turnId": "turn-1",
              "itemId": "i-1",
              "startedAtMs": 0,
              "command": "ls",
            },
          ),
        );
        await pump();
        respondCalls.clear();

        await registry.dispose();
        expect(respondCalls, hasLength(1));
        expect(
          (respondCalls.single.result as Map)["decision"],
          equals("decline"),
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
