import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/codex_mcp_elicitation_dto.dart";
import "api/models/codex_pending_input.dart";
import "api/models/codex_user_input_dto.dart";
import "api/parsers/codex_question_parser.dart";
import "codex_app_server_client.dart";
import "repositories/mappers/codex_form_schema.dart";
import "repositories/mappers/codex_question_mapper.dart";

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

enum _ElicitationApprovalKind() {
  mcpToolCall,
  toolSuggestion,
}

sealed class _PendingCodexInput();

sealed class _PendingMcpRequest({
  required final Object codexId,
  required final String sessionId,
  required final String title,
  required final String message,
  required final ApprovalResponder respond,
}) extends _PendingCodexInput;

final class _PendingMcpForm({
  required super.codexId,
  required super.sessionId,
  required super.title,
  required super.message,
  required super.respond,
  required final CodexFormSchema schema,
}) extends _PendingMcpRequest;

final class _PendingMcpExternalAction({
  required super.codexId,
  required super.sessionId,
  required super.title,
  required super.message,
  required super.respond,
  required final String authorizationUrl,
}) extends _PendingMcpRequest;

// COMPATIBILITY 2026-10-15 (v1.9.2): v1.9.1 clients need cancel-only notices.
// Remove when supported production clients all consume typed forms/external actions.
const _mcpNotice = PluginQuestionInfo(
  header: "MCP request",
  question: "Open this native request in an updated Sesori client, or cancel it.",
  options: [PluginQuestionOption(label: "Cancel", description: "Cancel this native request.")],
  multiple: false,
  custom: false,
);

final class _PendingApproval({
  required final Object codexId,
  required final String method,
  required final Map<String, dynamic> params,
  required final ApprovalResponder respond,
  required final ApprovalErrorResponder respondError,
}) extends _PendingCodexInput;

final class _PendingAsyncQuestion({
  required final String sessionId,
  required final List<PluginQuestionInfo> questions,
  required final AsyncQuestionResponder respond,
  required final CodexQuestionMapper mapper,
}) extends _PendingCodexInput {
  Future<void> answer({required List<List<String>> answers}) => respond(
    sessionId: sessionId,
    text: mapper.asyncAnswerText(questions: questions, answers: answers),
  );
}

final class _PendingUserInput({
  required final Object codexId,
  required final CodexUserInputParamsDto input,
  required final ApprovalResponder respond,
  required final ApprovalErrorResponder respondError,
}) extends _PendingCodexInput;

/// Per-request reply functions injected at construction time so the
/// registry stays decoupled from [CodexAppServerClient].
typedef ApprovalResponder = void Function(Object id, Object? result);
typedef ApprovalErrorResponder = void Function(Object id, int code, String message);
typedef AsyncQuestionResponder = Future<void> Function({required String sessionId, required String text});
typedef PendingInputScopeResolver = ({String displaySessionId, List<String> sourceSessionIds}) Function({
  required String sessionId,
});

void _resolveCodexPermission({required _PendingCodexInput payload, required PluginPermissionReply reply}) {
  final approval = payload as _PendingApproval;
  approval.respond(approval.codexId, ApprovalRegistry._permissionResponse(approval, reply));
}

FutureOr<PendingQuestionReplyOutcome> _resolveCodexQuestion({
  required _PendingCodexInput payload,
  required List<List<String>> answers,
}) {
  switch (payload) {
    case _PendingMcpRequest():
      payload.respond(payload.codexId, const {"action": "cancel"});
      return PendingQuestionReplyOutcome.rejected;
    case _PendingApproval():
      throw StateError("Permission payload cannot be a question");
    case _PendingAsyncQuestion():
      return payload.answer(answers: answers).then((_) => PendingQuestionReplyOutcome.replied);
    case _PendingUserInput():
      final questions = payload.input.questions;
      payload.respond(payload.codexId, {
        "answers": {
          for (var i = 0; i < questions.length; i++)
            questions[i].id: {"answers": i < answers.length ? answers[i] : const <String>[]},
        },
      });
      return PendingQuestionReplyOutcome.replied;
  }
}

