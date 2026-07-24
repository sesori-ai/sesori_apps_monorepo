import "dart:async";

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

const String _elicitationApprovalKindKey = "codex_approval_kind";

enum _ElicitationApprovalKind { mcpToolCall, toolSuggestion }

/// A pending codex approval, kept until the user answers or codex
/// rescinds it.
class _PendingApproval {
  _PendingApproval({
    required this.bridgeRequestId,
    required this.codexId,
    required this.sessionId,
    required this.method,
    required this.params,
    required this.kind,
  });

  /// Stable id the bridge surfaces to mobile.
  final String bridgeRequestId;

  /// Original JSON-RPC `id` from codex — required to send the response
  /// frame back on the same request.
  final Object codexId;

  /// Thread id this approval belongs to. May be the empty string when
  /// codex didn't include one (rare).
  final String sessionId;

  /// JSON-RPC method this approval came in on.
  final String method;

  /// Raw params, kept so the reply can echo whatever codex needs.
  final Map<String, dynamic> params;

  final _PendingKind kind;
}

enum _PendingKind { permission, question }

/// Per-request reply functions injected at construction time so the
/// registry stays decoupled from [CodexAppServerClient].
typedef ApprovalResponder = void Function(Object id, Object? result);
typedef ApprovalErrorResponder =
    void Function(Object id, int code, String message);

/// Routes codex server-originated approval requests to the bridge SSE
/// stream and answers them when the bridge consumer replies.
///
/// Subscribe with [attach]. Detach + free pending state with [dispose].
class ApprovalRegistry {
  ApprovalRegistry({
    required void Function(BridgeSseEvent event) emit,
    required ApprovalResponder respond,
    required ApprovalErrorResponder respondError,
    String Function()? idGenerator,
  }) : _emit = emit,
       _respond = respond,
       _respondError = respondError,
       _injectedIdGenerator = idGenerator;

  final void Function(BridgeSseEvent event) _emit;
  final ApprovalResponder _respond;
  final ApprovalErrorResponder _respondError;
  final String Function()? _injectedIdGenerator;

  StreamSubscription<CodexServerRequest>? _subscription;
  int _seq = 0;

  String _generateId() {
    final injected = _injectedIdGenerator;
    if (injected != null) return injected();
    _seq++;
    return "br-$_seq";
  }

  /// bridgeRequestId → pending entry. Removed on reply or rejection.
  final Map<String, _PendingApproval> _pending = {};

  /// Subscribes to [stream] of codex server requests. Returns the
  /// subscription so the caller can manage it if desired.
  StreamSubscription<CodexServerRequest> attach(
    Stream<CodexServerRequest> stream,
  ) {
    final subscription = stream.listen(_handle);
    _subscription = subscription;
    return subscription;
  }

  /// Cancels the subscription and denies every still-pending approval so
  /// codex doesn't wait forever.
  Future<void> dispose() async {
    // Isolate the cancel so a failing cancel can never skip the pending-denial
    // loop below — otherwise codex would wait forever on unanswered approvals.
    try {
      await _subscription?.cancel();
    } catch (_) {
      // Best-effort; we still must deny everything that's pending.
    }
    _subscription = null;
    final remaining = List<_PendingApproval>.from(_pending.values);
    _pending.clear();
    for (final entry in remaining) {
      try {
        _denyPending(entry, questionErrorMessage: "bridge dispose");
      } catch (_) {
        // Best-effort.
      }
    }
  }

  /// Approvals that are still waiting for the user, scoped to one session.
  List<PluginPendingQuestion> pendingForSession(String sessionId) {
    return _pending.values
        .where(
          (e) => e.kind == _PendingKind.question && e.sessionId == sessionId,
        )
        .map(_toPluginPendingQuestion)
        .toList(growable: false);
  }

  /// Approvals waiting for any of the given session ids. Mobile passes
  /// the full list of sessions visible under a project.
  List<PluginPendingQuestion> pendingForProject(
    Iterable<String> sessionIds,
  ) {
    final set = Set<String>.from(sessionIds);
    return _pending.values
        .where(
          (e) => e.kind == _PendingKind.question && set.contains(e.sessionId),
        )
        .map(_toPluginPendingQuestion)
        .toList(growable: false);
  }

  /// Permission asks still waiting for the user, scoped to one session.
  List<PluginPendingPermission> pendingPermissionsForSession(String sessionId) {
    return _pending.values
        .where(
          (e) => e.kind == _PendingKind.permission && e.sessionId == sessionId,
        )
        .map(_toPluginPendingPermission)
        .toList(growable: false);
  }

  /// Returns the session id for a pending request, or null if the id is
  /// unknown.
  String? sessionIdFor(String bridgeRequestId) =>
      _pending[bridgeRequestId]?.sessionId;

  bool hasPendingInput(String sessionId) =>
      _pending.values.any((entry) => entry.sessionId == sessionId);

  bool get hasAnyPendingInput => _pending.isNotEmpty;

  void cancelForSession(String sessionId) {
    final entries = _pending.values.where((entry) => entry.sessionId == sessionId).toList(growable: false);
    for (final entry in entries) {
      _pending.remove(entry.bridgeRequestId);
      try {
        _denyPending(entry, questionErrorMessage: "thread closed");
      } on Object catch (error, stackTrace) {
        Log.w("[codex] failed to deny pending approval for closed thread", error, stackTrace);
      }
      _emit(
        entry.kind == _PendingKind.permission
            ? BridgeSsePermissionReplied(
                requestID: entry.bridgeRequestId,
                sessionID: entry.sessionId,
                displaySessionId: entry.sessionId,
                reply: PluginPermissionReply.reject.name,
              )
            : BridgeSseQuestionRejected(
                requestID: entry.bridgeRequestId,
                sessionID: entry.sessionId,
                displaySessionId: entry.sessionId,
              ),
      );
    }
  }

