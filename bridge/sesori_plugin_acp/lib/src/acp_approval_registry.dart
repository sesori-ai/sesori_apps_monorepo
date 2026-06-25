import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_protocol.dart";
import "acp_stdio_client.dart";

typedef AcpResponder = void Function(Object id, Object? result);
typedef AcpErrorResponder = void Function(Object id, int code, String message);

/// Builds the harness-specific reply payload for a pending question from the
/// bridge's `List<List<String>>` answers (outer = per question, inner =
/// selected values).
typedef AcpQuestionReplyBuilder = Object? Function(List<List<String>> answers);

enum _PendingKind { permission, question }

class _PendingApproval {
  _PendingApproval({
    required this.bridgeRequestId,
    required this.acpId,
    required this.sessionId,
    required this.kind,
    this.params = const {},
    this.questions = const [],
    this.replyBuilder,
  });

  final String bridgeRequestId;

  /// Original JSON-RPC `id` — echoed when responding.
  final Object acpId;
  final String sessionId;
  final _PendingKind kind;

  /// Raw request params (permission: carries the `options[]`).
  final Map<String, dynamic> params;

  /// Rendered questions for `getPendingQuestions` (question kind only).
  final List<PluginQuestionInfo> questions;

  /// Builds the reply payload (question kind only).
  final AcpQuestionReplyBuilder? replyBuilder;
}

/// Routes ACP server-originated requests to the bridge SSE stream and answers
/// them when the bridge consumer replies.
///
/// Handles the standard `session/request_permission` (the client must echo a
/// server-supplied `optionId`). Harness extensions (e.g. Cursor's
/// `cursor/ask_question`) are caught by overriding [handleExtensionRequest]
/// and registering a pending question via [addPendingQuestion].
class AcpApprovalRegistry {
  AcpApprovalRegistry({
    required void Function(BridgeSseEvent event) emit,
    required AcpResponder respond,
    required AcpErrorResponder respondError,
    String Function()? idGenerator,
    String? Function()? activeSessionResolver,
  }) : _emit = emit,
       _respond = respond,
       _respondError = respondError,
       _injectedIdGenerator = idGenerator,
       _activeSessionResolver = activeSessionResolver;

  /// Convenience constructor wiring the responders to an [AcpStdioClient].
  factory AcpApprovalRegistry.forClient({
    required AcpStdioClient client,
    required void Function(BridgeSseEvent event) emit,
    String Function()? idGenerator,
    String? Function()? activeSessionResolver,
  }) {
    return AcpApprovalRegistry(
      emit: emit,
      respond: (id, result) => client.respondToServerRequest(id: id, result: result),
      respondError: (id, code, message) =>
          client.respondToServerRequestWithError(id: id, code: code, message: message),
      idGenerator: idGenerator,
      activeSessionResolver: activeSessionResolver,
    );
  }

  final void Function(BridgeSseEvent event) _emit;
  final AcpResponder _respond;
  final AcpErrorResponder _respondError;
  final String Function()? _injectedIdGenerator;

  /// Resolves the session a server request belongs to when the request itself
  /// omits one. Some agents (Cursor's `cursor/create_plan`) send blocking
  /// requests with no `sessionId`; falling back to the active turn's session is
  /// the only signal tying the request to the conversation that triggered it.
  final String? Function()? _activeSessionResolver;

  StreamSubscription<AcpServerRequest>? _subscription;
  int _seq = 0;
  final Map<String, _PendingApproval> _pending = {};

  // --- Hooks / helpers for subclasses (public: cross-package subclassing) ---

  /// Emit a bridge event (e.g. from a subclass extension handler).
  void emit(BridgeSseEvent event) => _emit(event);

  /// Respond to a server request with a result payload.
  void respond(Object acpId, Object? result) => _respond(acpId, result);

  /// Respond to a server request with a JSON-RPC error.
  void respondError(Object acpId, int code, String message) =>
      _respondError(acpId, code, message);

  /// Generates the next stable bridge request id (`br-N`).
  String generateBridgeId() {
    final injected = _injectedIdGenerator;
    if (injected != null) return injected();
    _seq++;
    return "br-$_seq";
  }

