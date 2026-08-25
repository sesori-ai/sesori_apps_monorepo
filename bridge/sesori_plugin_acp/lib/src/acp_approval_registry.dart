import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_protocol.dart";
import "acp_stdio_client.dart";
import "repositories/mappers/acp_elicitation_mapper.dart";

typedef AcpResponder = void Function(Object id, Object? result);
typedef AcpErrorResponder = void Function(Object id, int code, String message);

/// Builds the harness-specific reply payload for a pending question from the
/// bridge's `List<List<String>>` answers (outer = per question, inner =
/// selected values).
typedef AcpQuestionReplyBuilder = Object? Function(List<List<String>> answers);
typedef AcpQuestionResolutionBuilder = Object? Function(AcpQuestionResolution resolution);

enum AcpQuestionResolution() { declined, cancelled }

sealed class const _AcpPendingPayload({required final Object acpId});

final class const _AcpPendingPermission({
  required super.acpId,
  required final Map<String, dynamic> params,
  required final AcpResponder respond,
}) extends _AcpPendingPayload;

final class const _AcpPendingQuestion({
  required super.acpId,
  required final AcpQuestionReplyBuilder replyBuilder,
  required final AcpQuestionResolutionBuilder? resolutionBuilder,
  required final AcpResponder respond,
  required final AcpErrorResponder respondError,
}) extends _AcpPendingPayload;

void _resolveAcpPermission({required _AcpPendingPayload payload, required PluginPermissionReply reply}) {
  final permission = payload as _AcpPendingPermission;
  final optionId = _selectOptionId(_optionsFrom(permission.params), reply);
  if (optionId == null) {
    permission.respond(permission.acpId, const {
      "outcome": {"outcome": "cancelled"},
    });
    return;
  }
  permission.respond(permission.acpId, {
    "outcome": {"outcome": "selected", "optionId": optionId},
  });
}

PendingQuestionReplyOutcome _resolveAcpQuestion({
  required _AcpPendingPayload payload,
  required List<List<String>> answers,
}) {
  final question = payload as _AcpPendingQuestion;
  Object? result;
  try {
    result = question.replyBuilder(answers);
  } on Object catch (error, stack) {
    Log.w("[acp] invalid question reply; declining request", error, stack);
    _sendAcpQuestionResolution(
      question,
      resolution: AcpQuestionResolution.declined,
      fallbackErrorMessage: "invalid answer",
    );
    return PendingQuestionReplyOutcome.rejected;
  }
  question.respond(question.acpId, result);
  return PendingQuestionReplyOutcome.replied;
}

void _rejectAcpQuestion({required _AcpPendingPayload payload}) {
  _sendAcpQuestionResolution(
    payload as _AcpPendingQuestion,
    resolution: AcpQuestionResolution.declined,
    fallbackErrorMessage: "user rejected",
  );
}

void _cancelAcpPending({required _AcpPendingPayload payload, required PendingCancellationReason reason}) {
  switch (payload) {
    case _AcpPendingPermission(:final acpId, :final respond):
      respond(acpId, const {
        "outcome": {"outcome": "cancelled"},
      });
    case final _AcpPendingQuestion question:
      _sendAcpQuestionResolution(
        question,
        resolution: AcpQuestionResolution.cancelled,
        fallbackErrorMessage: switch (reason) {
          PendingCancellationReason.sessionCancelled => "aborted",
          PendingCancellationReason.disposed => "bridge dispose",
        },
      );
  }
}

void _sendAcpQuestionResolution(
  _AcpPendingQuestion question, {
  required AcpQuestionResolution resolution,
  required String fallbackErrorMessage,
}) {
  final builder = question.resolutionBuilder;
  if (builder == null) {
    question.respondError(question.acpId, -32603, fallbackErrorMessage);
    return;
  }
  question.respond(question.acpId, builder(resolution));
}

