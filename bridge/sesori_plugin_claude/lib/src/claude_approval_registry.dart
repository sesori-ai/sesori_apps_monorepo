import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show stripAnsi;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/claude_stream_message.dart";
import "claude_form_schema.dart";
import "models/claude_permission_mode.dart";

typedef ClaudeApprovalResponder = bool Function({
  required String sessionId,
  required String requestId,
  required Map<String, Object?> payload,
});

sealed class const _PendingApproval({
  required final String id,
  required final String requestId,
  required final String sessionId,
});

final class const _PendingPermission({
  required super.id,
  required super.requestId,
  required super.sessionId,
  required final String tool,
  required final String description,
  required final Map<String, Object?> input,

  /// What an Always answer grants; null when Claude suppresses Always or
  /// suggests nothing Sesori can grant for the session.
  required final _AlwaysGrant? alwaysGrant,
}) extends _PendingApproval {
  bool get allowAlways => alwaysGrant != null;
}

/// What Always grants for the rest of the session, sent back to Claude as
/// `updatedPermissions`.
sealed class const _AlwaysGrant() {
  List<Map<String, Object?>> get updatedPermissions;
}

/// Allow rules Claude suggested, already scoped to the session.
final class const _SessionRulesGrant({required final List<Map<String, Object?>> rules}) extends _AlwaysGrant {
  @override
  List<Map<String, Object?>> get updatedPermissions => rules;
}

/// Switching the session to accept-edits, Claude's only suggestion for a file
/// edit, as Always does in Claude Code's own terminal.
final class const _AcceptEditsGrant() extends _AlwaysGrant {
  @override
  List<Map<String, Object?>> get updatedPermissions => [
    {"type": "setMode", "mode": ClaudePermissionMode.acceptEdits.controlValue, "destination": "session"},
  ];
}

final class const _PendingExternalAction({
  required super.id,
  required super.requestId,
  required super.sessionId,
  required final String title,
  required final String message,
  required final String authorizationUrl,
}) extends _PendingApproval;

final class const _PendingForm({
  required super.id,
  required super.requestId,
  required super.sessionId,
  required final String title,
  required final String message,
  required final ClaudeFormSchema schema,
}) extends _PendingApproval;

// COMPATIBILITY 2026-10-15 (v1.9.2): public v1.9.1 clients need cancel-only questions.
// Remove when all supported production clients consume typed forms.
const _formNotice = PluginQuestionInfo(
  header: "MCP form",
  question: "This native request needs a form. Open it in an updated Sesori client, or cancel it.",
  options: [PluginQuestionOption(label: "Cancel", description: "Cancel this native request.", isDefault: false)],
  multiple: false,
  custom: false,
);

// COMPATIBILITY 2026-10-15 (v1.9.2): public v1.9.1 clients need cancel-only questions.
// Remove when all supported production clients consume typed external actions.
const _externalActionNotice = PluginQuestionInfo(
  header: "MCP authorization",
  question: "This native request needs an external action. Open it in an updated Sesori client, or cancel it.",
  options: [PluginQuestionOption(label: "Cancel", description: "Cancel this native request.", isDefault: false)],
  multiple: false,
  custom: false,
);

sealed class const _PendingQuestion({
  required super.id,
  required super.requestId,
  required super.sessionId,
  required final Map<String, Object?> input,
  required final List<PluginQuestionInfo> questions,
}) extends _PendingApproval {
  Map<String, Object?> updatedInput({required List<List<String>> answers});
}

final class const _AskUserQuestion({
  required super.id,
  required super.requestId,
  required super.sessionId,
  required super.input,
  required super.questions,
}) extends _PendingQuestion {
  @override
  Map<String, Object?> updatedInput({required List<List<String>> answers}) => {
    ...input,
    "answers": {
      for (var index = 0; index < questions.length && index < answers.length; index++)
        questions[index].question: answers[index].join(", "),
    },
  };
}

final class const _ExitPlanMode({
  required super.id,
  required super.requestId,
  required super.sessionId,
  required super.input,
  required super.questions,
}) extends _PendingQuestion {
  @override
  Map<String, Object?> updatedInput({required List<List<String>> answers}) => input;
}

final class const _UnknownInteraction({
  required super.id,
  required super.requestId,
  required super.sessionId,
  required super.input,
  required super.questions,
}) extends _PendingQuestion {
  @override
  Map<String, Object?> updatedInput({required List<List<String>> answers}) => input;
}

