import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/claude_stream_message.dart";

typedef ClaudeApprovalResponder =
    bool Function({
      required String sessionId,
      required String requestId,
      required Map<String, Object?> payload,
    });

sealed class const _PendingApproval({
    required this.id,
    required this.requestId,
    required this.sessionId,
    required this.toolUseId,
  }) {
  final String id;
  final String requestId;
  final String sessionId;
  final String? toolUseId;
}

final class const _PendingPermission({
    required super.id,
    required super.requestId,
    required super.sessionId,
    required super.toolUseId,
    required this.tool,
    required this.description,
    required this.input,
    required this.suggestions,
    required this.allowAlways,
  }) extends _PendingApproval {
  final String tool;
  final String description;
  final Map<String, Object?> input;
  final List<_ClaudePermissionSuggestion> suggestions;
  final bool allowAlways;
}

sealed class const _PendingQuestion({
    required super.id,
    required super.requestId,
    required super.sessionId,
    required super.toolUseId,
    required this.input,
    required this.questions,
  }) extends _PendingApproval {
  final Map<String, Object?> input;
  final List<PluginQuestionInfo> questions;

  Map<String, Object?> updatedInput({required List<List<String>> answers});
}

final class const _AskUserQuestion({
    required super.id,
    required super.requestId,
    required super.sessionId,
    required super.toolUseId,
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
    required super.toolUseId,
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
    required super.toolUseId,
    required super.input,
    required super.questions,
  }) extends _PendingQuestion {
  @override
  Map<String, Object?> updatedInput({required List<List<String>> answers}) => input;
}

sealed class const _ClaudePermissionSuggestion() {
  factory _ClaudePermissionSuggestion.parse(Map<String, Object?> raw) =>
      raw["type"] == "addRules" && raw["destination"] == "session"
      ? _SessionAddRules(raw: raw)
      : const _IneligiblePermissionSuggestion();
}

final class const _SessionAddRules({required this.raw}) extends _ClaudePermissionSuggestion {
  final Map<String, Object?> raw;
}

final class const _IneligiblePermissionSuggestion() extends _ClaudePermissionSuggestion;

