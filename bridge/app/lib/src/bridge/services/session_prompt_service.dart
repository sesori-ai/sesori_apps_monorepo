import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

class SessionPromptService {
  final SessionRepository _sessionRepository;

  SessionPromptService({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Future<void> sendPrompt({
    required String sessionId,
    required List<PromptPart> parts,
    required String? agent,
    required PromptModel? model,
    required String? command,
  }) async {
    if (command == null) {
      await _sessionRepository.sendPrompt(
        sessionId: sessionId,
        parts: parts,
        agent: agent,
        model: model,
      );
      return;
    }

    final textPart = parts.whereType<PromptPartText>().firstOrNull;
    await _sessionRepository.sendCommand(
      sessionId: sessionId,
      command: command,
      arguments: textPart?.text ?? '',
    );
  }
}
