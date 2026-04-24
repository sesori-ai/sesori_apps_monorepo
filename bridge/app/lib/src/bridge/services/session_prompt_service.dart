import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

class SessionPromptService {
  final SessionRepository _sessionRepository;

  SessionPromptService({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Future<void> sendPrompt({
    required String sessionId,
    required List<PromptPart> parts,
    required String? variant,
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
  }
}
