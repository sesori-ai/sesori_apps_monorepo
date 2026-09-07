import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_identity.dart";
import "../models/antigravity_interaction.dart";
import "../repositories/antigravity_interaction_repository.dart";
import "../repositories/mappers/antigravity_protocol_mapper.dart";
import "../repositories/mappers/models/antigravity_permission_dto.dart";

class AntigravityInteractionService({
  required final AntigravityProtocolMapper _protocolMapper,
  required final AntigravityInteractionRepository _repository,
}) {
  void rejectAmbiguousServerRequest({required AcpServerRequest request}) {
    Log.w("[antigravity] ambiguous tool-call attribution for request ${request.id.toString()}; refusing");
    _repository.rejectAmbiguous(requestId: request.id);
  }

  AntigravityInteraction? classify({required AcpServerRequest request}) {
    final AntigravityPermissionRequestDto? input;
    try {
      input = _protocolMapper.mapPermissionRequest(request: request);
    } on Object catch (error, stackTrace) {
      _rejectMalformed(requestId: request.id, error: error, stackTrace: stackTrace);
      return null;
    }
    if (input == null) {
      _repository.unsupported(requestId: request.id);
      return null;
    }
    try {
      return _classify(requestId: request.id, input: input);
    } on FormatException catch (error, stackTrace) {
      _rejectMalformed(requestId: request.id, error: error, stackTrace: stackTrace);
      return null;
    }
  }

  // ignore: no_slop_linter/prefer_specific_type, ACP request IDs are opaque string or integer values
  AntigravityInteraction _classify({required Object requestId, required AntigravityPermissionRequestDto input}) {
    _validateText(value: input.sessionId, limit: 256);
    _validateText(value: input.toolCall.toolCallId, limit: 256);
    _validateText(value: input.toolCall.title, limit: 4096);
    final ids = <String>{};
    for (final option in input.options) {
      _validateText(value: option.optionId, limit: 256);
      _validateText(value: option.name, limit: 512);
      if (!ids.add(option.optionId)) throw const FormatException("Duplicate permission option IDs");
    }
    final safe = input.options
        .where(
          (option) =>
              option.metadata?.hasWarning != true &&
              (option.kind == AntigravityPermissionKind.allowOnce ||
                  option.kind == AntigravityPermissionKind.rejectOnce),
        )
        .toList(growable: false);
    if (input.toolCall.toolCallId.startsWith("interaction_")) {
      final labels = <String, String>{};
      for (final option in safe) {
        if (labels.containsKey(option.name)) throw const FormatException("Ambiguous question labels");
        labels[option.name] = option.optionId;
      }
      if (labels.length < 2) throw const FormatException("Question has fewer than two safe choices");
      return AntigravityQuestion(
        requestId: requestId,
        sessionId: input.sessionId,
        question: PluginQuestionInfo(
          question: input.toolCall.title,
          header: AntigravityIdentity.displayName,
          options: [for (final label in labels.keys) PluginQuestionOption(label: label, description: "")],
          multiple: false,
          custom: false,
        ),
        optionIdsByLabel: labels,
      );
    }
    final allows = safe.where((option) => option.kind == AntigravityPermissionKind.allowOnce).toList();
    final rejects = safe.where((option) => option.kind == AntigravityPermissionKind.rejectOnce).toList();
    if (allows.length != 1 || rejects.length > 1) throw const FormatException("No unambiguous once-only permission");
    return AntigravityPermission(
      requestId: requestId,
      sessionId: input.sessionId,
      tool: switch (input.toolCall.kind) {
        null || AntigravityPermissionToolKind.unknown => "tool",
        final kind => kind.name,
      },
      description: input.toolCall.title,
      allowOptionId: allows.single.optionId,
      rejectOptionId: rejects.singleOrNull?.optionId,
    );
  }

  void replyPermission({required AntigravityInteraction payload, required PluginPermissionReply reply}) {
    // ignore: no_slop_linter/avoid_as_cast, the pending registry dispatches only the registered permission variant here
    final AntigravityPermission(:requestId, :allowOptionId, :rejectOptionId) = payload as AntigravityPermission;
    final selected = switch (reply) {
      PluginPermissionReply.once => allowOptionId,
      PluginPermissionReply.reject => rejectOptionId,
      PluginPermissionReply.always => null,
    };
    if (selected == null) {
      _repository.cancel(requestId: requestId);
    } else {
      _repository.select(requestId: requestId, optionId: selected);
    }
  }

  PendingQuestionReplyOutcome replyQuestion({
    required AntigravityInteraction payload,
    required List<List<String>> answers,
  }) {
    // ignore: no_slop_linter/avoid_as_cast, the pending registry dispatches only the registered question variant here
    final AntigravityQuestion(:requestId, :optionIdsByLabel) = payload as AntigravityQuestion;
    final label = answers.length == 1 && answers.single.length == 1 ? answers.single.single : null;
    final optionId = optionIdsByLabel[label];
    if (optionId == null) {
      Log.w("[antigravity] invalid single-choice answer; cancelling question");
      _repository.cancel(requestId: requestId);
      return PendingQuestionReplyOutcome.rejected;
    }
    _repository.select(requestId: requestId, optionId: optionId);
    return PendingQuestionReplyOutcome.replied;
  }

  void rejectQuestion({required AntigravityInteraction payload}) => _repository.cancel(requestId: payload.requestId);

  void cancel({required AntigravityInteraction payload, required PendingCancellationReason reason}) =>
      _repository.cancel(requestId: payload.requestId);

  // ignore: no_slop_linter/prefer_specific_type, retain opaque ACP request identity and original decoding failure
  void _rejectMalformed({required Object requestId, required Object error, required StackTrace stackTrace}) {
    Log.w(
      "[antigravity] refusing malformed or unsupported permission choices for request ${requestId.toString()}",
      error is AntigravityInteractionException
          ? error
          : AntigravityInteractionException(
              message: error is FormatException ? error.message : "Request cannot be presented safely",
              cause: error,
            ),
      stackTrace,
    );
    _repository.cancel(requestId: requestId);
  }

  void _validateText({required String value, required int limit}) {
    if (value.trim().isEmpty || value.length > limit) {
      throw const FormatException("Empty or oversized permission field");
    }
  }
}
