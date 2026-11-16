import "dart:async";
import "dart:math";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show buildWorktreeSystemContext;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginBranchPointUnavailableException, PluginRefusalException, PluginStaleOptionsException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/accepted_prompts_repository.dart";
import "../repositories/models/deliverable_prompt_part.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/random_hex_id.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_continuation_repository.dart";
import "../repositories/session_repository.dart";
import "archived_session_validator.dart";
import "chat_history_service.dart";
import "prompt_part_delivery_service.dart";
import "session_branch_refused_exception.dart";
import "session_mutation_dispatcher.dart";
import "session_operation_dispatcher.dart";
import "session_options_service.dart";
import "session_prompt_refused_exception.dart";
import "session_view_service.dart";
import "stale_session_prompt_options_exception.dart";

class const SessionPromptDefaultsChange({
  required final String sessionId,
  required final SessionPromptDefaults promptDefaults,
});

/// The settings a prompt takes from a session's remembered prompt defaults.
typedef PromptSettings = ({SessionVariant? variant, bool fastMode, String? agent, PromptModel? model});

/// What a send asks its session's plugin to do with the prompt.
sealed class const _PromptSend();

/// A prompt; [handoff] marks one Sesori wrote to send another session here.
final class const _PromptSendPrompt({required final MessageHandoff? handoff}) extends _PromptSend;

final class const _PromptSendCommand({
  required final String command,
  required final CommandSource? commandSource,
}) extends _PromptSend;

/// An edit: rewind to before [beforeMessageId], then send the prompt.
final class const _PromptSendRewind({required final String beforeMessageId}) extends _PromptSend;

