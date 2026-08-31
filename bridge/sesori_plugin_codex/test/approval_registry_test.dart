// ignore_for_file: cast_nullable_to_non_nullable

import "dart:async";
import "dart:convert";

import "package:codex_plugin/codex_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("ApprovalRegistry", () {
    late StreamController<CodexServerRequest> requests;
    late List<BridgeSseEvent> emitted;
    late List<_RespondCall> respondCalls;
    late List<_RespondError> errorCalls;
    late _FakeAgentToolHost agentToolHost;
    late ApprovalRegistry registry;

    setUp(() {
      requests = StreamController<CodexServerRequest>.broadcast();
      emitted = [];
      respondCalls = [];
      errorCalls = [];
      agentToolHost = _FakeAgentToolHost();
      registry = ApprovalRegistry(
        agentToolHost: agentToolHost,
        emit: emitted.add,
        respond: (id, result) => respondCalls.add(_RespondCall(id, result)),
        respondError: (id, code, message) => errorCalls.add(_RespondError(id, code, message)),
      );
      registry.attach(stream: requests.stream);
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

    test(
      "a pending permission is queryable via pendingPermissionsForSession",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 130,
            method: "item/commandExecution/requestApproval",
            params: {
              "threadId": "t-7",
              "turnId": "turn-1",
              "itemId": "i-1",
              "startedAtMs": 0,
              "command": "rm -rf build",
              "reason": "clean build dir",
            },
          ),
        );
        await pump();
        final asked = emitted.single as BridgeSsePermissionAsked;

        final pending = registry.pendingPermissionsForSession(sessionId: "t-7");
        expect(pending, hasLength(1));
        expect(pending.single.id, equals(asked.requestID));
        expect(pending.single.sessionID, equals("t-7"));
        expect(pending.single.displaySessionId, equals("t-7"));
        expect(pending.single.tool, equals("exec"));
        expect(pending.single.description, equals("clean build dir"));
        expect(registry.hasPendingInput(sessionId: "t-7"), isTrue);
        // Questions and permissions are disjoint: a permission is never a
        // pending question.
        expect(registry.pendingForSession(sessionId: "t-7"), isEmpty);
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

      final ok = registry.replyPermission(requestId: askedId, reply: PluginPermissionReply.once);
      expect(ok, isTrue);
      expect(respondCalls.single.id, equals(100));
      expect((respondCalls.single.result as Map)["decision"], equals("accept"));
      expect(emitted.single, isA<BridgeSsePermissionReplied>());
      expect(registry.hasPendingInput(sessionId: "t-1"), isFalse);
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

      registry.replyPermission(requestId: askedId, reply: PluginPermissionReply.always);
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

      registry.replyPermission(requestId: askedId, reply: PluginPermissionReply.reject);
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
          "fileSystem": {
            "writableRoots": <String>["/repo"],
          },
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

        registry.replyPermission(requestId: event.requestID, reply: PluginPermissionReply.always);
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

        registry.replyPermission(requestId: askedId, reply: PluginPermissionReply.reject);
        final result = respondCalls.single.result as Map;
        expect(result["permissions"], isEmpty);
        expect(result["scope"], equals("turn"));
      },
    );

    // --- legacy (sendUserTurn) approvals are no longer supported ---
    //
    // The bridge drives turns exclusively via the v2 turn/start API, so codex
    // 0.142.0 only ever emits the `item/.../requestApproval` names. The dropped
    // legacy `execCommandApproval`/`applyPatchApproval` requests are not routed:
    // they fall through to a soft -32601 and never surface a permission card.

    test(
      "legacy execCommandApproval is not handled (soft -32601, no card)",
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
        expect(emitted, isEmpty, reason: "no permission card for a legacy method");
        expect(respondCalls, isEmpty);
        expect(errorCalls.single.id, equals(120));
        expect(errorCalls.single.code, equals(-32601));
      },
    );

    test(
      "replyPermission for an unknown id returns false and emits nothing",
      () {
        final ok = registry.replyPermission(
          requestId: "br-bogus",
          reply: PluginPermissionReply.once,
        );
        expect(ok, isFalse);
        expect(respondCalls, isEmpty);
      },
    );

    // --- v2 elicitation + user input questions ---

    test(
      "empty MCP tool-call elicitation surfaces as an approvable permission",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 199,
            method: "mcpServer/elicitation/request",
            params: {
              "threadId": "t-3",
              "turnId": "turn-1",
              "serverName": "codex_apps",
              "mode": "form",
              "message": "Allow Calendar to create an event?",
              "_meta": {
                "codex_approval_kind": "mcp_tool_call",
                "persist": ["session", "always"],
                "tool_name": "calendar_create_event",
              },
              "requestedSchema": {
                "type": "object",
                "properties": <String, Object?>{},
              },
            },
          ),
        );
        await pump();

        final asked = emitted.single as BridgeSsePermissionAsked;
        expect(asked.sessionID, equals("t-3"));
        expect(asked.description, equals("Allow Calendar to create an event?"));
        expect(asked.allowAlways, isTrue);
        expect(registry.pendingPermissionsForSession(sessionId: "t-3"), hasLength(1));
        expect(registry.pendingPermissionsForSession(sessionId: "t-3").single.allowAlways, isTrue);
        expect(registry.pendingForSession(sessionId: "t-3"), isEmpty);

        final replied = registry.replyPermission(
          requestId: asked.requestID,
          reply: PluginPermissionReply.once,
        );
        expect(replied, isTrue);
        expect(respondCalls.single.id, equals(199));
        expect(
          respondCalls.single.result,
          equals({
            "action": "accept",
            "content": null,
            "_meta": null,
          }),
        );
      },
    );

    test(
      "MCP tool approval without always persistence hides Always live and pending",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 197,
            method: "mcpServer/elicitation/request",
            params: {
              "threadId": "t-3",
              "serverName": "codex_apps",
              "mode": "form",
              "message": "Allow Calendar to read events?",
              "_meta": {
                "codex_approval_kind": "mcp_tool_call",
                "persist": ["session"],
                "tool_name": "calendar_read_events",
              },
              "requestedSchema": {
                "type": "object",
                "properties": <String, Object?>{},
              },
            },
          ),
        );
        await pump();

        expect((emitted.single as BridgeSsePermissionAsked).allowAlways, isFalse);
        expect(registry.pendingPermissionsForSession(sessionId: "t-3").single.allowAlways, isFalse);
      },
    );

    test(
      "MCP tool-call metadata cannot turn a non-empty form into a permission",
      () async {
        requests.add(
          const CodexServerRequest(
            id: 198,
            method: "mcpServer/elicitation/request",
            params: {
              "threadId": "t-3",
              "serverName": "custom-mcp",
              "mode": "form",
              "message": "Which environment should I use?",
              "_meta": {"codex_approval_kind": "mcp_tool_call"},
              "requestedSchema": {
                "type": "object",
                "properties": {
                  "environment": {"type": "string"},
                },
              },
            },
          ),
        );
        await pump();

        expect(emitted.single, isA<BridgeSseQuestionAsked>());
        expect(registry.pendingPermissionsForSession(sessionId: "t-3"), isEmpty);
        expect(registry.pendingForSession(sessionId: "t-3"), hasLength(1));
      },
    );

    test("tool suggestions remain questions", () async {
      requests.add(
        const CodexServerRequest(
          id: 197,
          method: "mcpServer/elicitation/request",
          params: {
            "threadId": "t-3",
            "serverName": "codex_apps",
            "mode": "form",
            "message": "Install Google Calendar?",
            "_meta": {
              "codex_approval_kind": "tool_suggestion",
              "tool_type": "connector",
              "suggest_type": "install",
            },
            "requestedSchema": {
              "type": "object",
              "properties": <String, Object?>{},
            },
          },
        ),
      );
      await pump();

      expect(emitted.single, isA<BridgeSseQuestionAsked>());
      expect(registry.pendingPermissionsForSession(sessionId: "t-3"), isEmpty);
    });

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

        final pending = registry.pendingForSession(sessionId: "t-3");
        expect(pending, hasLength(1));
        expect(pending.single.id, equals(asked.id));
        expect(registry.hasPendingInput(sessionId: "t-3"), isTrue);
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

        final ok = registry.replyQuestion(
          requestId: askedId,
          answers: const [
            ["Daniil"],
          ],
        );
        expect(ok, isTrue);
        expect(respondCalls.single.id, equals(201));
        final answers = (respondCalls.single.result as Map)["answers"] as Map;
        expect(
          answers["name"],
          equals({
            "answers": ["Daniil"],
          }),
        );
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

        registry.replyQuestion(
          requestId: askedId,
          answers: const [
            ["/tmp/out"],
          ],
        );
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

        final ok = registry.rejectQuestion(requestId: askedId);
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

        final ok = registry.rejectQuestion(requestId: askedId);
        expect(ok, isTrue);
        expect(respondCalls, isEmpty);
        expect(errorCalls.single.id, equals(204));
      },
    );

    test("dynamic tools trust app-server threadId and return typed JSON", () async {
      requests.add(
        const CodexServerRequest(
          id: 400,
          method: "item/tool/call",
          params: {
            "threadId": "trusted-thread",
            "turnId": "turn-1",
            "callId": "call-1",
            "tool": "claim_simulator",
            "namespace": null,
            "arguments": {"deviceKey": "ios:sim-1"},
          },
        ),
      );
      await pump();
      await pump();

      expect(agentToolHost.invocations, hasLength(1));
      expect(agentToolHost.invocations.single.backendSessionId, "trusted-thread");
      expect(agentToolHost.invocations.single.tool, PluginAgentTool.claimSimulator);
      expect(agentToolHost.invocations.single.arguments, {"deviceKey": "ios:sim-1"});
      final result = respondCalls.single.result as Map<String, dynamic>;
      expect(result["success"], isTrue);
      expect(
        jsonDecode(((result["contentItems"] as List).single as Map)["text"] as String),
        agentToolHost.outcome,
      );
    });

    test("dynamic tools reject model-controlled session identity", () async {
      requests.add(
        const CodexServerRequest(
          id: 401,
          method: "item/tool/call",
          params: {
            "threadId": "trusted-thread",
            "turnId": "turn-1",
            "callId": "call-1",
            "tool": "claim_simulator",
            "arguments": {
              "deviceKey": "ios:sim-1",
              "backendSessionId": "injected-thread",
            },
          },
        ),
      );
      await pump();

      expect(agentToolHost.invocations, isEmpty);
      expect(respondCalls, isEmpty);
      expect(errorCalls.single.id, 401);
      expect(errorCalls.single.code, -32602);
      expect(errorCalls.single.message, "Invalid params");
    });

    test("dynamic tool failures return a bounded non-leaking response", () async {
      agentToolHost.error = StateError("private backend detail");
      requests.add(
        const CodexServerRequest(
          id: 402,
          method: "item/tool/call",
          params: {
            "threadId": "trusted-thread",
            "turnId": "turn-1",
            "callId": "call-1",
            "tool": "list_simulators",
            "arguments": <String, Object?>{},
          },
        ),
      );
      await pump();
      await pump();

      final result = respondCalls.single.result as Map<String, dynamic>;
      expect(result["success"], isFalse);
      expect(result, {
        "success": false,
        "contentItems": [
          {"type": "inputText", "text": '{"outcome":"internalError"}'},
        ],
      });
      expect(jsonEncode(result), isNot(contains("private backend detail")));
    });

    test("dynamic tools and approvals coexist on one request subscription", () async {
      requests.add(
        const CodexServerRequest(
          id: 403,
          method: "item/tool/call",
          params: {
            "threadId": "t-coexist",
            "turnId": "turn-1",
            "callId": "call-1",
            "tool": "release_simulator",
            "arguments": {"deviceKey": "ios:sim-1"},
          },
        ),
      );
      requests.add(
        const CodexServerRequest(
          id: 404,
          method: "item/commandExecution/requestApproval",
          params: {
            "threadId": "t-coexist",
            "turnId": "turn-1",
            "itemId": "item-1",
            "command": "ls",
          },
        ),
      );
      await pump();
      await pump();

      final asked = emitted.single as BridgeSsePermissionAsked;
      expect(agentToolHost.invocations.single.backendSessionId, "t-coexist");
      expect(respondCalls.single.id, 403);
      expect(registry.replyPermission(requestId: asked.requestID, reply: PluginPermissionReply.once), isTrue);
      expect(respondCalls.map((call) => call.id), [403, 404]);
      expect((respondCalls.last.result as Map)["decision"], "accept");
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

class _RespondCall(final Object id, final Object? result);

class _RespondError(final Object id, final int code, final String message);

class _FakeAgentToolHost() implements PluginAgentToolHost {
  final Map<String, dynamic> outcome = {
    "outcome": "claimed",
    "deviceKey": "ios:sim-1",
  };
  final List<_ToolInvocation> invocations = [];
  Object? error;
  bool disposed = false;

  @override
  Future<Map<String, dynamic>> invoke({
    required String backendSessionId,
    required PluginAgentTool tool,
    required Map<String, dynamic> arguments,
  }) async {
    invocations.add(
      _ToolInvocation(
        backendSessionId: backendSessionId,
        tool: tool,
        arguments: arguments,
      ),
    );
    final invocationError = error;
    if (invocationError != null) throw invocationError;
    return outcome;
  }

  @override
  Future<PluginAgentToolMcpCapability> provisionMcp({required String? backendSessionId}) => throw UnimplementedError();

  @override
  Future<void> bindMcp({
    required PluginAgentToolMcpCapability capability,
    required String backendSessionId,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeMcp({required PluginAgentToolMcpCapability capability}) => throw UnimplementedError();

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _ToolInvocation({
  required final String backendSessionId,
  required final PluginAgentTool tool,
  required final Map<String, dynamic> arguments,
});
