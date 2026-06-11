import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../sse/sse_manager.dart";

class SessionPromptService {
  final SessionRepository _sessionRepository;
  final SSEManager _sseManager;
  final Duration _commandDispatchFastFailWindow;

  SessionPromptService({
    required SessionRepository sessionRepository,
    required SSEManager sseManager,
    Duration commandDispatchFastFailWindow = const Duration(seconds: 3),
  })  : _sessionRepository = sessionRepository,
        _sseManager = sseManager,
        _commandDispatchFastFailWindow = commandDispatchFastFailWindow;

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
    final sendFuture = _sessionRepository.sendCommand(
      sessionId: sessionId,
      command: normalizedCommand,
      arguments: textPart?.text ?? '',
      variant: variant,
      agent: agent,
      model: model,
    );
    try {
      await sendFuture.timeout(_commandDispatchFastFailWindow);
    } on TimeoutException {
      // OpenCode's /command endpoint is synchronous — it responds only after
      // the full agent run completes, and no async variant exists upstream.
      // Surviving the fast-fail window means OpenCode accepted the command and
      // the run is in progress (progress streams over SSE). Detach instead of
      // holding the phone's relay request open until its client-side timeout
      // misreports an in-flight command as a failed send.
      unawaited(
        sendFuture.catchError((Object e, StackTrace s) {
          Log.w(
            "command '$normalizedCommand' for session $sessionId "
            "failed after dispatch: $e",
            e,
            s,
          );
        }),
      );
    }
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
    _sseManager.enqueueEvent(
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