/// Owns pending Claude permission and interaction requests until the phone
/// answers them or their session is torn down.
final class ClaudeApprovalRegistry({
  required final void Function(BridgeSseEvent event) _emit,
  required final ClaudeApprovalResponder _respond,
}) {
  final Map<String, _PendingApproval> _pending = {};
  final Map<String, Set<String>> _allowedTools = {};

  /// Sessions whose Always on a file edit switched them to accept-edits.
  final Set<String> _acceptEditsSessions = {};
  int _sequence = 0;

  void handle({required String sessionId, required ClaudeControlRequestMessage message}) {
    final attributedSessionId = _nonEmptyString(sessionId);
    final requestId = _nonEmptyString(message.requestId);
    if (attributedSessionId == null || requestId == null) return;
    switch (message.subtype) {
      case ClaudeControlRequestSubtype.elicitation:
        _handleElicitation(sessionId: attributedSessionId, requestId: requestId, request: message.request);
        return;
      case ClaudeControlRequestSubtype.unknown:
        return;
      case ClaudeControlRequestSubtype.canUseTool:
        break;
    }

    final request = message.request;
    final tool = _nonEmptyString(request["tool_name"]) ?? "tool";
    final input = _map(request["input"]);
    final id = "br-${++_sequence}";
    if (request["requires_user_interaction"] == true) {
      final pending = switch (tool) {
        "AskUserQuestion" => _AskUserQuestion(
          id: id,
          requestId: requestId,
          sessionId: attributedSessionId,
          input: input,
          questions: _askUserQuestions(input: input),
        ),
        "ExitPlanMode" => _ExitPlanMode(
          id: id,
          requestId: requestId,
          sessionId: attributedSessionId,
          input: input,
          questions: _planApprovalQuestions(input: input),
        ),
        _ => _UnknownInteraction(
          id: id,
          requestId: requestId,
          sessionId: attributedSessionId,
          input: input,
          questions: _interactionQuestions(tool: tool, request: request),
        ),
      };
      _pending[id] = pending;
      _emitActivity(
        event: BridgeSseQuestionAsked(
          interactionKind: PluginQuestionInteractionKind.question,
          id: id,
          sessionID: attributedSessionId,
          displaySessionId: attributedSessionId,
          questions: pending.questions,
        ),
      );
      return;
    }

    final pending = _PendingPermission(
      id: id,
      requestId: requestId,
      sessionId: attributedSessionId,
      tool: tool,
      description: _description(request),
      input: input,
      alwaysGrant: request["suppress_always_allow_rule"] == true
          ? null
          : _alwaysGrant(suggestions: request["permission_suggestions"]),
    );
    _pending[id] = pending;
    _emitActivity(
      event: BridgeSsePermissionAsked(
        requestID: id,
        sessionID: attributedSessionId,
        displaySessionId: attributedSessionId,
        tool: pending.tool,
        description: pending.description,
        allowAlways: pending.allowAlways,
      ),
    );
  }

  void _handleElicitation({
    required String sessionId,
    required String requestId,
    required Map<String, Object?> request,
  }) {
    if (request["mode"] == null || request["mode"] == "form") {
      final schema = ClaudeFormSchema.parse(schema: request["requested_schema"]);
      if (schema != null) {
        final id = "br-${++_sequence}";
        _pending[id] = _PendingForm(
          id: id,
          requestId: requestId,
          sessionId: sessionId,
          title: _nonEmptyString(request["mcp_server_name"]) ?? "MCP form",
          message: _nonEmptyString(request["message"]) ?? "Complete this native request.",
          schema: schema,
        );
        _emitActivity(
          event: BridgeSseQuestionAsked(
            interactionKind: PluginQuestionInteractionKind.form,
            id: id,
            sessionID: sessionId,
            displaySessionId: sessionId,
            questions: const [_formNotice],
          ),
        );
        return;
      }
    }
    final url = _nonEmptyString(request["url"]);
    if (request["mode"] != "url" || url == null) {
      final responded = _respond(sessionId: sessionId, requestId: requestId, payload: {"action": "decline"});
      _emit(
        BridgeSseTuiToastShow(
          sessionID: sessionId,
          title: "MCP request unavailable",
          message: "This MCP form or external-action request is not supported by this bridge.",
          variant: "warning",
        ),
      );
      if (!responded) Log.w("[claude] could not decline unsupported elicitation $requestId in $sessionId");
      return;
    }
    final id = "br-${++_sequence}";
    _pending[id] = _PendingExternalAction(
      id: id,
      requestId: requestId,
      sessionId: sessionId,
      title: _nonEmptyString(request["mcp_server_name"]) ?? "MCP authorization",
      message: _nonEmptyString(request["message"]) ?? "Continue in the browser, then respond to this request.",
      authorizationUrl: url,
    );
    _emitActivity(
      event: BridgeSseQuestionAsked(
        interactionKind: PluginQuestionInteractionKind.externalAction,
        id: id,
        sessionID: sessionId,
        displaySessionId: sessionId,
        questions: const [_externalActionNotice],
      ),
    );
  }

  List<PluginPendingExternalAction> pendingExternalActionsForSession({required String sessionId}) => [
    for (final entry in _pending.values)
      if (entry case final _PendingExternalAction action when action.sessionId == sessionId)
        PluginPendingExternalAction(
          id: action.id,
          sessionID: sessionId,
          displaySessionId: sessionId,
          title: action.title,
          message: action.message,
          authorizationUrl: action.authorizationUrl,
          purpose: PluginExternalActionPurpose.authorization,
          choices: const [
            PluginExternalActionChoice.accept,
            PluginExternalActionChoice.decline,
            PluginExternalActionChoice.cancel,
          ],
        ),
  ];

  bool hasExternalAction({required String id}) => _pending[id] is _PendingExternalAction;

  bool hasForm({required String id}) => _pending[id] is _PendingForm;

  List<PluginPendingForm> pendingFormsForSession({required String sessionId}) => [
    for (final entry in _pending.values)
      if (entry case final _PendingForm form when form.sessionId == sessionId)
        PluginPendingForm(
          id: form.id,
          sessionID: sessionId,
          displaySessionId: sessionId,
          title: form.title,
          message: form.message,
          fields: form.schema.fields,
        ),
  ];

  PluginFormSubmissionResult replyForm({
    required String id,
    required String sessionId,
    required Map<String, PluginFormValue> values,
  }) {
    final entry = _pending[id];
    if (entry is! _PendingForm || entry.sessionId != sessionId) return const PluginFormAlreadySettled();
    final errors = entry.schema.validate(values: values);
    if (errors.isNotEmpty) return PluginFormValidationFailed(fieldErrors: errors);
    if (!_respond(
      sessionId: sessionId,
      requestId: entry.requestId,
      payload: {
        "action": "accept",
        "content": entry.schema.encode(values: values),
      },
    )) {
      return const PluginFormUnavailable();
    }
    _pending.remove(id);
    _emitActivity(
      event: BridgeSseQuestionReplied(requestID: id, sessionID: sessionId, displaySessionId: sessionId),
    );
    return const PluginFormAccepted();
  }

  PluginFormDismissalResult declineForm({
    required String id,
    required String sessionId,
    required PluginFormDismissalChoice choice,
  }) {
    final entry = _pending[id];
    if (entry is! _PendingForm || entry.sessionId != sessionId) return PluginFormDismissalResult.alreadySettled;
    if (!_respond(sessionId: sessionId, requestId: entry.requestId, payload: {"action": choice.name})) {
      return PluginFormDismissalResult.unavailable;
    }
    _pending.remove(id);
    _emitActivity(
      event: BridgeSseQuestionRejected(requestID: id, sessionID: sessionId, displaySessionId: sessionId),
    );
    return PluginFormDismissalResult.accepted;
  }

  PluginExternalActionReply replyExternalAction({
    required String id,
    required String sessionId,
    required PluginExternalActionChoice choice,
  }) {
    final entry = _pending[id];
    if (entry is! _PendingExternalAction || entry.sessionId != sessionId) {
      return PluginExternalActionReply.alreadySettled;
    }
    if (!_respond(sessionId: sessionId, requestId: entry.requestId, payload: {"action": choice.name})) {
      return PluginExternalActionReply.unavailable;
    }
    _pending.remove(id);
    _emitActivity(
      event: choice == PluginExternalActionChoice.accept
          ? BridgeSseQuestionReplied(requestID: id, sessionID: sessionId, displaySessionId: sessionId)
          : BridgeSseQuestionRejected(requestID: id, sessionID: sessionId, displaySessionId: sessionId),
    );
    return PluginExternalActionReply.accepted;
  }

  List<PluginPendingPermission> pendingPermissionsForSession({required String sessionId}) => [
    for (final entry in _pending.values)
      if (entry case final _PendingPermission permission when permission.sessionId == sessionId)
        PluginPendingPermission(
          id: permission.id,
          sessionID: sessionId,
          displaySessionId: sessionId,
          tool: permission.tool,
          description: permission.description,
          allowAlways: permission.allowAlways,
        ),
  ];

  List<PluginPendingQuestion> pendingQuestionsForSession({required String sessionId}) => [
    for (final entry in _pending.values)
      if (entry.sessionId == sessionId)
        if (entry case final _PendingQuestion question)
          PluginPendingQuestion(
            interactionKind: PluginQuestionInteractionKind.question,
            id: question.id,
            sessionID: sessionId,
            displaySessionId: sessionId,
            questions: question.questions,
          )
        // COMPATIBILITY 2026-10-15 (v1.9.2): public v1.9.1 reads question snapshots.
        // Remove when all supported production clients consume typed external actions.
        else if (entry is _PendingExternalAction)
          PluginPendingQuestion(
            interactionKind: PluginQuestionInteractionKind.externalAction,
            id: entry.id,
            sessionID: sessionId,
            displaySessionId: sessionId,
            questions: const [_externalActionNotice],
          )
        // COMPATIBILITY 2026-10-15 (v1.9.2): public v1.9.1 reads question snapshots.
        // Remove when all supported production clients consume typed forms.
        else if (entry is _PendingForm)
          PluginPendingQuestion(
            interactionKind: PluginQuestionInteractionKind.form,
            id: entry.id,
            sessionID: sessionId,
            displaySessionId: sessionId,
            questions: const [_formNotice],
          ),
  ];

  List<String> allowedToolsForSession({required String sessionId}) =>
      List.unmodifiable(_allowedTools[sessionId] ?? const <String>{});

  /// The mode [sessionId]'s process runs in when the client asks for
  /// [requested]. After Always on a file edit, the asking default stays
  /// accept-edits, so neither the next turn nor a relaunched process puts it
  /// back; an explicit other mode, such as plan, still applies.
  ClaudePermissionMode? permissionModeFor({required String sessionId, required ClaudePermissionMode? requested}) =>
      requested == ClaudePermissionMode.standard && _acceptEditsSessions.contains(sessionId)
      ? ClaudePermissionMode.acceptEdits
      : requested;

  bool hasPendingInput({required String sessionId}) => _pending.values.any((entry) => entry.sessionId == sessionId);

  bool hasPermission({required String id}) => _pending[id] is _PendingPermission;

  bool hasQuestion({required String id}) => _pending[id] is _PendingQuestion;

  bool isExitPlanModeQuestion({required String id}) => _pending[id] is _ExitPlanMode;

  bool replyPermission({required String id, required PluginPermissionReply reply}) {
    final entry = _pending[id];
    if (entry is! _PendingPermission) return false;
    final payload = switch (reply) {
      PluginPermissionReply.once => <String, Object?>{"behavior": "allow", "updatedInput": entry.input},
      PluginPermissionReply.always => <String, Object?>{
        "behavior": "allow",
        "updatedInput": entry.input,
        if (entry.alwaysGrant case final grant?) "updatedPermissions": grant.updatedPermissions,
      },
      PluginPermissionReply.reject => <String, Object?>{"behavior": "deny", "message": "User denied permission."},
    };
    if (!_respond(sessionId: entry.sessionId, requestId: entry.requestId, payload: payload)) return false;
    if (reply == PluginPermissionReply.always) {
      switch (entry.alwaysGrant) {
        case _SessionRulesGrant(:final rules):
          final allowedTools = _allowedTools.putIfAbsent(entry.sessionId, () => {});
          for (final rule in rules) {
            allowedTools.addAll(_allowedToolRules(rule));
          }
          if (allowedTools.isEmpty) _allowedTools.remove(entry.sessionId);
        case _AcceptEditsGrant():
          _acceptEditsSessions.add(entry.sessionId);
        case null:
          break;
      }
    }
    _pending.remove(id);
    _emitActivity(
      event: BridgeSsePermissionReplied(
        requestID: id,
        sessionID: entry.sessionId,
        displaySessionId: entry.sessionId,
        reply: reply.name,
      ),
    );
    return true;
  }

  bool replyQuestion({required String id, required List<List<String>> answers}) {
    final entry = _pending[id];
    if (entry is! _PendingQuestion) return false;
    if (!_respond(
      sessionId: entry.sessionId,
      requestId: entry.requestId,
      payload: {
        "behavior": "allow",
        "updatedInput": entry.updatedInput(answers: answers),
      },
    )) {
      return false;
    }
    _pending.remove(id);
    _emitActivity(
      event: BridgeSseQuestionReplied(requestID: id, sessionID: entry.sessionId, displaySessionId: entry.sessionId),
    );
    return true;
  }

  bool rejectQuestion({required String id}) {
    final entry = _pending[id];
    if (entry is! _PendingQuestion) return false;
    if (!_deny(entry: entry, message: "User rejected the request.")) return false;
    _pending.remove(id);
    _emitActivity(
      event: BridgeSseQuestionRejected(requestID: id, sessionID: entry.sessionId, displaySessionId: entry.sessionId),
    );
    return true;
  }

  void cancelForSession({required String sessionId}) {
    final entries = _pending.values.where((entry) => entry.sessionId == sessionId).toList(growable: false);
    for (final entry in entries) {
      _pending.remove(entry.id);
      _cancel(entry);
    }
  }

  /// Retires the entry the CLI withdrew with `control_cancel_request`. The CLI
  /// no longer waits for it, so nothing is sent back.
  void withdraw({required String sessionId, required String requestId}) {
    final entries = _pending.values
        .where((entry) => entry.sessionId == sessionId && entry.requestId == requestId)
        .toList(growable: false);
    for (final entry in entries) {
      _pending.remove(entry.id);
      _emitCancellation(entry: entry);
    }
  }

  /// Archive leaves the process alive; only a successful native write settles.
  void cancelForArchive({required String sessionId}) {
    final entries = _pending.values.where((entry) => entry.sessionId == sessionId).toList(growable: false);
    for (final entry in entries) {
      if (!_sendCancellation(entry: entry)) continue;
      _pending.remove(entry.id);
      _emitCancellation(entry: entry);
    }
  }

  void dispose() {
    final entries = _pending.values.toList(growable: false);
    _pending.clear();
    _allowedTools.clear();
    _acceptEditsSessions.clear();
    entries.forEach(_cancel);
  }

  void forgetSession({required String sessionId}) {
    cancelForSession(sessionId: sessionId);
    _allowedTools.remove(sessionId);
    _acceptEditsSessions.remove(sessionId);
  }

  void _cancel(_PendingApproval entry) {
    _sendCancellation(entry: entry);
    _emitCancellation(entry: entry);
  }

  bool _sendCancellation({required _PendingApproval entry}) {
    final responded = switch (entry) {
      _PendingExternalAction() || _PendingForm() => _respond(
        sessionId: entry.sessionId,
        requestId: entry.requestId,
        payload: {"action": "cancel"},
      ),
      _PendingPermission() ||
      _PendingQuestion() => _deny(entry: entry, message: "Request cancelled because this session is no longer active."),
    };
    if (!responded) {
      Log.w("[claude] failed to send cancellation for pending approval ${entry.id}");
    }
    return responded;
  }

  void _emitCancellation({required _PendingApproval entry}) {
    switch (entry) {
      case _PendingPermission():
        _emitActivity(
          event: BridgeSsePermissionReplied(
            requestID: entry.id,
            sessionID: entry.sessionId,
            displaySessionId: entry.sessionId,
            reply: PluginPermissionReply.reject.name,
          ),
        );
      case _PendingQuestion() || _PendingExternalAction() || _PendingForm():
        _emitActivity(
          event: BridgeSseQuestionRejected(
            requestID: entry.id,
            sessionID: entry.sessionId,
            displaySessionId: entry.sessionId,
          ),
        );
    }
  }

  /// Pending approvals feed the awaiting-input flag in the activity summary,
  /// so invalidate that summary after every approval transition.
  void _emitActivity({required BridgeSseEvent event}) {
    _emit(event);
    _emit(const BridgeSseProjectUpdated());
  }

  bool _deny({required _PendingApproval entry, required String message}) => _respond(
    sessionId: entry.sessionId,
    requestId: entry.requestId,
    payload: {"behavior": "deny", "message": message},
  );
}

