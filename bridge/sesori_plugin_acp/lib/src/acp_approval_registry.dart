import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_pending_registry.dart";
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

enum AcpQuestionResolution() {
  declined,
  cancelled,
}

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
  if (payload is! _AcpPendingPermission) throw StateError("Only a permission payload takes a permission reply");
  final optionId = _selectOptionId(options: _optionsFrom(payload.params), reply: reply);
  if (optionId == null) {
    payload.respond(payload.acpId, const {
      "outcome": {"outcome": "cancelled"},
    });
    return;
  }
  payload.respond(payload.acpId, {
    "outcome": {"outcome": "selected", "optionId": optionId},
  });
}

PendingQuestionReplyOutcome _resolveAcpQuestion({
  required _AcpPendingPayload payload,
  required List<List<String>> answers,
}) {
  if (payload is! _AcpPendingQuestion) throw StateError("Only a question payload takes a question reply");
  final question = payload;
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
  if (payload is! _AcpPendingQuestion) throw StateError("Only a question payload can be rejected");
  _sendAcpQuestionResolution(
    payload,
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
  required super.idGenerator,

  /// Resolves the session a server request belongs to when the request itself
  /// omits one. Some agents send blocking requests with no `sessionId`.
  required final String? Function()? _activeSessionResolver,
}) extends AcpPendingRegistry<_AcpPendingPayload> {
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
    required String Function()? idGenerator,
    required String? Function()? activeSessionResolver,
  }) {
    return AcpApprovalRegistry(
      emit: emit,
      respond: (id, result) => client.respondToServerRequest(id: id, result: result),
      respondError: (id, code, message) => client.respondToServerRequestWithError(id: id, code: code, message: message),
      idGenerator: idGenerator,
      activeSessionResolver: activeSessionResolver,
    );
  }

  /// Rejects a request whose tool-call id matches more than one live session.
  /// No active-turn fallback is safe because it could present and approve the
  /// request under the wrong source context.
  @override
  void rejectAmbiguousServerRequest({required AcpServerRequest request}) {
    Log.w("[acp] server request has ambiguous tool-call session attribution; cancelling");
    switch (request.method) {
      case AcpMethods.sessionRequestPermission:
        _respond(request.id, const {
          "outcome": {"outcome": "cancelled"},
        });
      case AcpMethods.elicitationCreate:
        _respond(request.id, const {"action": "cancel"});
      default:
        _respondError(request.id, -32602, "ambiguous tool-call session attribution");
    }
  }

  /// Responds to a server request with a result payload.
  void respond({required Object acpId, required Object? result}) => _respond(acpId, result);

  /// Responds to a server request with a JSON-RPC error.
  void respondError({required Object acpId, required int code, required String message}) =>
      _respondError(acpId, code, message);

  /// Resolves the request's explicit `sessionId`, or the active turn's session
  /// when omitted. Returns `null` when no session can be resolved.
  String? resolveSessionId(Map<String, dynamic> params) {
    final rawSessionId = params["sessionId"];
    if (rawSessionId != null && rawSessionId is! String) return null;
    final explicit = rawSessionId is String ? rawSessionId.trim() : null;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final active = _activeSessionResolver?.call();
    return active == null || active.isEmpty ? null : active;
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
      interactionKind: PluginQuestionInteractionKind.question,
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

  /// Override when the agent pairs an elicitation choice property with a
  /// free-text "other" property, so the two map to one question. Returns the
  /// paired key for [choiceKey], or null; the base pairs none.
  String? elicitationCustomAnswerKey({required String choiceKey, required Set<String> propertyKeys}) => null;

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
    if (sessionId == null) {
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
    if (sessionId == null) {
      Log.w("[acp] elicitation with no resolvable session; cancelling");
      _respond(request.id, const {"action": "cancel"});
      return;
    }
    final form = AcpElicitationMapper(customAnswerKeyFor: elicitationCustomAnswerKey).parse(params: request.params);
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

String? _selectOptionId({required List<Map<String, dynamic>> options, required PluginPermissionReply reply}) {
  final preference = switch (reply) {
    PluginPermissionReply.once => const ["allow_once"],
    PluginPermissionReply.always => const ["allow_always", "allow_once"],
    PluginPermissionReply.reject => const ["reject_once", "reject_always"],
  };
  for (final kind in preference) {
    for (final option in options) {
      if (option["kind"] == kind) {
        return switch (option["optionId"]) {
          final String? optionId => optionId,
          final other => throw FormatException("permission optionId is not a string: ${other.runtimeType}"),
        };
      }
    }
  }
  return null;
}