  /// The session a server request belongs to: its explicit `sessionId` when
  /// present, otherwise the active turn's session (see [_activeSessionResolver]).
  /// Returns "" only when neither is available — the caller must treat that as
  /// unresolved (a request stamped with "" is dropped by the mobile client).
  String resolveSessionId(Map<String, dynamic> params) {
    final explicit = (params["sessionId"] as String?)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _activeSessionResolver?.call() ?? "";
  }

  /// Registers a pending question (used by extension handlers). Caller is
  /// responsible for emitting [BridgeSseQuestionAsked].
  void addPendingQuestion({
    required String bridgeRequestId,
    required Object acpId,
    required String sessionId,
    required List<PluginQuestionInfo> questions,
    required AcpQuestionReplyBuilder replyBuilder,
  }) {
    _pending[bridgeRequestId] = _PendingApproval(
      bridgeRequestId: bridgeRequestId,
      acpId: acpId,
      sessionId: sessionId,
      kind: _PendingKind.question,
      questions: questions,
      replyBuilder: replyBuilder,
    );
  }

  /// Override to handle harness-specific server requests (e.g. Cursor's
  /// `cursor/ask_question`). Return true if handled. Base handles none.
  bool handleExtensionRequest(AcpServerRequest request) => false;

  // --- Lifecycle ---

  StreamSubscription<AcpServerRequest> attach(Stream<AcpServerRequest> stream) {
    final subscription = stream.listen(_handle);
    _subscription = subscription;
    return subscription;
  }

  Future<void> dispose() async {
    // Isolated so a failed cancel cannot skip the pending-approval cleanup
    // below, which unblocks callers awaiting a permission/question reply.
    try {
      await _subscription?.cancel();
    } on Object catch (e, st) {
      Log.w("[acp] failed to cancel approval subscription", e, st);
    }
    _subscription = null;
    final remaining = List<_PendingApproval>.from(_pending.values);
    _pending.clear();
    for (final entry in remaining) {
      try {
        if (entry.kind == _PendingKind.permission) {
          _respond(entry.acpId, const {
            "outcome": {"outcome": "cancelled"},
          });
        } else {
          _respondError(entry.acpId, -32000, "bridge dispose");
        }
      } catch (_) {
        // Best-effort.
      }
    }
  }

  // --- Queries ---

  List<PluginPendingQuestion> pendingForSession(String sessionId) {
    return _pending.values
        .where((e) => e.kind == _PendingKind.question && e.sessionId == sessionId)
        .map(_toPluginPendingQuestion)
        .toList(growable: false);
  }

  List<PluginPendingPermission> pendingPermissionsForSession(String sessionId) {
    return _pending.values
        .where((e) => e.kind == _PendingKind.permission && e.sessionId == sessionId)
        .map(_toPluginPendingPermission)
        .toList(growable: false);
  }

  List<PluginPendingQuestion> pendingForProject(Iterable<String> sessionIds) {
    final set = Set<String>.from(sessionIds);
    return _pending.values
        .where((e) => e.kind == _PendingKind.question && set.contains(e.sessionId))
        .map(_toPluginPendingQuestion)
        .toList(growable: false);
  }

  String? sessionIdFor(String bridgeRequestId) =>
      _pending[bridgeRequestId]?.sessionId;

  /// Whether [sessionId] is blocked awaiting user input — a pending permission
  /// ask or question. Both kinds count, mirroring the OpenCode tracker's
  /// "awaiting input" notion (see `_rootHasPendingInput`).
  bool hasPendingInput(String sessionId) =>
      _pending.values.any((e) => e.sessionId == sessionId);

  // --- Replies ---

  /// Acknowledges a permission ask. Maps the once/always/reject decision onto
  /// the server-supplied option whose `kind` matches and echoes its
  /// `optionId` (ACP requires the client to select a provided option).
  bool replyPermission(String bridgeRequestId, PluginPermissionReply reply) {
    final entry = _pending.remove(bridgeRequestId);
    if (entry == null || entry.kind != _PendingKind.permission) return false;
    final optionId = _selectOptionId(_optionsFrom(entry.params), reply);
    if (optionId == null) {
      _respond(entry.acpId, const {
        "outcome": {"outcome": "cancelled"},
      });
    } else {
      _respond(entry.acpId, {
        "outcome": {"outcome": "selected", "optionId": optionId},
      });
    }
    _emit(
      BridgeSsePermissionReplied(
        requestID: bridgeRequestId,
        sessionID: entry.sessionId,
        // ACP agents have no sub-agent hierarchy, so a request's display root
        // is its own session.
        displaySessionId: entry.sessionId,
        reply: reply.name,
      ),
    );
    return true;
  }

