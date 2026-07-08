import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Adds Cursor's question extensions on top of the standard ACP permission
/// handling: `cursor/ask_question` (multiple-choice) and `cursor/create_plan`
/// (accept/reject), both blocking requests that the bridge surfaces as
/// questions.
///
/// NOTE: Cursor's exact reply payload shapes are not formally documented; the
/// builders below are best-effort and should be confirmed against a real
/// `cursor-agent acp` trace during end-to-end verification.
class CursorApprovalRegistry extends AcpApprovalRegistry {
  CursorApprovalRegistry({
    required AcpStdioClient client,
    required super.emit,
    super.idGenerator,
    super.activeSessionResolver,
  }) : super(
         respond: (id, result) =>
             client.respondToServerRequest(id: id, result: result),
         respondError: (id, code, message) => client
             .respondToServerRequestWithError(id: id, code: code, message: message),
       );

  @override
  bool handleExtensionRequest(AcpServerRequest request) {
    switch (request.method) {
      case "cursor/ask_question":
        _handleAskQuestion(request);
        return true;
      case "cursor/create_plan":
        _handleCreatePlan(request);
        return true;
    }
    return false;
  }

  void _handleAskQuestion(AcpServerRequest request) {
    final params = request.params;
    // Cursor's question requests may omit `sessionId`; fall back to the active
    // turn's session so the request still surfaces in the conversation.
    final sessionId = resolveSessionId(params);
    if (sessionId.isEmpty) {
      // A question stamped with "" is dropped by the mobile client, so it would
      // register an invisible pending question that blocks the turn forever.
      // Reject so the agent can proceed instead of hanging.
      Log.w("[cursor] cursor/ask_question with no resolvable session; rejecting");
      respondError(request.id, -32602, "cursor/ask_question: no resolvable session");
      return;
    }
    final title = _str(params["title"]) ?? "Question";
    final rawQ = params["questions"];
    final rawQuestions = rawQ is List ? rawQ : const <Object?>[];

    final pluginQuestions = <PluginQuestionInfo>[];
    final metas = <_QuestionMeta>[];

    for (final raw in rawQuestions.whereType<Map<dynamic, dynamic>>()) {
      final q = raw.cast<String, dynamic>();
      // Parse defensively: Cursor's payload shapes are not formally documented,
      // so a field arriving with an unexpected type (e.g. allowMultiple as a
      // string) must not crash the whole request handler.
      final prompt = _str(q["prompt"]) ?? _str(q["question"]);
      if (prompt == null || prompt.isEmpty) continue; // skip a question with no text
      final multiple = q["allowMultiple"] == true;
      final rawOptions = q["options"];
      final options = (rawOptions is List ? rawOptions : const <Object?>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((o) => o.cast<String, dynamic>())
          .toList(growable: false);

      final labelToId = <String, String>{};
      final pluginOptions = <PluginQuestionOption>[];
      for (final option in options) {
        final id = _str(option["id"]) ?? _str(option["value"]) ?? "";
        var label = _str(option["label"]) ?? id;
        // The bridge round-trips the *label* the user picked, so duplicate
        // labels would collapse to one id and reply with the wrong option.
        // Disambiguate so each displayed label maps to exactly one id.
        if (labelToId.containsKey(label)) {
          var n = 2;
          while (labelToId.containsKey("$label ($n)")) {
            n++;
          }
          label = "$label ($n)";
        }
        labelToId[label] = id;
        pluginOptions.add(PluginQuestionOption(label: label, description: ""));
      }

      pluginQuestions.add(
        PluginQuestionInfo(
          question: prompt,
          header: title,
          options: pluginOptions,
          multiple: multiple,
          custom: false,
        ),
      );
      metas.add(_QuestionMeta(id: _str(q["id"]), labelToId: labelToId));
    }

    // A malformed/empty question list must not register a pending question: it
    // would block the session awaiting input that can never be answered. Reject
    // the request so the agent can proceed instead of hanging.
    if (pluginQuestions.isEmpty) {
      Log.w("[cursor] cursor/ask_question had no valid questions; rejecting");
      respondError(request.id, -32602, "cursor/ask_question: no valid questions");
      return;
    }

    final bridgeId = generateBridgeId();
    addPendingQuestion(
      bridgeRequestId: bridgeId,
      acpId: request.id,
      sessionId: sessionId,
      questions: pluginQuestions,
      replyBuilder: (answers) => _buildAskReply(metas, answers),
    );
    emit(
      BridgeSseQuestionAsked(
        id: bridgeId,
        sessionID: sessionId,
        // Cursor sessions are flat (no sub-agent hierarchy), so a request's
        // display root is its own session.
        displaySessionId: sessionId,
        questions: pluginQuestions,
      ),
    );
  }

  /// A field as a non-empty String, or null if absent/another type. Cursor's
  /// reply shapes are not formally documented, so casts here are fail-soft.
  static String? _str(Object? value) => value is String ? value : null;

  Object _buildAskReply(List<_QuestionMeta> metas, List<List<String>> answers) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < metas.length; i++) {
      final selectedLabels = i < answers.length ? answers[i] : const <String>[];
      final ids = selectedLabels
          .map((label) => metas[i].labelToId[label] ?? label)
          .toList(growable: false);
      out.add({"id": metas[i].id, "selectedOptionIds": ids});
    }
    return {"questions": out};
  }

  void _handleCreatePlan(AcpServerRequest request) {
    final params = request.params;
    // `cursor/create_plan` carries no `sessionId` (only a `toolCallId`), so
    // resolve it from the active turn — otherwise the plan-approval question is
    // stamped with an empty session and dropped by the mobile client.
    final sessionId = resolveSessionId(params);
    if (sessionId.isEmpty) {
      // No active turn to attribute the plan to: a "" session is dropped by the
      // mobile client, so the plan-approval question would block forever. Reject
      // so the agent proceeds instead of hanging.
      Log.w("[cursor] cursor/create_plan with no resolvable session; rejecting");
      respondError(request.id, -32602, "cursor/create_plan: no resolvable session");
      return;
    }
    final name = _str(params["name"]) ?? "Plan";
    final overview = _str(params["overview"]) ??
        _str(params["plan"]) ??
        "Review the proposed plan.";

    final questions = [
      PluginQuestionInfo(
        question: overview,
        header: name,
        options: const [
          PluginQuestionOption(label: "Accept", description: ""),
          PluginQuestionOption(label: "Reject", description: ""),
        ],
        multiple: false,
        custom: false,
      ),
    ];

    final bridgeId = generateBridgeId();
    addPendingQuestion(
      bridgeRequestId: bridgeId,
      acpId: request.id,
      sessionId: sessionId,
      questions: questions,
      replyBuilder: (answers) {
        final accepted = answers.isNotEmpty &&
            answers.first.any((a) => a.toLowerCase() == "accept");
        return {"accepted": accepted};
      },
    );
    emit(
      BridgeSseQuestionAsked(
        id: bridgeId,
        sessionID: sessionId,
        displaySessionId: sessionId,
        questions: questions,
      ),
    );
  }
}

class _QuestionMeta {
  _QuestionMeta({required this.id, required this.labelToId});

  final String? id;
  final Map<String, String> labelToId;
}
