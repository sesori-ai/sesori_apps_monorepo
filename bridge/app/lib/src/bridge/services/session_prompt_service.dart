import "dart:async";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "archived_session_validator.dart";
import "prompt_echo_correlator.dart";
import "session_operation_dispatcher.dart";

class const SessionPromptDefaultsChange({
  required final String sessionId,
  required final SessionPromptDefaults promptDefaults,
});

class SessionPromptService({
  required final SessionRepository _sessionRepository,
  required final SessionOperationDispatcher _dispatcher,
  required final ArchivedSessionValidator _archivedSessionValidator,
  required final PromptEchoCorrelator _promptEchoCorrelator,
}) {
  final StreamController<SessionPromptDefaultsChange> _promptDefaultsChangesController =
      StreamController<SessionPromptDefaultsChange>.broadcast(sync: true);

  Stream<SessionPromptDefaultsChange> get promptDefaultsChanges => _promptDefaultsChangesController.stream;

  Future<void> sendPrompt({
    required String sessionId,
    required String? promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
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
    required String? agent,
    required PromptModel? model,
    required String? normalizedCommand,
  }) async {
    // Inside the dispatched body, so this cannot race a concurrent archive on
    // the same family lane.
    await _archivedSessionValidator.requireNotArchived(sessionId: sessionId);
    if (normalizedCommand == null || normalizedCommand.isEmpty) {
      // Recorded before dispatch: a backend can publish its echo while this
      // call is still awaiting, and that echo must already find the id.
      _promptEchoCorrelator.recordDispatched(sessionId: sessionId, promptId: promptId);
      try {
        await _sessionRepository.sendPrompt(
          sessionId: sessionId,
          promptId: promptId,
          parts: parts,
          variant: variant,
          agent: agent,
          model: model,
        );
      } on PluginOperationException {
        // Only a refusal the plugin reports is definite: it produces no echo,
        // so the id must not stay pending for another prompt's echo to claim.
        // Any other failure (transport, timeout) may still have been accepted,
        // and its echo needs this correlation to survive.
        _promptEchoCorrelator.forgetPrompt(sessionId: sessionId, promptId: promptId);
        rethrow;
      }
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
    _promptEchoCorrelator.recordDispatched(sessionId: sessionId, promptId: promptId);
    try {
      await _sessionRepository.sendCommand(
        sessionId: sessionId,
        promptId: promptId,
        command: normalizedCommand,
        arguments: arguments ?? '',
        userVisibleArguments: arguments == null || arguments.trim().isEmpty ? null : arguments,
        variant: variant,
        agent: agent,
        model: model,
      );
    } on PluginOperationException {
      // See sendPrompt: only a reported refusal retires the correlation.
      _promptEchoCorrelator.forgetPrompt(sessionId: sessionId, promptId: promptId);
      rethrow;
    }
    await _updatePromptDefaults(
      sessionId: sessionId,
      variant: variant,
      agent: agent,
      model: model,
    );
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

  static final Random _secureRandom = Random.secure();

  /// Bridge-generated prompt identity for sends that carry none (old clients,
  /// bridge-originated initial commands).
  static String generatePromptId() {
    final buffer = StringBuffer("prm_");
    for (var index = 0; index < 16; index++) {
      buffer.write(_secureRandom.nextInt(256).toRadixString(16).padLeft(2, "0"));
    }
    return buffer.toString();
  }
}