  void _denyPending(_PendingApproval entry, {required String questionErrorMessage}) {
    if (entry.kind == _PendingKind.permission) {
      _respond(entry.codexId, _permissionResponse(entry, PluginPermissionReply.reject));
    } else if (entry.method == _elicitationMethod) {
      _respond(entry.codexId, const {"action": "cancel"});
    } else {
      _respondError(entry.codexId, -32000, questionErrorMessage);
    }
  }

  /// Acknowledges a permission ask with a once/always/reject decision.
  ///
  /// Returns true when the response was sent, false if the id had
  /// already been resolved or didn't exist.
  bool replyPermission(String bridgeRequestId, PluginPermissionReply reply) {
    final entry = _pending.remove(bridgeRequestId);
    if (entry == null || entry.kind != _PendingKind.permission) return false;
    _respond(entry.codexId, _permissionResponse(entry, reply));
    _emit(
      BridgeSsePermissionReplied(
        requestID: bridgeRequestId,
        sessionID: entry.sessionId,
        displaySessionId: entry.sessionId,
        reply: reply.name,
      ),
    );
    return true;
  }

  /// Replies to an elicitation / user-input request. `answers` is the
  /// list-of-lists shape the bridge contract requires (one inner list
  /// per question, multi-select allowed).
  bool replyQuestion(String bridgeRequestId, List<List<String>> answers) {
    final entry = _pending.remove(bridgeRequestId);
    if (entry == null || entry.kind != _PendingKind.question) return false;
    _respond(entry.codexId, _questionResponse(entry, answers));
    _emit(
      BridgeSseQuestionReplied(
        requestID: bridgeRequestId,
        sessionID: entry.sessionId,
        displaySessionId: entry.sessionId,
      ),
    );
    return true;
  }

  /// Reject an elicitation / user-input request.
  ///
  /// MCP elicitations carry a proper `decline` action; `item/tool/
  /// requestUserInput` has no decline variant, so a JSON-RPC error is the
  /// signal that the user dismissed it.
  bool rejectQuestion(String bridgeRequestId) {
    final entry = _pending.remove(bridgeRequestId);
    if (entry == null || entry.kind != _PendingKind.question) return false;
    if (entry.method == _elicitationMethod) {
      _respond(entry.codexId, const {"action": "decline"});
    } else {
      _respondError(entry.codexId, -32603, "user rejected");
    }
    _emit(
      BridgeSseQuestionRejected(
        requestID: bridgeRequestId,
        sessionID: entry.sessionId,
        displaySessionId: entry.sessionId,
      ),
    );
    return true;
  }

  void _handle(CodexServerRequest request) {
    final method = request.method;
    final isMcpToolApproval = method == _elicitationMethod && _isMcpToolApproval(request.params);
    final isPermission = _permissionMethods.contains(method) || isMcpToolApproval;
    final isQuestion = _questionMethods.contains(method) && !isMcpToolApproval;
    if (!isPermission && !isQuestion) {
      // Don't recognise — return a soft error so codex doesn't hang.
      _respondError(request.id, -32601, "method not handled by bridge: $method");
      return;
    }

    final sessionId = _extractSessionId(request.params);
    final bridgeRequestId = _generateId();
    final entry = _PendingApproval(
      bridgeRequestId: bridgeRequestId,
      codexId: request.id,
      sessionId: sessionId ?? "",
      method: method,
      params: request.params,
      kind: isPermission ? _PendingKind.permission : _PendingKind.question,
    );
    _pending[bridgeRequestId] = entry;

    if (isPermission) {
      _emit(
        BridgeSsePermissionAsked(
          requestID: bridgeRequestId,
          sessionID: entry.sessionId,
          // codex has no sub-agent hierarchy, so a request's display root is
          // its own session.
          displaySessionId: entry.sessionId,
          tool: _toolHintFor(method),
          description: _permissionDescriptionFor(entry),
        ),
      );
    } else {
      _emit(
        BridgeSseQuestionAsked(
          id: bridgeRequestId,
          sessionID: entry.sessionId,
          displaySessionId: entry.sessionId,
          questions: [_questionInfoFor(entry)],
        ),
      );
    }
  }

  PluginPendingQuestion _toPluginPendingQuestion(_PendingApproval entry) {
    return PluginPendingQuestion(
      id: entry.bridgeRequestId,
      sessionID: entry.sessionId,
      // codex has no sub-agent hierarchy, so a request's display root is its
      // own session.
      displaySessionId: entry.sessionId,
      questions: [_questionInfoFor(entry)],
    );
  }

  PluginPendingPermission _toPluginPendingPermission(_PendingApproval entry) {
    return PluginPendingPermission(
      id: entry.bridgeRequestId,
      sessionID: entry.sessionId,
      displaySessionId: entry.sessionId,
      tool: _toolHintFor(entry.method),
      description: _permissionDescriptionFor(entry),
    );
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
      (entry.params["reason"] as String?) ??
      _descriptionFallback(entry.method, entry.params);

  /// Builds the JSON-RPC result payload for a permission reply, keyed by the
  /// request's wire method:
  ///   - command/file change   → `{decision: accept|acceptForSession|decline}`
  ///   - permissions request    → `{permissions: GrantedPermissionProfile, scope}`
  ///   - MCP tool approval      → `{action, content, _meta}`
  Map<String, dynamic> _permissionResponse(
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
  Map<String, dynamic> _questionResponse(
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

  bool _isMcpToolApproval(Map<String, dynamic> params) {
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

  _ElicitationApprovalKind? _parseElicitationApprovalKind(Object? raw) {
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

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}
