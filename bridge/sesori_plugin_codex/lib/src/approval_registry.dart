import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "codex_app_server_client.dart";

/// Codex methods that always surface as permission asks.
///
/// These are the JSON-RPC method names codex `app-server` (0.142.0) sends as
/// server-originated requests when it needs the user to allow / deny a
/// destructive action. The bridge drives turns exclusively via the **v2**
/// `turn/start` API, so codex only ever emits the slash-delimited
/// `item/.../requestApproval` names. The deprecated `applyPatchApproval` /
/// `execCommandApproval` requests (emitted only on the legacy
/// `sendUserTurn`/`sendUserMessage` path we never call) are intentionally not
/// handled — an unexpected one returns a soft -32601 rather than routing.
/// Tagged MCP tool-call elicitations are classified from their payload in
/// `_isMcpToolApproval` because that wire method also carries genuine forms.
const Set<String> _permissionMethods = {
  "item/commandExecution/requestApproval",
  "item/fileChange/requestApproval",
  "item/permissions/requestApproval",
};

/// Codex methods that we surface as questions (free-form user input or
/// MCP-driven elicitations). These get rendered by mobile as a question
/// prompt rather than the binary allow/deny UI unless an elicitation is
/// explicitly tagged as an MCP tool-call approval.
const Set<String> _questionMethods = {
  // v2 wire names.
  "item/tool/requestUserInput",
  "mcpServer/elicitation/request",
};

/// The v2 permissions-escalation method. Its response is **not** a decision —
/// it is `{permissions: GrantedPermissionProfile, scope: turn|session}`.
const String _permissionsRequestMethod = "item/permissions/requestApproval";

/// The v2 MCP elicitation method. Its response is `{action: accept|decline|
/// cancel, content?}` rather than an answers map.
const String _elicitationMethod = "mcpServer/elicitation/request";

/// The v2 user-input method. Its response is
/// `{answers: {<questionId>: {answers: [..]}}}`.
const String _userInputMethod = "item/tool/requestUserInput";
const String _dynamicToolCallMethod = "item/tool/call";
const Duration _dynamicToolCallTimeout = Duration(seconds: 10);
const int _maxDynamicToolOutcomeCharacters = 512 * 1024;
const String _dynamicToolFailureOutcome = '{"outcome":"internalError"}';
const Set<String> _dynamicToolParamKeys = {
  "threadId",
  "turnId",
  "callId",
  "tool",
  "namespace",
  "arguments",
};

const String _elicitationApprovalKindKey = "codex_approval_kind";

enum _ElicitationApprovalKind() {
  mcpToolCall,
  toolSuggestion,
}

class _PendingApproval({
  required final Object codexId,
  required final String method,
  required final Map<String, dynamic> params,
  required final ApprovalResponder respond,
  required final ApprovalErrorResponder respondError,
});

/// Per-request reply functions injected at construction time so the
/// registry stays decoupled from [CodexAppServerClient].
typedef ApprovalResponder = void Function(Object id, Object? result);
typedef ApprovalErrorResponder = void Function(Object id, int code, String message);

void _resolveCodexPermission({required _PendingApproval payload, required PluginPermissionReply reply}) {
  payload.respond(payload.codexId, ApprovalRegistry._permissionResponse(payload, reply));
}

PendingQuestionReplyOutcome _resolveCodexQuestion({
  required _PendingApproval payload,
  required List<List<String>> answers,
}) {
  payload.respond(payload.codexId, ApprovalRegistry._questionResponse(payload, answers));
  return PendingQuestionReplyOutcome.replied;
}

void _rejectCodexQuestion({required _PendingApproval payload}) {
  if (payload.method == _elicitationMethod) {
    payload.respond(payload.codexId, const {"action": "decline"});
    return;
  }
  payload.respondError(payload.codexId, -32603, "user rejected");
}

void _cancelCodexPending({required _PendingApproval payload, required PendingCancellationReason reason}) {
  if (_permissionMethods.contains(payload.method) ||
      payload.method == _elicitationMethod && ApprovalRegistry._isMcpToolApproval(payload.params)) {
    payload.respond(payload.codexId, ApprovalRegistry._permissionResponse(payload, PluginPermissionReply.reject));
  } else if (payload.method == _elicitationMethod) {
    payload.respond(payload.codexId, const {"action": "cancel"});
  } else {
    payload.respondError(
      payload.codexId,
      -32000,
      switch (reason) {
        PendingCancellationReason.sessionCancelled => "thread closed",
        PendingCancellationReason.disposed => "bridge dispose",
      },
    );
  }
}