FutureOr<void> _rejectCodexQuestion({
  required _PendingCodexInput payload,
}) {
  switch (payload) {
    case _PendingMcpRequest():
      payload.respond(payload.codexId, const {"action": "cancel"});
    case _PendingAsyncQuestion():
      return payload.answer(answers: const []);
    case _PendingUserInput():
      payload.respondError(payload.codexId, -32603, "user rejected");
    case _PendingApproval():
      if (payload.method == _elicitationMethod) {
        payload.respond(payload.codexId, const {"action": "decline"});
      } else {
        payload.respondError(payload.codexId, -32603, "user rejected");
      }
  }
}

void _cancelCodexPending({required _PendingCodexInput payload, required PendingCancellationReason reason}) {
  // Async questions have no suspended server request. Teardown only retires
  // their local card; it must not start a new turn to send a cancellation.
  if (payload is _PendingAsyncQuestion) return;
  if (payload is _PendingMcpRequest) {
    payload.respond(payload.codexId, const {"action": "cancel"});
    return;
  }
  if (payload is _PendingUserInput) {
    payload.respondError(payload.codexId, -32000, _cancellationMessage(reason: reason));
    return;
  }
  payload as _PendingApproval;
  if (_permissionMethods.contains(payload.method) ||
      payload.method == _elicitationMethod && ApprovalRegistry._isMcpToolApproval(payload.params)) {
    payload.respond(payload.codexId, ApprovalRegistry._permissionResponse(payload, PluginPermissionReply.reject));
  } else if (payload.method == _elicitationMethod) {
    payload.respond(payload.codexId, const {"action": "cancel"});
  } else {
    payload.respondError(
      payload.codexId,
      -32000,
      _cancellationMessage(reason: reason),
    );
  }
}

String _cancellationMessage({required PendingCancellationReason reason}) => switch (reason) {
  PendingCancellationReason.sessionCancelled => "thread closed",
  PendingCancellationReason.disposed => "bridge dispose",
};