class SessionPromptService({
  required final SessionRepository _sessionRepository,
  required final AcceptedPromptsRepository _acceptedPromptsRepository,
  required final SessionOperationDispatcher _dispatcher,
  required final ArchivedSessionValidator _archivedSessionValidator,
  required final SessionOptionsService _sessionOptionsService,
  required final SessionContinuationRepository _continuations,
  required final SessionViewService _views,
  required final SessionMutationDispatcher _mutations,
  required final PromptPartDeliveryService _promptPartDelivery,
  required final ChatHistoryService _chatHistory,
  required final ScheduledTaskRepository _scheduledTasks,
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
    required CommandSource? commandSource,
    required MessageHandoff? handoff,
  }) {
    final send = _promptOrCommand(command: command, commandSource: commandSource, handoff: handoff);
    return _dispatcher.dispatch(
      sessionId: sessionId,
      operation: switch (send) {
        _PromptSendCommand() => SessionOperation.sendCommand,
        _PromptSendPrompt() || _PromptSendRewind() => SessionOperation.sendPrompt,
      },
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
        send: send,
        byUser: true,
      ),
    );
  }

  /// Edits [messageId], a prompt that opens a turn: removes it and every
  /// later message from the session's conversation, then sends [parts] in its
  /// place. Files are never touched.
  ///
  /// A send in every other respect: the same archived rejection, [promptId]
  /// dedupe (a retry of an accepted edit succeeds without rewinding again),
  /// attachment delivery and prompt defaults. Refusals are
  /// [SessionBranchRefusedException]s.
  Future<void> rewindAndSendPrompt({
    required String sessionId,
    required String messageId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) {
    return _dispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.rewindSession,
      body: () async {
        try {
          await _sendPrompt(
            sessionId: sessionId,
            promptId: promptId,
            parts: parts,
            variant: variant,
            fastMode: fastMode,
            agent: agent,
            model: model,
            send: _PromptSendRewind(beforeMessageId: messageId),
            byUser: true,
          );
        } on StaleSessionPromptOptionsException catch (error) {
          throw SessionBranchRefusedException(
            code: SessionBranchErrorCode.staleSessionOptions,
            message: error.message,
            cause: error.cause,
            causeStackTrace: error.causeStackTrace,
          );
        } on SessionPromptRefusedException catch (error) {
          throw SessionBranchRefusedException(
            code: SessionBranchErrorCode.refused,
            message: error.userFacingReason,
            cause: error.cause,
            causeStackTrace: error.causeStackTrace,
          );
        }
      },
    );
  }

  /// Sends as [sendPrompt] does, for a caller that already holds the session's
  /// lane. It is the bridge's own send (a scheduled run, a quota continuation,
  /// a send-to-session summary request), never a person's prompt.
  Future<void> sendPromptAlreadyReserved({
    required String sessionId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required String? command,
    required CommandSource? commandSource,
    required MessageHandoff? handoff,
  }) => _sendPrompt(
    sessionId: sessionId,
    promptId: promptId,
    parts: parts,
    variant: variant,
    fastMode: fastMode,
    agent: agent,
    model: model,
    send: _promptOrCommand(command: command, commandSource: commandSource, handoff: handoff),
    byUser: false,
  );

  static _PromptSend _promptOrCommand({
    required String? command,
    required CommandSource? commandSource,
    required MessageHandoff? handoff,
  }) {
    final normalizedCommand = command?.trim();
    return normalizedCommand == null || normalizedCommand.isEmpty
        ? _PromptSendPrompt(handoff: handoff)
        : _PromptSendCommand(command: normalizedCommand, commandSource: commandSource);
  }

  Future<void> _sendPrompt({
    required String sessionId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required _PromptSend send,
    // A person's own prompt, which hands a scheduled run's session back to
    // the user, so its completions push again.
    required bool byUser,
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
    // Built before the quota cancellation below, so an edit its own checks
    // refuse leaves a pending continuation alone.
    final sendToPlugin = switch (send) {
      _PromptSendPrompt(:final handoff) => () async => await _sessionRepository.sendPrompt(
        sessionId: sessionId,
        promptId: promptId,
        parts: await _deliverableParts(sessionId: sessionId, parts: parts),
        variant: variant,
        fastMode: fastMode,
        agent: agent,
        model: model,
        handoff: handoff,
      ),
      _PromptSendCommand(:final command, :final commandSource) => () {
        final arguments = parts.whereType<PromptPartText>().firstOrNull?.text;
        // Per the BridgePluginApi contract, sendCommand completes once the
        // backend has accepted the command — not when its run finishes — so
        // awaiting it here never holds the phone's relay request open for
        // the duration of the command's agent run. A command sends only its
        // text, so it saves no files.
        return _sessionRepository.sendCommand(
          sessionId: sessionId,
          promptId: promptId,
          command: command,
          arguments: arguments ?? '',
          userVisibleArguments: arguments == null || arguments.trim().isEmpty ? null : arguments,
          variant: variant,
          fastMode: fastMode,
          agent: agent,
          model: model,
          commandSource: commandSource,
        );
      },
      _PromptSendRewind(:final beforeMessageId) => await _checkedRewind(
        sessionId: sessionId,
        beforeMessageId: beforeMessageId,
        promptId: promptId,
        parts: parts,
        variant: variant,
        fastMode: fastMode,
        agent: agent,
        model: model,
      ),
    };
    if (await _continuations.cancelCurrentObservationAlreadyReserved(sessionId: sessionId)) {
      try {
        _mutations.continuationUpdated(session: await _views.get(sessionId: sessionId));
      } on Object catch (error, stackTrace) {
        Log.w("Could not publish quota cancellation before prompt for session $sessionId", error, stackTrace);
      }
    }
    await _sendMappingRejections(sessionId: sessionId, send: sendToPlugin);
    try {
      await _acceptedPromptsRepository.recordAccepted(sessionId: sessionId, promptId: promptId);
    } catch (error, stackTrace) {
      // The plugin already owns the prompt; failing the send would only make
      // the client retry it.
      Log.w("Failed to record accepted prompt $promptId for session $sessionId", error, stackTrace);
    }
    if (byUser) {
      try {
        await _scheduledTasks.recordUserPrompted(sessionId: sessionId, at: DateTime.now());
      } on Object catch (error, stackTrace) {
        // The prompt went out; only the run's completion push stays silenced.
        Log.w("Failed to record the user's prompt on the scheduled run of session $sessionId", error, stackTrace);
      }
    }
    await _updatePromptDefaults(
      sessionId: sessionId,
      variant: variant,
      fastMode: fastMode,
      agent: agent,
      model: model,
    );
  }

  /// Sends through [send], turning the plugin's typed rejections into
  /// bridge-owned ones. When the plugin rejects the selection as stale, the
  /// rejected cache row is gone before the typed failure reaches the client
  /// and triggers forced discovery.
  Future<void> _sendMappingRejections({
    required String sessionId,
    required Future<void> Function() send,
  }) async {
    try {
      await send();
    } on PluginStaleOptionsException catch (error, stackTrace) {
      await _invalidateStaleOptionsCache(sessionId: sessionId);
      throw StaleSessionPromptOptionsException(cause: error, causeStackTrace: stackTrace);
    } on PluginRefusalException catch (error, stackTrace) {
      throw SessionPromptRefusedException(cause: error, causeStackTrace: stackTrace);
    }
  }

  /// The parts the plugin receives: files it can't take inline are saved and
  /// named by path. Called only once a send is going ahead, after the accepted
  /// check and the session's own checks (archived, busy, turn), so a repeated
  /// prompt, or one those checks refuse, saves no files.
  Future<List<DeliverablePromptPart>> _deliverableParts({
    required String sessionId,
    required List<PromptPart> parts,
  }) async => await _promptPartDelivery.deliverableParts(
    sessionId: sessionId,
    inlineImages: await _sessionRepository.inlineImagesSupportedForSession(sessionId: sessionId),
    parts: parts,
  );

  /// Checks the edit, then returns the send that rewinds through the plugin
  /// and removes the rewound messages from the store and every client by
  /// exact id. The ids are read before the send, so the edited prompt's own
  /// messages, which may be captured before the plugin returns, are never
  /// among them.
  Future<Future<void> Function()> _checkedRewind({
    required String sessionId,
    required String beforeMessageId,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) async {
    if (await _sessionRepository.isSessionRunning(sessionId: sessionId)) {
      throw const SessionBranchRefusedException(
        code: SessionBranchErrorCode.sessionBusy,
        message: null,
        cause: null,
        causeStackTrace: null,
      );
    }
    final removal = await _chatHistory.removalForRewind(sessionId: sessionId, messageId: beforeMessageId);
    final (:removedMessageIds, :edit) = switch (removal) {
      RewindRemovalLaterTurn(:final removedMessageIds) => (
        removedMessageIds: removedMessageIds,
        edit: () => _nativeRewind(
          sessionId: sessionId,
          beforeMessageId: beforeMessageId,
          removedMessageIds: removedMessageIds,
          promptId: promptId,
          parts: parts,
          variant: variant,
          fastMode: fastMode,
          agent: agent,
          model: model,
        ),
      ),
      // Nothing before the first turn is kept, so the edited prompt starts a
      // new harness session. Decided here, before any plugin rewind call, so
      // it works on every harness.
      RewindRemovalFirstTurn(:final removedMessageIds) => (
        removedMessageIds: removedMessageIds,
        edit: () => _replaceHarnessSession(
          sessionId: sessionId,
          parts: parts,
          variant: variant,
          fastMode: fastMode,
          agent: agent,
          model: model,
        ),
      ),
      RewindRemovalNotTurnOpener() => throw const SessionBranchRefusedException(
        code: SessionBranchErrorCode.branchPointUnavailable,
        message: null,
        cause: null,
        causeStackTrace: null,
      ),
    };
    return () async {
      await edit();
      await _publishRewound(sessionId: sessionId, removedMessageIds: removedMessageIds);
    };
  }

  /// Rewinds through the plugin. When the edit fails after the harness may
  /// have rewound, the messages it no longer has are removed anyway.
  Future<void> _nativeRewind({
    required String sessionId,
    required String beforeMessageId,
    required List<String> removedMessageIds,
    required String promptId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) async {
    try {
      await _sessionRepository.rewindAndSendPrompt(
        sessionId: sessionId,
        beforeMessageId: beforeMessageId,
        promptId: promptId,
        parts: await _deliverableParts(sessionId: sessionId, parts: parts),
        variant: variant,
        fastMode: fastMode,
        agent: agent,
        model: model,
      );
    } on PluginBranchPointUnavailableException catch (error, stackTrace) {
      throw SessionBranchRefusedException(
        code: SessionBranchErrorCode.branchPointUnavailable,
        message: error.userFacingReason,
        cause: error,
        causeStackTrace: stackTrace,
      );
    } on PluginStaleOptionsException {
      // Like the branch point, refused before the conversation changed.
      rethrow;
    } on PluginRefusalException {
      rethrow;
    } on Object {
      await _reconcileFailedRewind(sessionId: sessionId, removedMessageIds: removedMessageIds);
      rethrow;
    }
  }

  /// Moves the session onto a new harness session whose first prompt is
  /// [parts], then purges the history of the sub-agent sessions that went
  /// with the old one.
  Future<void> _replaceHarnessSession({
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
  }) async {
    final userParts = await _deliverableParts(sessionId: sessionId, parts: parts);
    final removedSessionIds = await _sessionRepository.replaceBackendSession(
      sessionId: sessionId,
      parts: [
        ...await _worktreeContextParts(sessionId: sessionId),
        ...userParts,
      ],
      userVisibleText: DeliverablePromptPart.userVisibleText(parts: userParts),
      variant: variant,
      fastMode: fastMode,
      agent: agent,
      model: model,
    );
    try {
      await _chatHistory.purgeSessionsHistory(sessionIds: removedSessionIds, includeArchive: true);
    } on Object catch (error, stackTrace) {
      Log.w("Failed to purge the history of sessions $removedSessionIds removed by an edit", error, stackTrace);
    }
  }

  /// The worktree context a new harness session's first prompt carries, as
  /// at session creation, when the session runs in a dedicated worktree.
  Future<List<DeliverablePromptPart>> _worktreeContextParts({required String sessionId}) async {
    final session = await _sessionRepository.getStoredSession(sessionId: sessionId);
    if (session case StoredSession(isDedicated: true, :final worktreePath?, :final baseBranch?)) {
      return [
        DeliverablePromptPart.text(
          text: buildWorktreeSystemContext(worktreePath: worktreePath, baseBranch: baseBranch),
        ),
      ];
    }
    return const [];
  }

  /// The harness may have rewound before the edit's resend failed (Codex
  /// reverts, then starts the turn), so the messages it no longer has are
  /// removed as a successful edit removes them. The edit still fails, and the
  /// client keeps the edited text.
  Future<void> _reconcileFailedRewind({required String sessionId, required List<String> removedMessageIds}) async {
    final List<String> missing;
    try {
      missing = await _chatHistory.messagesMissingFromHarness(sessionId: sessionId, messageIds: removedMessageIds);
    } on Object catch (error, stackTrace) {
      Log.w("Could not read session $sessionId from its harness after its edit failed", error, stackTrace);
      return;
    }
    await _publishRewound(sessionId: sessionId, removedMessageIds: missing);
  }

  /// Removes [removedMessageIds] from the store and every client. Never
  /// fails: the edit's outcome is already decided, and a later backfill drops
  /// what this could not.
  Future<void> _publishRewound({required String sessionId, required List<String> removedMessageIds}) async {
    if (removedMessageIds.isEmpty) return;
    try {
      final session = await _sessionRepository.getCatalogSession(sessionId: sessionId);
      if (session == null) {
        Log.w("Session $sessionId disappeared after its edit; its rewound messages stay stored");
        return;
      }
      _mutations.messagesRewound(session: session, removedMessageIds: removedMessageIds);
    } on Object catch (error, stackTrace) {
      Log.w("Could not publish the rewound messages of session $sessionId", error, stackTrace);
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

    /// Rechecked after the write: a retired plugin generation must not reach clients.
    required bool Function() isCurrentSource,
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
    if (stored == null || !isCurrentSource()) return;
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

  /// The settings a bridge-originated prompt to a session takes from its
  /// remembered [defaults].
  static PromptSettings settingsFrom({required SessionPromptDefaults? defaults}) {
    final model = defaults?.model;
    final variant = model?.variant;
    return (
      variant: variant == null ? null : SessionVariant(id: variant),
      fastMode: defaults?.fastMode ?? false,
      agent: defaults?.agent,
      model: model == null ? null : PromptModel(providerID: model.providerID, modelID: model.modelID),
    );
  }
}