/// Routes ACP server-originated requests to the bridge SSE stream and answers
/// them when the bridge consumer replies.
///
/// Handles the standard `session/request_permission` and elicitation methods.
/// Harness extensions override [handleExtensionRequest] and register questions
/// with [addPendingQuestion].
class AcpApprovalRegistry({
  required super.emit,
  required final AcpResponder _respond,
  required final AcpErrorResponder _respondError,
  super.idGenerator,

  /// Resolves the session a server request belongs to when the request itself
  /// omits one. Some agents send blocking requests with no `sessionId`.
  final String? Function()? _activeSessionResolver,
}) extends PendingPermissionRegistry<AcpServerRequest, _AcpPendingPayload> {
  this
    : super(
        logContext: "[acp]",
        resolvePermission: _resolveAcpPermission,
        resolveQuestion: _resolveAcpQuestion,
        rejectQuestion: _rejectAcpQuestion,
        cancelPending: _cancelAcpPending,
      );

  /// Convenience constructor wiring the responders to an [AcpStdioClient].
  factory forClient({
    required AcpStdioClient client,
    required void Function(BridgeSseEvent event) emit,
    String Function()? idGenerator,
    String? Function()? activeSessionResolver,
  }) {
    return AcpApprovalRegistry(
      emit: emit,
      respond: (id, result) => client.respondToServerRequest(id: id, result: result),
      respondError: (id, code, message) => client.respondToServerRequestWithError(id: id, code: code, message: message),
      idGenerator: idGenerator,
      activeSessionResolver: activeSessionResolver,
    );
  }

  /// Responds to a server request with a result payload.
  void respond(Object acpId, Object? result) => _respond(acpId, result);

  /// Responds to a server request with a JSON-RPC error.
  void respondError(Object acpId, int code, String message) => _respondError(acpId, code, message);

  /// Resolves the request's explicit `sessionId`, or the active turn's session
  /// when omitted. Returns an empty string when no session can be resolved.
  String resolveSessionId(Map<String, dynamic> params) {
    final rawSessionId = params["sessionId"];
    if (rawSessionId != null && rawSessionId is! String) return "";
    final explicit = rawSessionId is String ? rawSessionId.trim() : null;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _activeSessionResolver?.call() ?? "";
  }

  /// Registers and emits a harness-specific pending question.
  String addPendingQuestion({
    required Object acpId,
    required String sessionId,
    required List<PluginQuestionInfo> questions,
    required AcpQuestionReplyBuilder replyBuilder,
    required AcpQuestionResolutionBuilder? resolutionBuilder,
  }) {
    return registerPendingQuestion(
      payload: _AcpPendingQuestion(
        acpId: acpId,
        replyBuilder: replyBuilder,
        resolutionBuilder: resolutionBuilder,
        respond: _respond,
        respondError: _respondError,
      ),
      sessionId: sessionId,
      displaySessionId: sessionId,
      questions: questions,
    );
  }

  /// Override to handle harness-specific server requests. Returns true when
  /// handled; the base handles none.
  bool handleExtensionRequest(AcpServerRequest request) => false;

  @override
  void handleRequest(AcpServerRequest request) {
    if (request.method == AcpMethods.sessionRequestPermission) {
      _handlePermission(request);
      return;
    }
    if (request.method == AcpMethods.elicitationCreate) {
      _handleElicitation(request);
      return;
    }
    if (handleExtensionRequest(request)) return;
    _respondError(request.id, -32601, "method not handled by bridge: ${request.method}");
  }

  void _handlePermission(AcpServerRequest request) {
    final sessionId = resolveSessionId(request.params);
    if (sessionId.isEmpty) {
      Log.w("[acp] permission request with no resolvable session; auto-cancelling");
      _respond(request.id, const {
        "outcome": {"outcome": "cancelled"},
      });
      return;
    }
    final summary = _permissionSummary(request.params);
    registerPendingPermission(
      payload: _AcpPendingPermission(acpId: request.id, params: request.params, respond: _respond),
      sessionId: sessionId,
      displaySessionId: sessionId,
      tool: summary.tool,
      description: summary.description,
      allowAlways: _allowsAlways(request.params),
    );
  }

  void _handleElicitation(AcpServerRequest request) {
    final sessionId = resolveSessionId(request.params);
    if (sessionId.isEmpty) {
      Log.w("[acp] elicitation with no resolvable session; cancelling");
      _respond(request.id, const {"action": "cancel"});
      return;
    }
    final form = const AcpElicitationMapper().parse(params: request.params);
    switch (form) {
      case AcpUnsupportedElicitationForm(:final reason):
        Log.w("[acp] declining elicitation: $reason");
        _respond(request.id, const {"action": "decline"});
      case AcpSupportedElicitationForm(:final questions):
        addPendingQuestion(
          acpId: request.id,
          sessionId: sessionId,
          questions: questions,
          replyBuilder: (answers) => form.buildResponse(answers: answers),
          resolutionBuilder: (resolution) => {
            "action": switch (resolution) {
              AcpQuestionResolution.declined => "decline",
              AcpQuestionResolution.cancelled => "cancel",
            },
          },
        );
    }
  }

  ({String tool, String description}) _permissionSummary(Map<String, dynamic> params) {
    final toolCall = _asMap(params["toolCall"]) ?? const {};
    return (
      tool: _str(toolCall["kind"]) ?? "tool",
      description: _str(toolCall["title"]) ?? _str(toolCall["toolCallId"]) ?? "permission requested",
    );
  }

  static String? _str(Object? value) => value is String && value.isNotEmpty ? value : null;

  bool _allowsAlways(Map<String, dynamic> params) =>
      _optionsFrom(params).any((option) => option["kind"] == "allow_always");

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}

List<Map<String, dynamic>> _optionsFrom(Map<String, dynamic> params) {
  final raw = params["options"];
  if (raw is! List) return const [];
  return raw.whereType<Map<dynamic, dynamic>>().map((map) => map.cast<String, dynamic>()).toList(growable: false);
}

String? _selectOptionId(List<Map<String, dynamic>> options, PluginPermissionReply reply) {
  final preference = switch (reply) {
    PluginPermissionReply.once => const ["allow_once"],
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