/// Suggested allow rules win over a mode switch when Claude offers both. A file
/// edit's only suggestion is `setMode` to accept-edits, which Always grants;
/// any other mode, such as `bypassPermissions`, is never offered. Verified live
/// on 2026-11-16 with Claude Code 2.1.325: the edit's `setMode` returned with
/// the `session` destination switched the process to accept-edits (reported on
/// `system/status`), the next edit ran without a request, and no settings file
/// was written.
_AlwaysGrant? _alwaysGrant({required Object? suggestions}) {
  final rules = _sessionRules(suggestions: suggestions);
  if (rules.isNotEmpty) return _SessionRulesGrant(rules: rules);
  final acceptsEdits = _maps(suggestions).any(
    (suggestion) =>
        suggestion["type"] == "setMode" &&
        ClaudePermissionMode.tryParse(_nonEmptyString(suggestion["mode"])) == ClaudePermissionMode.acceptEdits,
  );
  return acceptsEdits ? const _AcceptEditsGrant() : null;
}

/// Claude suggests saving most allow rules to a settings file: Bash and Skill
/// rules go to `localSettings`. Sesori grants only session-scoped approvals, so
/// a rule from any destination is sent back with the `session`
/// destination, which Claude applies to the running process without writing a
/// file. Other suggestion types (`setMode`, `addDirectories`, ...) are not
/// rules; see [_alwaysGrant] for the one mode switch Always sends. Verified live on 2026-11-16 with Claude Code
/// 2.1.325: a `localSettings` Bash rule returned as `session` let the same
/// command run again in that process without a second request, and no settings
/// file was written.
List<Map<String, Object?>> _sessionRules({required Object? suggestions}) => [
  for (final suggestion in _maps(suggestions))
    if (suggestion["type"] == "addRules" && _maps(suggestion["rules"]).isNotEmpty)
      {...suggestion, "destination": "session"},
];

