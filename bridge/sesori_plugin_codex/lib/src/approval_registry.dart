import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "codex_app_server_client.dart";

/// Codex methods that we surface as permission asks.
///
/// These are the JSON-RPC method names sent as server-originated requests
/// when codex needs the user to allow / deny a destructive action.
const Set<String> _permissionMethods = {
  "applyPatchApproval",
  "fileChangeRequestApproval",
  "execCommandApproval",
  "commandExecutionRequestApproval",
  "permissionsRequestApproval",
};

/// Codex methods that we surface as questions (free-form user input or
/// MCP-driven elicitations). These get rendered by mobile as a question
/// prompt rather than the binary allow/deny UI.
const Set<String> _questionMethods = {
  "mcpServerElicitationRequest",
  "toolRequestUserInput",
};

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

  /// Cancels the subscription and rejects every still-pending approval
  /// with a `denied` decision so codex doesn't wait forever.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    final remaining = List<_PendingApproval>.from(_pending.values);
    _pending.clear();
    for (final entry in remaining) {
      try {
        if (entry.kind == _PendingKind.permission) {
          _respond(entry.codexId, _decisionPayload("denied"));
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
    final decision = switch (reply) {
      PluginPermissionReply.once => "approved",
      PluginPermissionReply.always => "approved_for_session",
      PluginPermissionReply.reject => "denied",
    };
    _respond(entry.codexId, _decisionPayload(decision));
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
    // For Phase 5 MVP we send the flat answers array as the codex
    // response. The exact codex schema per method
    // (mcpServerElicitationRequest, toolRequestUserInput) varies; this
    // shape is plenty for the simple text-input case and can be widened
    // once we have a Phase-6 trace from a real elicitation in the wild.
    _respond(entry.codexId, {
      "answers": answers.map((row) => row.toList()).toList(),
    });
    _emit(
      BridgeSseQuestionReplied(
        requestID: bridgeRequestId,
        sessionID: entry.sessionId,
      ),
    );
    return true;
  }

  /// Reject an elicitation. Codex receives a JSON-RPC error response.
  bool rejectQuestion(String bridgeRequestId) {
    final entry = _pending.remove(bridgeRequestId);
    if (entry == null || entry.kind != _PendingKind.question) return false;
    _respondError(entry.codexId, -32603, "user rejected");
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
      _emit(
        BridgeSseQuestionAsked(
          id: bridgeRequestId,
          sessionID: entry.sessionId,
          questions: [
            {
              "method": method,
              "params": request.params,
            },
          ],
        ),
      );
    }
  }

  PluginPendingQuestion _toPluginPendingQuestion(_PendingApproval entry) {
    final reason =
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

  String _toolHintFor(String method) {
    return switch (method) {
      "applyPatchApproval" || "fileChangeRequestApproval" => "patch",
      "execCommandApproval" || "commandExecutionRequestApproval" => "exec",
      "permissionsRequestApproval" => "permissions",
      _ => method,
    };
  }

  String _descriptionFallback(String method, Map<String, dynamic> params) {
    final command = params["command"];
    if (command is List && command.isNotEmpty) {
      return command.join(" ");
    }
    final fileChanges = params["fileChanges"];
    if (fileChanges is Map && fileChanges.isNotEmpty) {
      final files = fileChanges.keys.cast<String>().take(3).join(", ");
      return "Apply changes to $files";
    }
    return method;
  }

  String? _extractSessionId(Map<String, dynamic> params) {
    final thread = params["threadId"];
    if (thread is String && thread.isNotEmpty) return thread;
    final conversation = params["conversationId"];
    if (conversation is String && conversation.isNotEmpty) return conversation;
    return null;
  }

  Map<String, dynamic> _decisionPayload(String decision) {
    return {"decision": decision};
  }
}
