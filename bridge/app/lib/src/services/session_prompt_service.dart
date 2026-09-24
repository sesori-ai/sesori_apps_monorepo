import "dart:async";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginStaleOptionsException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/accepted_prompts_repository.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/random_hex_id.dart";
import "../repositories/session_repository.dart";
import "archived_session_validator.dart";
import "session_operation_dispatcher.dart";
import "session_options_service.dart";
import "stale_session_prompt_options_exception.dart";

class const SessionPromptDefaultsChange({
  required final String sessionId,
  required final SessionPromptDefaults promptDefaults,
});

class SessionPromptService({
  required final SessionRepository _sessionRepository,
  required final AcceptedPromptsRepository _acceptedPromptsRepository,
  required final SessionOperationDispatcher _dispatcher,
  required final ArchivedSessionValidator _archivedSessionValidator,
  required final SessionOptionsService _sessionOptionsService,
}) {
  final StreamController<SessionPromptDefaultsChange> _promptDefaultsChangesController =
      StreamController<SessionPromptDefaultsChange>.broadcast(sync: true);

  Stream<SessionPromptDefaultsChange> get promptDefaultsChanges => _promptDefaultsChangesController.stream;

  Future<void> sendPrompt({
    required String sessionId,
    required String? promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required String? command,
  }) {
    final normalizedCommand = command?.trim();
    return _dispatcher.dispatch(
      sessionId: sessionId,
      operation: normalizedCommand == null || normalizedCommand.isEmpty
          ? SessionOperation.sendPrompt
          : SessionOperation.sendCommand,
      body: () => _sendPrompt(
        sessionId: sessionId,
        // Clients that predate prompt ids omit them; plugins always receive
        // one so queue entries and dedupe stay uniformly keyed.
        promptId: promptId ?? generatePromptId(),
        parts: parts,
        variant: variant,
        fastMode: fastMode,
        agent: agent,
        model: model,
        normalizedCommand: normalizedCommand,
      ),
    );
  }

  Future<void> _sendPrompt({
    required String sessionId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required String? normalizedCommand,
  }) async {
    // Inside the dispatched body, so this cannot race a concurrent archive on
    // the same family lane.
    await _archivedSessionValidator.requireNotArchived(sessionId: sessionId);
    // A client retries a send whose response was lost with the same id,
    // possibly hours later, when the plugin's own dedup may be gone (idle
    // reap, bridge restart). The lane keeps this check and the record below
    // atomic, and the repeat succeeds as the first send did.
    if (await _acceptedPromptsRepository.isAccepted(sessionId: sessionId, promptId: promptId)) {
      Log.i("Ignoring repeated prompt $promptId for session $sessionId: it was already accepted");
      return;
    }
    if (normalizedCommand == null || normalizedCommand.isEmpty) {
      await _sendInvalidatingStaleOptionsCache(
        sessionId: sessionId,
        send: () => _sessionRepository.sendPrompt(
          sessionId: sessionId,
          promptId: promptId,
          parts: parts,
          variant: variant,
          fastMode: fastMode,
          agent: agent,
          model: model,
        ),
      );
    } else {
      final textPart = parts.whereType<PromptPartText>().firstOrNull;
      final arguments = textPart?.text;
      // Per the BridgePluginApi contract, sendCommand completes once the
      // backend has accepted the command — not when its run finishes — so
      // awaiting it here never holds the phone's relay request open for the
      // duration of the command's agent run.
      await _sendInvalidatingStaleOptionsCache(
        sessionId: sessionId,
        send: () => _sessionRepository.sendCommand(
          sessionId: sessionId,
          promptId: promptId,
          command: normalizedCommand,
          arguments: arguments ?? '',
          userVisibleArguments: arguments == null || arguments.trim().isEmpty ? null : arguments,
          variant: variant,
          fastMode: fastMode,
          agent: agent,
          model: model,
        ),
      );
    }
    try {
      await _acceptedPromptsRepository.recordAccepted(sessionId: sessionId, promptId: promptId);
    } catch (error, stackTrace) {
      // The plugin already owns the prompt; failing the send would only make
      // the client retry it.
      Log.w("Failed to record accepted prompt $promptId for session $sessionId", error, stackTrace);
    }
    await _updatePromptDefaults(
      sessionId: sessionId,
      variant: variant,
      fastMode: fastMode,
      agent: agent,
      model: model,
    );
  }

  /// Sends through [send]; when the plugin rejects the selection as stale,
  /// the rejected cache row is gone before the typed failure reaches the
  /// client and triggers forced discovery.
  Future<void> _sendInvalidatingStaleOptionsCache({
    required String sessionId,
    required Future<void> Function() send,
  }) async {
    try {
      await send();
    } on PluginStaleOptionsException catch (error, stackTrace) {
      await _invalidateStaleOptionsCache(sessionId: sessionId);
      throw StaleSessionPromptOptionsException(cause: error, causeStackTrace: stackTrace);
    }
  }

  Future<void> _invalidateStaleOptionsCache({required String sessionId}) async {
    try {
      final scope = await _sessionRepository.findSessionOptionsScope(sessionId: sessionId);
      if (scope == null) return;
      await _sessionOptionsService.invalidateRejectedSelection(
        pluginId: scope.pluginId,
        projectId: scope.projectId,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Failed to invalidate stale session options cache for session $sessionId", error, stackTrace);
    }
  }

  /// Cancels the queued prompt [promptId] on [sessionId] before dispatch.
  ///
  /// Runs on the same serialized family lane as sends, so a cancel cannot
  /// race the enqueue or dispatch of the entry it names, and holds the same
  /// archive-permanence rule as every other session mutation. Returns whether
  /// an entry was removed.
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) {
    return _dispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.cancelQueuedPrompt,
      body: () async {
        await _archivedSessionValidator.requireNotArchived(sessionId: sessionId);
        return await _sessionRepository.cancelQueuedPrompt(sessionId: sessionId, promptId: promptId);
      },
    );
  }

  Future<void> _updatePromptDefaults({
    required String sessionId,
    required SessionVariant? variant,
    required bool fastMode,
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
      await _sessionRepository.updateRequestedPromptDefaults(
        sessionId: sessionId,
        agent: agent,
        agentModel: agentModel,
        fastMode: fastMode,
      );
      _promptDefaultsChangesController.add(
        SessionPromptDefaultsChange(
          sessionId: sessionId,
          promptDefaults: SessionPromptDefaults(
            agent: agent,
            model: agentModel,
            fastMode: fastMode,
          ),
        ),
      );
    } catch (error, stackTrace) {
      Log.w("Failed to update prompt defaults for session $sessionId", error, stackTrace);
    }
  }

  /// Records the agent and model the backend reports for [sessionId] and
  /// publishes the stored prompt defaults, which keep the session's fast mode.
  ///
  /// Publishes nothing when the write fails: a report without the stored fast
  /// mode would switch it off on the client.
  Future<void> recordBackendPromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) async {
    final SessionPromptDefaults? stored;
    try {
      stored = await _sessionRepository.updatePromptDefaults(
        sessionId: sessionId,
        agent: agent,
        agentModel: agentModel,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Failed to persist backend-originated prompt defaults for session $sessionId", error, stackTrace);
      return;
    }
    if (stored == null) return;
    _promptDefaultsChangesController.add(SessionPromptDefaultsChange(sessionId: sessionId, promptDefaults: stored));
  }

  Future<void> dispose() async {
    await _promptDefaultsChangesController.close();
  }

  static final Random _secureRandom = Random.secure();

  /// Bridge-generated prompt identity for sends that carry none (old clients,
  /// bridge-originated initial commands).
  static String generatePromptId() => generateRandomHexId(
    secureRandom: _secureRandom,
    prefix: "prm_",
    byteLength: 16,
  );
}
