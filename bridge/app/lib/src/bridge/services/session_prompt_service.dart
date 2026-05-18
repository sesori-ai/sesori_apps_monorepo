import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../sse/sse_manager.dart";

class SessionPromptService {
  final SessionRepository _sessionRepository;
  final SSEManager? _sseManager;

  SessionPromptService({
    required SessionRepository sessionRepository,
    SSEManager? sseManager,
  })  : _sessionRepository = sessionRepository,
        _sseManager = sseManager;

  Future<void> sendPrompt({
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
    required String? command,
  }) async {
    final normalizedCommand = command?.trim();
    if (normalizedCommand == null || normalizedCommand.isEmpty) {
      await _sessionRepository.sendPrompt(
        sessionId: sessionId,
        parts: parts,
        variant: variant,
        agent: agent,
        model: model,
      );
      await _updatePromptDefaults(
        sessionId: sessionId,
        variant: variant,
        agent: agent,
        model: model,
      );
      return;
    }

    final textPart = parts.whereType<PromptPartText>().firstOrNull;
    await _sessionRepository.sendCommand(
      sessionId: sessionId,
      command: normalizedCommand,
      arguments: textPart?.text ?? '',
      variant: variant,
      agent: agent,
      model: model,
    );
    await _updatePromptDefaults(
      sessionId: sessionId,
      variant: variant,
      agent: agent,
      model: model,
    );
  }

  Future<void> _updatePromptDefaults({
    required String sessionId,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    final agentModel = model != null
        ? AgentModel(
            providerID: model.providerID,
            modelID: model.modelID,
            variant: variant?.id,
          )
        : null;
    try {
      await _sessionRepository.updatePromptDefaults(
        sessionId: sessionId,
        agent: agent,
        agentModel: agentModel,
      );
      _emitPromptDefaultsChanged(
        sessionId: sessionId,
        agent: agent,
        agentModel: agentModel,
      );
    } catch (e) {
      Log.w("Failed to update prompt defaults for session $sessionId: $e");
    }
  }

  void _emitPromptDefaultsChanged({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) {
    final sseManager = _sseManager;
    if (sseManager == null) return;

    sseManager.enqueueEvent(
      SesoriSseEvent.sessionPromptDefaultsChanged(
        sessionID: sessionId,
        promptDefaults: SessionPromptDefaults(
          agent: agent,
          model: agentModel,
        ),
      ),
    );
  }
}