/// Routes codex server-originated approval requests to the bridge SSE
/// stream and answers them when the bridge consumer replies.
///
/// Subscribe with [attach]. Detach + free pending state with [dispose].
class ApprovalRegistry({
  required super.emit,
  final PluginAgentToolHost? agentToolHost,
  required final ApprovalResponder _respond,
  required final ApprovalErrorResponder _respondError,
  super.idGenerator,
}) extends PendingPermissionRegistry<CodexServerRequest, _PendingApproval> {
  this
    : super(
        logContext: "[codex]",
        resolvePermission: _resolveCodexPermission,
        resolveQuestion: _resolveCodexQuestion,
        rejectQuestion: _rejectCodexQuestion,
        cancelPending: _cancelCodexPending,
      );

  final Set<Future<void>> _dynamicCalls = {};

  @override
  void handleRequest(CodexServerRequest request) {
    final method = request.method;
    if (method == _dynamicToolCallMethod) {
      final host = agentToolHost;
      if (host == null) {
        _respondError(request.id, -32601, "Method not available");
        return;
      }
      late final Future<void> operation;
      operation = _handleDynamicToolCall(request: request, host: host).whenComplete(
        () => _dynamicCalls.remove(operation),
      );
      _dynamicCalls.add(operation);
      unawaited(operation);
      return;
    }
    final isMcpToolApproval = method == _elicitationMethod && _isMcpToolApproval(request.params);
    final isPermission = _permissionMethods.contains(method) || isMcpToolApproval;
    final isQuestion = _questionMethods.contains(method) && !isMcpToolApproval;
    if (!isPermission && !isQuestion) {
      // Don't recognise — return a soft error so codex doesn't hang.
      _respondError(request.id, -32601, "method not handled by bridge: $method");
      return;
    }

    final sessionId = _extractSessionId(request.params);
    final entry = _PendingApproval(
      codexId: request.id,
      method: method,
      params: request.params,
      respond: _respond,
      respondError: _respondError,
    );
    final resolvedSessionId = sessionId ?? "";

    if (isPermission) {
      final allowAlways = _allowsAlways(entry);
      registerPendingPermission(
        payload: entry,
        sessionId: resolvedSessionId,
        displaySessionId: resolvedSessionId,
        tool: _toolHintFor(method),
        description: _permissionDescriptionFor(entry),
        allowAlways: allowAlways,
      );
    } else {
      registerPendingQuestion(
        payload: entry,
        sessionId: resolvedSessionId,
        displaySessionId: resolvedSessionId,
        questions: [_questionInfoFor(entry)],
      );
    }
  }

  Future<void> _handleDynamicToolCall({
    required CodexServerRequest request,
    required PluginAgentToolHost host,
  }) async {
    final invocation = _parseDynamicToolInvocation(request.params);
    if (invocation == null) {
      _respondError(request.id, -32602, "Invalid params");
      return;
    }

    var success = true;
    var text = _dynamicToolFailureOutcome;
    try {
      final outcome = await host
          .invoke(
            backendSessionId: invocation.backendSessionId,
            tool: invocation.tool,
            arguments: invocation.arguments,
          )
          .timeout(_dynamicToolCallTimeout);
      final encoded = jsonEncode(outcome);
      if (encoded.length > _maxDynamicToolOutcomeCharacters) {
        throw const FormatException("dynamic tool outcome exceeds protocol limit");
      }
      text = encoded;
    } on Object {
      success = false;
      Log.w("[codex] dynamic tool call failed");
    }
    _respond(request.id, {
      "success": success,
      "contentItems": [
        {"type": "inputText", "text": text},
      ],
    });
  }

  _DynamicToolInvocation? _parseDynamicToolInvocation(Map<String, dynamic> params) {
    if (params.keys.any((key) => !_dynamicToolParamKeys.contains(key))) return null;
    final backendSessionId = _boundedString(params["threadId"], maxLength: 2048);
    final turnId = _boundedString(params["turnId"], maxLength: 2048);
    final callId = _boundedString(params["callId"], maxLength: 2048);
    final toolName = params["tool"];
    final namespace = params["namespace"];
    final rawArguments = params["arguments"];
    if (backendSessionId == null ||
        turnId == null ||
        callId == null ||
        toolName is! String ||
        namespace != null ||
        rawArguments is! Map) {
      return null;
    }
    final tool = PluginAgentTool.fromWireName(toolName);
    if (tool == null) return null;

    final arguments = <String, dynamic>{};
    for (final entry in rawArguments.entries) {
      final key = entry.key;
      if (key is! String) return null;
      arguments[key] = entry.value;
    }
    final validArguments = switch (tool) {
      PluginAgentTool.listSimulators => arguments.isEmpty,
      PluginAgentTool.claimSimulator || PluginAgentTool.releaseSimulator =>
        arguments.length == 1 && _boundedString(arguments["deviceKey"], maxLength: 512) != null,
    };
    if (!validArguments) return null;
    return _DynamicToolInvocation(
      backendSessionId: backendSessionId,
      tool: tool,
      arguments: arguments,
    );
  }

  String? _boundedString(Object? value, {required int maxLength}) =>
      value is String && value.isNotEmpty && value.length <= maxLength ? value : null;

  @override
  Future<void> dispose() async {
    await super.dispose();
    final calls = _dynamicCalls.toList(growable: false);
    if (calls.isNotEmpty) await Future.wait(calls);
  }

  bool _allowsAlways(_PendingApproval entry) {
    if (entry.method != _elicitationMethod) return true;
    final persist = _asMap(entry.params["_meta"])?["persist"];
    return persist is List && persist.contains("always");
  }

  /// Builds the single free-form question payload for a codex elicitation /
  /// user-input request: codex supplies no structured option set, so it is
  /// always a [PluginQuestionInfo.custom] question headed by the wire method.
  PluginQuestionInfo _questionInfoFor(_PendingApproval entry) {
    final reason =
        (entry.params["message"] as String?) ??
        (entry.params["reason"] as String?) ??
        _descriptionFallback(entry.method, entry.params);
    return PluginQuestionInfo(
      question: reason,
      header: entry.method,
      options: const [],
      multiple: false,
      custom: true,
    );
  }

  /// Human-readable description for a permission ask, shared by the
  /// `PermissionAsked` event and the pending-permission snapshot so the two
  /// never drift.
  String _permissionDescriptionFor(_PendingApproval entry) =>
      (entry.params["reason"] as String?) ?? _descriptionFallback(entry.method, entry.params);

  /// Builds the JSON-RPC result payload for a permission reply, keyed by the
  /// request's wire method:
  ///   - command/file change   → `{decision: accept|acceptForSession|decline}`
  ///   - permissions request    → `{permissions: GrantedPermissionProfile, scope}`
  ///   - MCP tool approval      → `{action, content, _meta}`
  static Map<String, dynamic> _permissionResponse(
    _PendingApproval entry,
    PluginPermissionReply reply,
  ) {
    if (entry.method == _elicitationMethod) {
      return switch (reply) {
        PluginPermissionReply.once => const {
          "action": "accept",
          "content": null,
          "_meta": null,
        },
        PluginPermissionReply.always => const {
          "action": "accept",
          "content": null,
          "_meta": {"persist": "always"},
        },
        PluginPermissionReply.reject => const {
          "action": "decline",
          "content": null,
          "_meta": null,
        },
      };
    }

    if (entry.method == _permissionsRequestMethod) {
      // Grant the requested profile on approve (turn- or session-scoped);
      // grant nothing on reject. RequestPermissionProfile and
      // GrantedPermissionProfile share the `{fileSystem?, network?}` shape, so
      // echoing the requested profile back is a faithful "grant exactly what
      // was asked".
      final requested = entry.params["permissions"];
      return switch (reply) {
        PluginPermissionReply.once => {
          "permissions": requested ?? const <String, dynamic>{},
          "scope": "turn",
        },
        PluginPermissionReply.always => {
          "permissions": requested ?? const <String, dynamic>{},
          "scope": "session",
        },
        PluginPermissionReply.reject => const {
          "permissions": <String, dynamic>{},
          "scope": "turn",
        },
      };
    }

    // Every remaining permission method is a v2 command/file-change approval
    // (CommandExecutionApprovalDecision / FileChangeApprovalDecision).
    final decision = switch (reply) {
      PluginPermissionReply.once => "accept",
      PluginPermissionReply.always => "acceptForSession",
      // `decline` lets the agent continue the turn; `cancel` would also
      // interrupt the whole turn, which is more than a single deny implies.
      PluginPermissionReply.reject => "decline",
    };
    return {"decision": decision};
  }

  /// Builds the JSON-RPC result for a question reply, keyed by wire method:
  ///   - `item/tool/requestUserInput` → `{answers: {<qid>: {answers: [..]}}}`
  ///   - `mcpServer/elicitation/request` → `{action: accept, content}`
  static Map<String, dynamic> _questionResponse(
    _PendingApproval entry,
    List<List<String>> answers,
  ) {
    if (entry.method == _userInputMethod) {
      // Map answers to codex's question-id-keyed shape, pairing each answer row
      // with its question by order (the mobile prompt preserves question order).
      final questions = (entry.params["questions"] as List?) ?? const [];
      final out = <String, dynamic>{};
      for (var i = 0; i < questions.length; i++) {
        final qid = _asMap(questions[i])?["id"] as String?;
        if (qid == null) continue;
        out[qid] = {"answers": i < answers.length ? answers[i] : const <String>[]};
      }
      return {"answers": out};
    }

    if (entry.method == _elicitationMethod) {
      // Accept the elicitation. `content` mirrors the server-defined form
      // schema, which the bridge cannot model generically; pass the flattened
      // answers best-effort (decline/cancel carry no content).
      return {
        "action": "accept",
        "content": {"answers": answers.expand((row) => row).toList()},
      };
    }

    // Unknown question method: fall back to the legacy answers array.
    return {"answers": answers.map((row) => row.toList()).toList()};
  }

  String _toolHintFor(String method) {
    return switch (method) {
      "item/fileChange/requestApproval" => "patch",
      "item/commandExecution/requestApproval" => "exec",
      "item/permissions/requestApproval" => "permissions",
      _ => method,
    };
  }

  String _descriptionFallback(String method, Map<String, dynamic> params) {
    // A command/exec approval carries the command to run as a single string;
    // file-change and permission approvals carry only an explanatory `reason`
    // (the touched files / diff arrive on the correlated `item/*`
    // notification, not on the approval request itself).
    final command = params["command"];
    if (command is String && command.isNotEmpty) return command;
    final reason = params["reason"];
    if (reason is String && reason.isNotEmpty) return reason;
    final message = params["message"];
    if (message is String && message.isNotEmpty) return message;
    return method;
  }

  static bool _isMcpToolApproval(Map<String, dynamic> params) {
    if (params["mode"] != "form") return false;
    final meta = _asMap(params["_meta"]);
    if (_parseElicitationApprovalKind(
          meta?[_elicitationApprovalKindKey],
        ) !=
        _ElicitationApprovalKind.mcpToolCall) {
      return false;
    }
    if (!params.containsKey("requestedSchema")) return false;
    final rawSchema = params["requestedSchema"];
    if (rawSchema == null) return true;
    final schema = _asMap(rawSchema);
    if (schema?["type"] != "object") return false;
    final properties = _asMap(schema?["properties"]);
    return properties != null && properties.isEmpty;
  }

  static _ElicitationApprovalKind? _parseElicitationApprovalKind(Object? raw) {
    return switch (raw) {
      "mcp_tool_call" => _ElicitationApprovalKind.mcpToolCall,
      "tool_suggestion" => _ElicitationApprovalKind.toolSuggestion,
      _ => null,
    };
  }

  String? _extractSessionId(Map<String, dynamic> params) {
    // v2 approvals carry the owning thread as `threadId`.
    final thread = params["threadId"];
    if (thread is String && thread.isNotEmpty) return thread;
    return null;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}

class const _DynamicToolInvocation({
  required final String backendSessionId,
  required final PluginAgentTool tool,
  required final Map<String, dynamic> arguments,
});