/// Owns pending Claude permission and interaction requests until the phone
/// answers them or their session is torn down.
final class ClaudeApprovalRegistry({
    required void Function(BridgeSseEvent event) emit,
    required ClaudeApprovalResponder respond,
  }) {
  this : _emit = emit,
       _respond = respond;

  final void Function(BridgeSseEvent event) _emit;
  final ClaudeApprovalResponder _respond;
  final Map<String, _PendingApproval> _pending = {};
  final Map<String, Set<String>> _allowedTools = {};
  final Map<String, Set<String>> _handledDenialToolIds = {};
  int _sequence = 0;

  bool handle({required String sessionId, required ClaudeControlRequestMessage message}) {
    final attributedSessionId = _nonEmptyString(sessionId);
    final requestId = _nonEmptyString(message.requestId);
    if (message.subtype != "can_use_tool" || attributedSessionId == null || requestId == null) return false;

    final request = message.request;
    final tool = _nonEmptyString(request["tool_name"]) ?? "tool";
    final toolUseId = _nonEmptyString(request["tool_use_id"]);
    final input = _map(request["input"]);
    final id = "br-${++_sequence}";
    if (request["requires_user_interaction"] == true) {
      final questions = _questions(tool: tool, input: input, request: request);
      final pending = switch (tool) {
        "AskUserQuestion" => _AskUserQuestion(
          id: id,
          requestId: requestId,
          sessionId: attributedSessionId,
          toolUseId: toolUseId,
          input: input,
          questions: questions,
        ),
        "ExitPlanMode" => _ExitPlanMode(
          id: id,
          requestId: requestId,
          sessionId: attributedSessionId,
          toolUseId: toolUseId,
          input: input,
          questions: questions,
        ),
        _ => _UnknownInteraction(
          id: id,
          requestId: requestId,
          sessionId: attributedSessionId,
          toolUseId: toolUseId,
          input: input,
          questions: questions,
        ),
      };
      _pending[id] = pending;
      _emit(
        BridgeSseQuestionAsked(
          id: id,
          sessionID: attributedSessionId,
          displaySessionId: attributedSessionId,
          questions: questions,
        ),
      );
      return true;
    }

    final pending = _PendingPermission(
      id: id,
      requestId: requestId,
      sessionId: attributedSessionId,
      toolUseId: toolUseId,
      tool: tool,
      description: _description(request),
      input: input,
      suggestions: _maps(request["permission_suggestions"]).map(_ClaudePermissionSuggestion.parse).toList(),
      allowAlways: request["suppress_always_allow_rule"] != true,
    );
    _pending[id] = pending;
    _emit(
      BridgeSsePermissionAsked(
        requestID: id,
        sessionID: attributedSessionId,
        displaySessionId: attributedSessionId,
        tool: pending.tool,
        description: pending.description,
        allowAlways: pending.allowAlways,
      ),
    );
    return true;
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
      if (entry case final _PendingQuestion question when question.sessionId == sessionId)
        PluginPendingQuestion(
          id: question.id,
          sessionID: sessionId,
          displaySessionId: sessionId,
          questions: question.questions,
        ),
  ];

  List<String> allowedToolsForSession({required String sessionId}) =>
      List.unmodifiable(_allowedTools[sessionId] ?? const <String>{});

  bool consumeHandledPermissionDenials({
    required String sessionId,
    required List<Map<String, Object?>> denials,
  }) {
    if (denials.isEmpty) return false;
    final handled = _handledDenialToolIds[sessionId];
    if (handled == null) return false;
    final toolUseIds = denials.map((denial) => _nonEmptyString(denial["tool_use_id"])).toList(growable: false);
    final allHandled = toolUseIds.every((toolUseId) => toolUseId != null && handled.contains(toolUseId));
    handled.removeAll(toolUseIds.whereType<String>());
    if (handled.isEmpty) _handledDenialToolIds.remove(sessionId);
    return allHandled;
  }

  bool hasPendingInput({required String sessionId}) => _pending.values.any((entry) => entry.sessionId == sessionId);

  bool hasPermission({required String id}) => _pending[id] is _PendingPermission;

  bool hasQuestion({required String id}) => _pending[id] is _PendingQuestion;

  bool isExitPlanModeQuestion({required String id}) => _pending[id] is _ExitPlanMode;

  bool replyPermission({required String id, required PluginPermissionReply reply}) {
    final entry = _pending[id];
    if (entry is! _PendingPermission) return false;
    final suggestions = entry.allowAlways
        ? [
            for (final suggestion in entry.suggestions)
              if (suggestion case _SessionAddRules(:final raw)) raw,
          ]
        : const <Map<String, Object?>>[];
    final payload = switch (reply) {
      PluginPermissionReply.once => <String, Object?>{"behavior": "allow", "updatedInput": entry.input},
      PluginPermissionReply.always => <String, Object?>{
        "behavior": "allow",
        "updatedInput": entry.input,
        if (suggestions.isNotEmpty) "updatedPermissions": suggestions,
      },
      PluginPermissionReply.reject => <String, Object?>{"behavior": "deny", "message": "User denied permission."},
    };
    if (!_respond(sessionId: entry.sessionId, requestId: entry.requestId, payload: payload)) return false;
    if (reply == PluginPermissionReply.reject) _recordHandledDenial(entry);
    if (reply == PluginPermissionReply.always && entry.allowAlways) {
      final allowedTools = _allowedTools.putIfAbsent(entry.sessionId, () => {});
      for (final suggestion in entry.suggestions) {
        if (suggestion case _SessionAddRules(:final raw)) {
          allowedTools.addAll(_allowedToolRules(raw));
        }
      }
      if (allowedTools.isEmpty) _allowedTools.remove(entry.sessionId);
    }
    _pending.remove(id);
    _emit(
      BridgeSsePermissionReplied(
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
    _emit(BridgeSseQuestionReplied(requestID: id, sessionID: entry.sessionId, displaySessionId: entry.sessionId));
    return true;
  }

  bool rejectQuestion({required String id}) {
    final entry = _pending[id];
    if (entry is! _PendingQuestion) return false;
    if (!_deny(entry: entry, message: "User rejected the request.")) return false;
    _pending.remove(id);
    _emit(BridgeSseQuestionRejected(requestID: id, sessionID: entry.sessionId, displaySessionId: entry.sessionId));
    return true;
  }

  void cancelForSession({required String sessionId}) {
    final entries = _pending.values.where((entry) => entry.sessionId == sessionId).toList(growable: false);
    for (final entry in entries) {
      _pending.remove(entry.id);
      _cancel(entry);
    }
  }

  void dispose() {
    final entries = _pending.values.toList(growable: false);
    _pending.clear();
    _allowedTools.clear();
    entries.forEach(_cancel);
    _handledDenialToolIds.clear();
  }

  void forgetSession({required String sessionId}) {
    cancelForSession(sessionId: sessionId);
    _allowedTools.remove(sessionId);
    _handledDenialToolIds.remove(sessionId);
  }

  void _cancel(_PendingApproval entry) {
    if (!_deny(entry: entry, message: "Request cancelled because the Claude session stopped.")) {
      Log.w("[claude] failed to send cancellation for pending approval ${entry.id}");
    }
    switch (entry) {
      case _PendingPermission():
        _emit(
          BridgeSsePermissionReplied(
            requestID: entry.id,
            sessionID: entry.sessionId,
            displaySessionId: entry.sessionId,
            reply: PluginPermissionReply.reject.name,
          ),
        );
      case _PendingQuestion():
        _emit(
          BridgeSseQuestionRejected(
            requestID: entry.id,
            sessionID: entry.sessionId,
            displaySessionId: entry.sessionId,
          ),
        );
    }
  }

  bool _deny({required _PendingApproval entry, required String message}) {
    final responded = _respond(
      sessionId: entry.sessionId,
      requestId: entry.requestId,
      payload: {"behavior": "deny", "message": message},
    );
    if (responded) _recordHandledDenial(entry);
    return responded;
  }

  void _recordHandledDenial(_PendingApproval entry) {
    final toolUseId = entry.toolUseId;
    if (toolUseId != null) (_handledDenialToolIds[entry.sessionId] ??= {}).add(toolUseId);
  }
}

Iterable<String> _allowedToolRules(Map<String, Object?> suggestion) sync* {
  for (final rule in _maps(suggestion["rules"])) {
    final toolName = _nonEmptyString(rule["toolName"]);
    if (toolName == null) continue;
    final content = _nonEmptyString(rule["ruleContent"]);
    yield content == null ? toolName : "$toolName($content)";
  }
}

List<PluginQuestionInfo> _questions({
  required String tool,
  required Map<String, Object?> input,
  required Map<String, Object?> request,
}) {
  if (tool == "AskUserQuestion") {
    return [
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
                  ),
            ],
            multiple: question["multiSelect"] == true,
            custom: true,
          ),
    ];
  }
  if (tool == "ExitPlanMode") {
    return [
      PluginQuestionInfo(
        question: _nonEmptyString(input["plan"]) ?? "Claude Code is ready to implement the plan.",
        header: "Plan approval",
        options: const [PluginQuestionOption(label: "Approve", description: "Start implementing this plan.")],
        multiple: false,
        custom: false,
      ),
    ];
  }
  return [
    PluginQuestionInfo(
      question: _description(request),
      header: _nonEmptyString(request["display_name"]) ?? tool,
      options: const [],
      multiple: false,
      custom: true,
    ),
  ];
}

String _description(Map<String, Object?> request) {
  final values = [request["title"], request["description"], request["decision_reason"]];
  return values.map(_nonEmptyString).whereType<String>().map(_stripAnsi).firstOrNull ??
      "Claude Code requested permission.";
}

String _stripAnsi(String value) =>
    value.replaceAll(RegExp(r"\x1B(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\))"), "");

String? _nonEmptyString(Object? value) => value is String && value.isNotEmpty ? value : null;

Map<String, Object?> _map(Object? value) => value is Map ? value.cast<String, Object?>() : const {};

List<Map<String, Object?>> _maps(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) item.cast<String, Object?>(),
      ]
    : const [];