/// Routes codex server-originated approval requests to the bridge SSE
/// stream and answers them when the bridge consumer replies.
///
/// Subscribe with [attach]. Detach + free pending state with [dispose].
class ApprovalRegistry({
  required super.emit,
  required final ApprovalResponder _respond,
  required final ApprovalErrorResponder _respondError,
  required final PendingInputScopeResolver _resolvePendingInputScope,
  required final AsyncQuestionResponder _sendAsyncAnswer,
  required final CodexQuestionParser _questionParser,
  required final CodexQuestionMapper _questionMapper,
  super.idGenerator,
}) extends PendingPermissionRegistry<CodexPendingInput, _PendingCodexInput> {
  final Map<String, String> _nativeTurnIdByPendingId = {};

  this
    : super(
        logContext: "[codex]",
        resolvePermission: _resolveCodexPermission,
        resolveQuestion: _resolveCodexQuestion,
        rejectQuestion: _rejectCodexQuestion,
        cancelPending: _cancelCodexPending,
      );

  @override
  void handleRequest(CodexPendingInput input) {
    switch (input) {
      case CodexPendingRequest(:final request):
        _handleServerRequest(request: request);
      case CodexPendingNotification(:final notification):
        _handleNotification(notification: notification);
    }
  }

  void _handleServerRequest({required CodexServerRequest request}) {
    final method = request.method;
    final isMcpToolApproval = method == _elicitationMethod && _isMcpToolApproval(request.params);
    if (method == _elicitationMethod && !isMcpToolApproval) {
      _handleMcpRequest(request: request);
      return;
    }
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
    final displaySessionId = _resolvePendingInputScope(sessionId: resolvedSessionId).displaySessionId;

    final nativeTurnId = _extractNativeTurnId(request.params);
    final String pendingId;
    if (isPermission) {
      final allowAlways = _allowsAlways(entry);
      pendingId = registerPendingPermission(
        payload: entry,
        sessionId: resolvedSessionId,
        displaySessionId: displaySessionId,
        tool: _toolHintFor(method),
        description: _permissionDescriptionFor(entry),
        allowAlways: allowAlways,
      );
    } else if (method == _userInputMethod) {
      final input = _questionParser.parseUserInput(params: request.params);
      if (input.questions.any((question) => question.isSecret)) {
        _respondError(request.id, -32602, "Secret question input is not supported by Sesori.");
        return;
      }
      pendingId = registerPendingQuestion(
        interactionKind: PluginQuestionInteractionKind.question,
        payload: _PendingUserInput(codexId: request.id, input: input, respond: _respond, respondError: _respondError),
        sessionId: resolvedSessionId,
        displaySessionId: displaySessionId,
        questions: _questionMapper.mapUserInput(request: input),
      );
    } else {
      throw StateError("Unclassified native input method: $method");
    }
    if (nativeTurnId != null) {
      _nativeTurnIdByPendingId[pendingId] = nativeTurnId;
    }
  }

  void _handleMcpRequest({required CodexServerRequest request}) {
    try {
      final input = _questionParser.parseMcpElicitation(params: request.params);
      if (input.threadId.isEmpty || input.serverName.isEmpty || input.message == null) {
        throw const FormatException("Missing MCP request identity or message");
      }
      final _PendingMcpRequest payload;
      final PluginQuestionInteractionKind kind;
      switch (input.mode) {
        case CodexMcpElicitationMode.form:
          final schema = CodexFormSchema.parse(schema: input.requestedSchema);
          if (schema == null) throw const FormatException("Unsupported MCP form schema");
          payload = _PendingMcpForm(
            codexId: request.id,
            sessionId: input.threadId,
            title: input.serverName,
            message: input.message!,
            respond: _respond,
            schema: schema,
          );
          kind = PluginQuestionInteractionKind.form;
        case CodexMcpElicitationMode.url:
          if (input.url == null || input.url!.isEmpty || input.elicitationId == null || input.elicitationId!.isEmpty) {
            throw const FormatException("Missing MCP external action");
          }
          payload = _PendingMcpExternalAction(
            codexId: request.id,
            sessionId: input.threadId,
            title: input.serverName,
            message: input.message!,
            respond: _respond,
            authorizationUrl: input.url!,
          );
          kind = PluginQuestionInteractionKind.externalAction;
        case CodexMcpElicitationMode.unknown:
          throw const FormatException("Unsupported MCP request mode");
      }
      final id = registerPendingQuestion(
        interactionKind: kind,
        payload: payload,
        sessionId: input.threadId,
        displaySessionId: _resolvePendingInputScope(sessionId: input.threadId).displaySessionId,
        questions: const [_mcpNotice],
      );
      final turnId = _extractNativeTurnId(request.params);
      if (turnId != null) _nativeTurnIdByPendingId[id] = turnId;
    } on Object catch (error, stackTrace) {
      Log.w("[codex] unsupported MCP request ${request.id}", error, stackTrace);
      _respond(request.id, const {"action": "decline"});
      final sessionId = _extractSessionId(request.params);
      emitEvent(
        event: BridgeSseTuiToastShow(
          sessionID: sessionId == null ? null : _resolvePendingInputScope(sessionId: sessionId).displaySessionId,
          title: "MCP request unavailable",
          message: "This MCP form or external-action request is not supported by this bridge.",
          variant: "warning",
        ),
      );
    }
  }

  List<PluginPendingForm> pendingFormsForSession({required String sessionId}) => [
    for (final source in _resolvePendingInputScope(sessionId: sessionId).sourceSessionIds)
      for (final snapshot in pendingForSession(sessionId: source))
        if (pendingQuestionPayload(requestId: snapshot.id) case final _PendingMcpForm form)
          PluginPendingForm(
            id: snapshot.id,
            sessionID: source,
            displaySessionId: _resolvePendingInputScope(sessionId: sessionId).displaySessionId,
            title: form.title,
            message: form.message,
            fields: form.schema.fields,
          ),
  ];

  List<PluginPendingExternalAction> pendingExternalActionsForSession({required String sessionId}) => [
    for (final source in _resolvePendingInputScope(sessionId: sessionId).sourceSessionIds)
      for (final snapshot in pendingForSession(sessionId: source))
        if (pendingQuestionPayload(requestId: snapshot.id) case final _PendingMcpExternalAction action)
          PluginPendingExternalAction(
            id: snapshot.id,
            sessionID: source,
            displaySessionId: _resolvePendingInputScope(sessionId: sessionId).displaySessionId,
            title: action.title,
            message: action.message,
            authorizationUrl: action.authorizationUrl,
            purpose: PluginExternalActionPurpose.authorization,
            choices: PluginExternalActionChoice.values,
          ),
  ];

  PluginFormSubmissionResult replyForm({
    required String requestId,
    required String sessionId,
    required Map<String, PluginFormValue> values,
  }) {
    final payload = pendingQuestionPayload(requestId: requestId);
    if (payload is! _PendingMcpForm || payload.sessionId != sessionId) return const PluginFormAlreadySettled();
    final errors = payload.schema.validate(values: values);
    if (errors.isNotEmpty) return PluginFormValidationFailed(fieldErrors: errors);
    payload.respond(payload.codexId, {"action": "accept", "content": payload.schema.encode(values: values)});
    _settleMcp(requestId: requestId, outcome: PendingQuestionReplyOutcome.replied);
    return const PluginFormAccepted();
  }

  PluginFormDismissalResult declineForm({
    required String requestId,
    required String sessionId,
    required PluginFormDismissalChoice choice,
  }) {
    final payload = pendingQuestionPayload(requestId: requestId);
    if (payload is! _PendingMcpForm || payload.sessionId != sessionId) return PluginFormDismissalResult.alreadySettled;
    payload.respond(payload.codexId, {"action": choice.name});
    _settleMcp(requestId: requestId, outcome: PendingQuestionReplyOutcome.rejected);
    return PluginFormDismissalResult.accepted;
  }

  PluginExternalActionReply replyExternalAction({
    required String requestId,
    required String sessionId,
    required PluginExternalActionChoice choice,
  }) {
    final payload = pendingQuestionPayload(requestId: requestId);
    if (payload is! _PendingMcpExternalAction || payload.sessionId != sessionId) {
      return PluginExternalActionReply.alreadySettled;
    }
    payload.respond(payload.codexId, {"action": choice.name});
    _settleMcp(
      requestId: requestId,
      outcome: choice == PluginExternalActionChoice.accept
          ? PendingQuestionReplyOutcome.replied
          : PendingQuestionReplyOutcome.rejected,
    );
    return PluginExternalActionReply.accepted;
  }

  void _settleMcp({required String requestId, required PendingQuestionReplyOutcome outcome}) {
    settlePendingQuestion(requestId: requestId, outcome: outcome);
    _nativeTurnIdByPendingId.remove(requestId);
  }

  bool isTypedMcpRequest({required String requestId}) =>
      pendingQuestionPayload(requestId: requestId) is _PendingMcpRequest;

  bool cancelLegacyMcpRequest({required String requestId, required String? sessionId}) {
    final payload = pendingQuestionPayload(requestId: requestId);
    if (payload is! _PendingMcpRequest || payload.sessionId != sessionId) return false;
    payload.respond(payload.codexId, const {"action": "cancel"});
    _settleMcp(requestId: requestId, outcome: PendingQuestionReplyOutcome.rejected);
    return true;
  }

  /// Exact native turn carried by current server-request input for [sessionId].
  /// Returns null when metadata is absent or current inputs disagree.
  String? pendingNativeTurnIdForSession({required String sessionId}) {
    final turnIds = {
      for (final pendingId in _pendingIdsForSession(sessionId: sessionId)) ?_nativeTurnIdByPendingId[pendingId],
    };
    return turnIds.length == 1 ? turnIds.single : null;
  }

  @override
  void cancelForSession({required String sessionId}) {
    final pendingIds = _pendingIdsForSession(sessionId: sessionId);
    super.cancelForSession(sessionId: sessionId);
    _nativeTurnIdByPendingId.removeWhere((pendingId, _) => pendingIds.contains(pendingId));
  }

  @override
  bool replyPermission({required String requestId, required PluginPermissionReply reply}) {
    final replied = super.replyPermission(requestId: requestId, reply: reply);
    if (replied) _nativeTurnIdByPendingId.remove(requestId);
    return replied;
  }

  @override
  Future<bool> replyQuestion({required String requestId, required List<List<String>> answers}) async {
    final replied = await super.replyQuestion(requestId: requestId, answers: answers);
    if (replied) _nativeTurnIdByPendingId.remove(requestId);
    return replied;
  }

  @override
  Future<bool> rejectQuestion({required String requestId}) async {
    final rejected = await super.rejectQuestion(requestId: requestId);
    if (rejected) _nativeTurnIdByPendingId.remove(requestId);
    return rejected;
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    _nativeTurnIdByPendingId.clear();
  }

  Set<String> _pendingIdsForSession({required String sessionId}) => {
    ...pendingPermissionsForSession(sessionId: sessionId).map((pending) => pending.id),
    ...pendingForSession(sessionId: sessionId).map((pending) => pending.id),
  };

  /// `request_user_input_async` is delivered as an assistant message, not a
  /// server request. Both forms share the existing pending-question surface.
  void _handleNotification({required CodexServerNotification notification}) {
    final request = _questionParser.parseAsyncQuestion(notification: notification);
    if (request != null) {
      final questions = _questionMapper.mapAsyncQuestions(questions: request.questions);
      registerPendingQuestion(
        interactionKind: PluginQuestionInteractionKind.question,
        payload: _PendingAsyncQuestion(
          sessionId: request.threadId,
          questions: questions,
          respond: _sendAsyncAnswer,
          mapper: _questionMapper,
        ),
        sessionId: request.threadId,
        displaySessionId: _resolvePendingInputScope(sessionId: request.threadId).displaySessionId,
        questions: questions,
      );
    }
  }

  List<PluginPendingQuestion> pendingQuestionsForSessionTree({required String sessionId}) {
    final scope = _resolvePendingInputScope(sessionId: sessionId);
    return [
      for (final sourceSessionId in scope.sourceSessionIds)
        for (final question in pendingForSession(sessionId: sourceSessionId))
          question.copyWith(displaySessionId: scope.displaySessionId),
    ];
  }

  List<PluginPendingPermission> pendingPermissionsForSessionTree({required String sessionId}) {
    final scope = _resolvePendingInputScope(sessionId: sessionId);
    return [
      for (final sourceSessionId in scope.sourceSessionIds)
        for (final permission in pendingPermissionsForSession(sessionId: sourceSessionId))
          permission.copyWith(displaySessionId: scope.displaySessionId),
    ];
  }

  bool _allowsAlways(_PendingApproval entry) {
    if (entry.method != _elicitationMethod) return true;
    final persist = _asMap(entry.params["_meta"])?["persist"];
    return persist is List && persist.contains("always");
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

  String? _extractNativeTurnId(Map<String, dynamic> params) {
    final turnId = params["turnId"];
    if (turnId is! String) return null;
    final trimmed = turnId.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}