  bool replyQuestion(String bridgeRequestId, List<List<String>> answers) {
    final entry = _pending.remove(bridgeRequestId);
    if (entry == null || entry.kind != _PendingKind.question) return false;
    final payload = entry.replyBuilder?.call(answers) ??
        {"answers": answers.map((row) => row.toList()).toList()};
    _respond(entry.acpId, payload);
    _emit(
      BridgeSseQuestionReplied(
        requestID: bridgeRequestId,
        sessionID: entry.sessionId,
        displaySessionId: entry.sessionId,
      ),
    );
    return true;
  }

  bool rejectQuestion(String bridgeRequestId) {
    final entry = _pending.remove(bridgeRequestId);
    if (entry == null || entry.kind != _PendingKind.question) return false;
    _respondError(entry.acpId, -32603, "user rejected");
    _emit(
      BridgeSseQuestionRejected(
        requestID: bridgeRequestId,
        sessionID: entry.sessionId,
        displaySessionId: entry.sessionId,
      ),
    );
    return true;
  }

  // --- Internals ---

  void _handle(AcpServerRequest request) {
    if (request.method == AcpMethods.sessionRequestPermission) {
      _handlePermission(request);
      return;
    }
    if (handleExtensionRequest(request)) return;
    _respondError(
      request.id,
      -32601,
      "method not handled by bridge: ${request.method}",
    );
  }

  void _handlePermission(AcpServerRequest request) {
    final sessionId = resolveSessionId(request.params);
    final bridgeRequestId = generateBridgeId();
    _pending[bridgeRequestId] = _PendingApproval(
      bridgeRequestId: bridgeRequestId,
      acpId: request.id,
      sessionId: sessionId,
      kind: _PendingKind.permission,
      params: request.params,
    );
    final summary = _permissionSummary(request.params);
    _emit(
      BridgeSsePermissionAsked(
        requestID: bridgeRequestId,
        sessionID: sessionId,
        // ACP agents have no sub-agent hierarchy, so a request's display root
        // is its own session.
        displaySessionId: sessionId,
        tool: summary.tool,
        description: summary.description,
      ),
    );
  }

  /// Derives the tool hint and human description from a permission request's
  /// `toolCall` params. Shared by the asked event and the pending-list
  /// snapshot so both stay in sync.
  ({String tool, String description}) _permissionSummary(
    Map<String, dynamic> params,
  ) {
    final toolCall = _asMap(params["toolCall"]) ?? const {};
    return (
      tool: (toolCall["kind"] as String?) ?? "tool",
      description: (toolCall["title"] as String?) ??
          (toolCall["toolCallId"] as String?) ??
          "permission requested",
    );
  }

  PluginPendingQuestion _toPluginPendingQuestion(_PendingApproval entry) {
    return PluginPendingQuestion(
      id: entry.bridgeRequestId,
      sessionID: entry.sessionId,
      displaySessionId: entry.sessionId,
      questions: entry.questions,
    );
  }

  PluginPendingPermission _toPluginPendingPermission(_PendingApproval entry) {
    final summary = _permissionSummary(entry.params);
    return PluginPendingPermission(
      id: entry.bridgeRequestId,
      sessionID: entry.sessionId,
      displaySessionId: entry.sessionId,
      tool: summary.tool,
      description: summary.description,
    );
  }

  List<Map<String, dynamic>> _optionsFrom(Map<String, dynamic> params) {
    final raw = params["options"];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, dynamic>())
        .toList(growable: false);
  }

  String? _selectOptionId(
    List<Map<String, dynamic>> options,
    PluginPermissionReply reply,
  ) {
    final preference = switch (reply) {
      PluginPermissionReply.once => const ["allow_once", "allow_always"],
      PluginPermissionReply.always => const ["allow_always", "allow_once"],
      PluginPermissionReply.reject => const ["reject_once", "reject_always"],
    };
    for (final kind in preference) {
      for (final option in options) {
        if (option["kind"] == kind) return option["optionId"] as String?;
      }
    }
    return null;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}
