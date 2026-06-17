import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "codex_app_server_client.dart";

/// Codex methods that we surface as permission asks.
///
/// These are the JSON-RPC method names codex `app-server` sends as
/// server-originated requests when it needs the user to allow / deny a
/// destructive action. The bridge drives turns via the **v2** `turn/start`
/// API, so the live names are the slash-delimited `item/.../requestApproval`
/// strings; the legacy `applyPatchApproval`/`execCommandApproval` names are
/// only emitted for the deprecated `sendUserTurn`/`sendUserMessage` path and
/// are kept here so an older/alternate flow still routes.
const Set<String> _permissionMethods = {
  // v2 (turn/start) — the live path the bridge uses.
  "item/commandExecution/requestApproval",
  "item/fileChange/requestApproval",
  "item/permissions/requestApproval",
  // legacy (sendUserTurn/sendUserMessage) — back-compat only.
  "applyPatchApproval",
  "execCommandApproval",
};

/// Codex methods that we surface as questions (free-form user input or
/// MCP-driven elicitations). These get rendered by mobile as a question
/// prompt rather than the binary allow/deny UI.
const Set<String> _questionMethods = {
  // v2 wire names.
  "item/tool/requestUserInput",
  "mcpServer/elicitation/request",
};

/// v2 command/file-change approval methods. Their response is a
/// `{decision: accept|acceptForSession|decline|cancel}` enum
/// (CommandExecutionApprovalDecision / FileChangeApprovalDecision).
const Set<String> _v2DecisionMethods = {
  "item/commandExecution/requestApproval",
  "item/fileChange/requestApproval",
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
    await _subscription?.cancel();
    _subscription = null;
    final remaining = List<_PendingApproval>.from(_pending.values);
    _pending.clear();
    for (final entry in remaining) {
      try {
        if (entry.kind == _PendingKind.permission) {
          _respond(entry.codexId, _permissionResponse(entry, PluginPermissionReply.reject));
        } else if (entry.method == _elicitationMethod) {
          _respond(entry.codexId, const {"action": "cancel"});
        } else {
          _respondError(entry.codexId, -32000, "bridge dispose");
        }
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

  /// Returns the session id for a pending request, or null if the id is
  /// unknown.
  String? sessionIdFor(String bridgeRequestId) =>
      _pending[bridgeRequestId]?.sessionId;

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
      ),
    );
    return true;
  }

  void _handle(CodexServerRequest request) {
    final method = request.method;
    final isPermission = _permissionMethods.contains(method);
    final isQuestion = _questionMethods.contains(method);
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
          tool: _toolHintFor(method),
          description:
              (request.params["reason"] as String?) ??
              _descriptionFallback(method, request.params),
        ),
      );
    } else {
      // BridgeSseQuestionAsked.questions must carry QuestionInfo-shaped maps
      // (the bridge parses them via SesoriSseEvent.fromJson → QuestionInfo).
      final reason =
          (request.params["message"] as String?) ??
          (request.params["reason"] as String?) ??
          _descriptionFallback(method, request.params);
      _emit(
        BridgeSseQuestionAsked(
          id: bridgeRequestId,
          sessionID: entry.sessionId,
          questions: [
            shared.QuestionInfo(question: reason, header: method).toJson(),
          ],
        ),
      );
    }
  }

  PluginPendingQuestion _toPluginPendingQuestion(_PendingApproval entry) {
    final reason =
        (entry.params["message"] as String?) ??
        (entry.params["reason"] as String?) ??
        _descriptionFallback(entry.method, entry.params);
    return PluginPendingQuestion(
      id: entry.bridgeRequestId,
      sessionID: entry.sessionId,
      questions: [
        PluginQuestionInfo(
          question: reason,
          header: entry.method,
          options: const [],
          multiple: false,
          custom: true,
        ),
      ],
    );
  }

  /// Builds the JSON-RPC result payload for a permission reply, keyed by the
  /// request's wire method so the v2 and legacy vocabularies stay correct:
  ///   - v2 command/file change → `{decision: accept|acceptForSession|decline}`
  ///   - legacy patch/exec       → `{decision: approved|approved_for_session|denied}`
  ///   - v2 permissions request  → `{permissions: GrantedPermissionProfile, scope}`
  Map<String, dynamic> _permissionResponse(
    _PendingApproval entry,
    PluginPermissionReply reply,
  ) {
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

    if (_v2DecisionMethods.contains(entry.method)) {
      final decision = switch (reply) {
        PluginPermissionReply.once => "accept",
        PluginPermissionReply.always => "acceptForSession",
        // `decline` lets the agent continue the turn; `cancel` would also
        // interrupt the whole turn, which is more than a single deny implies.
        PluginPermissionReply.reject => "decline",
      };
      return {"decision": decision};
    }

    // Legacy ReviewDecision vocabulary (applyPatchApproval / execCommandApproval).
    final decision = switch (reply) {
      PluginPermissionReply.once => "approved",
      PluginPermissionReply.always => "approved_for_session",
      PluginPermissionReply.reject => "denied",
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
      "item/fileChange/requestApproval" || "applyPatchApproval" => "patch",
      "item/commandExecution/requestApproval" || "execCommandApproval" => "exec",
      "item/permissions/requestApproval" => "permissions",
      _ => method,
    };
  }

  String _descriptionFallback(String method, Map<String, dynamic> params) {
    final command = params["command"];
    // v2 command/exec approvals carry `command` as a single string; the legacy
    // exec approval carries it as an argv list.
    if (command is String && command.isNotEmpty) return command;
    if (command is List && command.isNotEmpty) return command.join(" ");
    final fileChanges = params["fileChanges"];
    if (fileChanges is Map && fileChanges.isNotEmpty) {
      final files = fileChanges.keys.cast<String>().take(3).join(", ");
      return "Apply changes to $files";
    }
    final reason = params["reason"];
    if (reason is String && reason.isNotEmpty) return reason;
    return method;
  }

  String? _extractSessionId(Map<String, dynamic> params) {
    // v2 approvals carry `threadId`; legacy approvals carry `conversationId`.
    final thread = params["threadId"];
    if (thread is String && thread.isNotEmpty) return thread;
    final conversation = params["conversationId"];
    if (conversation is String && conversation.isNotEmpty) return conversation;
    return null;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}
