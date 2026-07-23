import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

class SessionPromptDefaultsChange {
  final String sessionId;
  final SessionPromptDefaults promptDefaults;

  const SessionPromptDefaultsChange({
    required this.sessionId,
    required this.promptDefaults,
  });
}

class SessionPromptService {
  final SessionRepository _sessionRepository;
  final StreamController<SessionPromptDefaultsChange> _promptDefaultsChangesController =
      StreamController<SessionPromptDefaultsChange>.broadcast(sync: true);

  SessionPromptService({
    required SessionRepository sessionRepository,
  }) : _sessionRepository = sessionRepository;

  Stream<SessionPromptDefaultsChange> get promptDefaultsChanges => _promptDefaultsChangesController.stream;

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
    final arguments = textPart?.text;
    // Per the BridgePluginApi contract, sendCommand completes once the
    // backend has accepted the command — not when its run finishes — so
    // awaiting it here never holds the phone's relay request open for the
    // duration of the command's agent run.
    await _sessionRepository.sendCommand(
      sessionId: sessionId,
      command: normalizedCommand,
      arguments: arguments ?? '',
      userVisibleArguments: arguments == null || arguments.trim().isEmpty ? null : arguments,
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
      _promptDefaultsChangesController.add(
        SessionPromptDefaultsChange(
          sessionId: sessionId,
          promptDefaults: SessionPromptDefaults(
            agent: agent,
            model: agentModel,
          ),
        ),
      );
    } catch (error, stackTrace) {
      Log.w("Failed to update prompt defaults for session $sessionId", error, stackTrace);
    }
  }

  Future<void> dispose() async {
    await _promptDefaultsChangesController.close();
  }
}
