import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

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
    final sessionId = (params["sessionId"] as String?) ?? "";
    final title = (params["title"] as String?) ?? "Question";
    final rawQuestions = (params["questions"] as List?) ?? const [];

    final sharedQuestions = <Map<String, dynamic>>[];
    final pluginQuestions = <PluginQuestionInfo>[];
    final metas = <_QuestionMeta>[];

    for (final raw in rawQuestions.whereType<Map<dynamic, dynamic>>()) {
      final q = raw.cast<String, dynamic>();
      final prompt = (q["prompt"] ?? q["question"] ?? "") as String;
      final multiple = (q["allowMultiple"] ?? false) as bool;
      final options = ((q["options"] as List?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((o) => o.cast<String, dynamic>())
          .toList(growable: false);

      final labelToId = <String, String>{};
      final sharedOptions = <shared.QuestionOption>[];
      final pluginOptions = <PluginQuestionOption>[];
      for (final option in options) {
        final id = (option["id"] ?? option["value"] ?? "") as String;
        final label = (option["label"] ?? id) as String;
        labelToId[label] = id;
        sharedOptions.add(shared.QuestionOption(label: label, description: ""));
        pluginOptions.add(PluginQuestionOption(label: label, description: ""));
      }

      sharedQuestions.add(
        shared.QuestionInfo(
          question: prompt,
          header: title,
          options: sharedOptions,
          multiple: multiple,
          custom: false,
        ).toJson(),
      );
      pluginQuestions.add(
        PluginQuestionInfo(
          question: prompt,
          header: title,
          options: pluginOptions,
          multiple: multiple,
          custom: false,
        ),
      );
      metas.add(_QuestionMeta(id: q["id"] as String?, labelToId: labelToId));
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
        questions: sharedQuestions,
      ),
    );
  }

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
    final sessionId = (params["sessionId"] as String?) ?? "";
    final name = (params["name"] as String?) ?? "Plan";
    final overview = (params["overview"] as String?) ??
        (params["plan"] as String?) ??
        "Review the proposed plan.";

    final bridgeId = generateBridgeId();
    addPendingQuestion(
      bridgeRequestId: bridgeId,
      acpId: request.id,
      sessionId: sessionId,
      questions: [
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
      ],
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
        questions: [
          shared.QuestionInfo(
            question: overview,
            header: name,
            options: const [
              shared.QuestionOption(label: "Accept", description: ""),
              shared.QuestionOption(label: "Reject", description: ""),
            ],
            multiple: false,
            custom: false,
          ).toJson(),
        ],
      ),
    );
  }
}

class _QuestionMeta {
  _QuestionMeta({required this.id, required this.labelToId});

  final String? id;
  final Map<String, String> labelToId;
}