Iterable<String> _allowedToolRules(Map<String, Object?> suggestion) sync* {
  for (final rule in _maps(suggestion["rules"])) {
    final toolName = _nonEmptyString(rule["toolName"]);
    if (toolName == null) continue;
    final content = _nonEmptyString(rule["ruleContent"]);
    yield content == null ? toolName : "$toolName($content)";
  }
}

List<PluginQuestionInfo> _askUserQuestions({required Map<String, Object?> input}) => [
  for (final question in _maps(input["questions"]))
    if (_nonEmptyString(question["question"]) case final text?)
      PluginQuestionInfo(
        question: text,
        header: _nonEmptyString(question["header"]) ?? "Question",
        options: [
          for (final option in _maps(question["options"]))
            if (_nonEmptyString(option["label"]) case final label?)
              PluginQuestionOption(
                label: label,
                description: _nonEmptyString(option["description"]) ?? "",
                isDefault: false,
              ),
        ],
        multiple: question["multiSelect"] == true,
        custom: true,
      ),
];

List<PluginQuestionInfo> _planApprovalQuestions({required Map<String, Object?> input}) => [
  PluginQuestionInfo(
    question: _nonEmptyString(input["plan"]) ?? "Claude Code is ready to implement the plan.",
    header: "Plan approval",
    options: const [
      PluginQuestionOption(label: "Approve", description: "Start implementing this plan.", isDefault: false),
    ],
    multiple: false,
    custom: false,
  ),
];

List<PluginQuestionInfo> _interactionQuestions({required String tool, required Map<String, Object?> request}) => [
  PluginQuestionInfo(
    question: _description(request),
    header: _nonEmptyString(request["display_name"]) ?? tool,
    options: const [],
    multiple: false,
    custom: true,
  ),
];

String _description(Map<String, Object?> request) {
  final values = [request["title"], request["description"], request["decision_reason"]];
  final description =
      values.map(_nonEmptyString).whereType<String>().map((value) => stripAnsi(value: value)).firstOrNull ??
      "Claude Code requested permission.";
  final server = _nonEmptyString(_map(request["mcp_server"])["name"]);
  return server == null ? description : "MCP server ${stripAnsi(value: server)}: $description";
}

String? _nonEmptyString(Object? value) => value is String && value.isNotEmpty ? value : null;

Map<String, Object?> _map(Object? value) => value is Map ? value.cast<String, Object?>() : const {};

List<Map<String, Object?>> _maps(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) item.cast<String, Object?>(),
      ]
    : const [];
