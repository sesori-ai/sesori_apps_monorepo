import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show Log, PluginPromptOrigin, PluginStaleOptionsException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/deliverable_prompt_part.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/new_session_defaults_repository.dart";
import "../repositories/project_catalog_identity_calculator.dart";
import "../repositories/scratch_repository.dart";
import "../repositories/session_metadata_repository.dart";
import "../repositories/session_repository.dart";
import "prompt_part_delivery_service.dart";
import "session_deletion_service.dart";
import "session_mutation_dispatcher.dart";
import "session_options_service.dart";
import "session_prompt_service.dart";
import "stale_session_prompt_options_exception.dart";
import "worktree_service.dart";

class SessionCreationService({
  required final SessionMetadataRepository _sessionMetadataRepository,
  required final WorktreeService _worktreeService,
  required final SessionRepository _sessionRepository,
  required final NewSessionDefaultsRepository _newSessionDefaultsRepository,
  required final SessionMutationDispatcher _sessionMutationDispatcher,
  required final SessionOptionsService _sessionOptionsService,
  required final ScratchRepository _scratchRepository,
  required final ProjectCatalogIdentityCalculator _projectCatalogIdentityCalculator,
  required final PromptPartDeliveryService _promptPartDelivery,
  required final SessionDeletionService _sessionDeletionService,
}) {
  final PendingOperations _lateMetadataWork = PendingOperations();
  bool _acceptingLateMetadata = true;
  Future<void>? _drainFuture;

  Future<Session> createSession({required CreateSessionRequest request}) =>
      _createRejectingStaleOptions(request: request, scheduledRun: null, runContext: null);

  /// Starts a scheduled task's run as a new session. It goes through every
  /// check and step of [createSession] except remembering the picks as the
  /// user's new-session defaults, and the session row carries
  /// [ScheduledRunSessionLink.taskId] and the task's approval mode.
  ///
  /// A [runContext] note leads a text prompt's parts for the harness only;
  /// the user's own text stays what the session shows.
  Future<Session> createScheduledRunSession({
    required CreateSessionRequest request,
    required ScheduledRunSessionLink scheduledRun,
    required String? runContext,
  }) => _createRejectingStaleOptions(request: request, scheduledRun: scheduledRun, runContext: runContext);

  Future<Session> _createRejectingStaleOptions({
    required CreateSessionRequest request,
    required ScheduledRunSessionLink? scheduledRun,
    required String? runContext,
  }) async {
    try {
      return await _createSession(request: request, scheduledRun: scheduledRun, runContext: runContext);
    } on PluginStaleOptionsException catch (error, stackTrace) {
      try {
        await _sessionOptionsService.invalidateRejectedSelection(
          pluginId: request.pluginId,
          projectId: request.projectId,
        );
      } on Object catch (invalidationError, invalidationStackTrace) {
        Log.w("Failed to invalidate stale options after session creation", invalidationError, invalidationStackTrace);
      }
      throw StaleSessionPromptOptionsException(
        cause: error,
        causeStackTrace: stackTrace,
        agent: request.agent,
        model: request.model,
        variant: request.variant,
      );
    }
  }

  Future<Session> _createSession({
    required CreateSessionRequest request,
    required ScheduledRunSessionLink? scheduledRun,
    required String? runContext,
  }) async {
    // Validate the opaque project handle before any plugin/git side effect.
    // The stored path is authoritative; unknown ids are not directories.
    final projectDirectory = await _sessionRepository.resolveProjectDirectory(projectId: request.projectId);
    final normalizedCommand = request.command?.normalize();
    final requestedModel = request.model;
    final promptDefaults = SessionPromptDefaults(
      agent: request.agent,
      model: requestedModel == null
          ? null
          : AgentModel(
              providerID: requestedModel.providerID,
              modelID: requestedModel.modelID,
              variant: request.variant?.id,
            ),
      fastMode: request.fastMode,
    );
    final firstText = _nonBlankTexts(
      texts: request.parts.whereType<PromptPartText>().map((part) => part.text),
    ).firstOrNull;
    await _sessionRepository.ensurePluginRoutable(
      pluginId: request.pluginId,
      operation: SessionOperation.createSession,
    );
    // Reserved before the plugin call, so the first prompt's files are saved
    // under the id the session is committed with.
    final reservedSessionId = await _sessionRepository.reserveSessionId();
    // A create with a command sends none of the user's parts (see
    // _buildPromptParts), so it saves nothing.
    final userParts = normalizedCommand == null
        ? await _promptPartDelivery.deliverableParts(
            sessionId: reservedSessionId,
            inlineImages: _sessionRepository.inlineImagesSupported(pluginId: request.pluginId),
            parts: request.parts,
          )
        : const <DeliverablePromptPart>[];
    // From the delivered parts, so each saved file's note shows in place.
    final userVisibleText = DeliverablePromptPart.userVisibleText(parts: userParts);
    final WorktreeResult? worktreeResult;
    final _SessionCreationWorktreeState worktreeState;
    if (_projectCatalogIdentityCalculator.isScratchRoot(path: request.projectId)) {
      // A project-less session runs in its own new folder. There is no
      // repository to branch from, so a dedicated-worktree request is ignored.
      worktreeResult = null;
      worktreeState = _InPlaceSessionCreationWorktreeState(
        directory: await _scratchRepository.createSessionDirectory(),
        baseCommit: null,
      );
    } else {
      worktreeResult = await _prepareWorktree(request: request);
      worktreeState = await _resolveWorktreeState(
        projectId: request.projectId,
        projectDirectory: projectDirectory,
        worktreeResult: worktreeResult,
      );
    }
    // A scheduled run's prompt is the user's saved text, but Sesori sends it.
    final origin = scheduledRun == null ? PluginPromptOrigin.user : PluginPromptOrigin.sesori;
    final created = await _sessionRepository.createSession(
      reservedSessionId: reservedSessionId,
      pluginId: request.pluginId,
      projectId: request.projectId,
      directory: worktreeState.directory,
      parentSessionId: null,
      parts: _buildPromptParts(
        parts: userParts,
        worktreeResult: worktreeResult,
        command: normalizedCommand,
        runContext: runContext,
      ),
      origin: origin,
      userVisibleText: normalizedCommand == null ? userVisibleText : null,
      variant: normalizedCommand == null || normalizedCommand.isEmpty ? request.variant : null,
      fastMode: request.fastMode,
      agent: normalizedCommand == null || normalizedCommand.isEmpty ? request.agent : null,
      model: normalizedCommand == null || normalizedCommand.isEmpty ? request.model : null,
      isDedicated: worktreeState.isDedicated,
      worktreePath: worktreeState.worktreePath,
      baseBranch: worktreeState.baseBranch,
      baseCommit: worktreeState.baseCommit,
      lastAgent: promptDefaults.agent,
      lastAgentModel: promptDefaults.model,
      scheduledRun: scheduledRun,
    );
    try {
      await _maybeSendCommand(
        session: created,
        command: normalizedCommand,
        arguments: _buildCommandArguments(
          userArguments: firstText ?? '',
          worktreeResult: worktreeResult,
        ),
        userVisibleArguments: firstText,
        origin: origin,
        variant: request.variant,
        fastMode: request.fastMode,
        agent: request.agent,
        model: request.model,
        commandSource: request.commandSource,
      );
    } on PluginStaleOptionsException {
      // The harness ran nothing, so the session it just made would sit empty
      // beside the corrected retry; it goes before the refusal is reported.
      await _deleteRefusedSession(
        sessionId: created.id,
        // Only a project-less session got a folder of its own to remove.
        deleteSessionFolder: _projectCatalogIdentityCalculator.isScratchRoot(path: request.projectId),
      );
      rethrow;
    }
    // A scheduled run must not change the user's remembered picks.
    if (scheduledRun == null) {
      unawaited(
        _recordNewSessionDefaults(
          sessionId: created.id,
          pluginId: request.pluginId,
          defaults: promptDefaults,
        ),
      );
    }
    _startLateMetadata(session: created, firstText: firstText);
    return created;
  }

  Future<void> _deleteRefusedSession({required String sessionId, required bool deleteSessionFolder}) async {
    Log.i("Deleting session $sessionId: its first command was refused as stale");
    try {
      await _sessionDeletionService.deleteSession(
        sessionId: sessionId,
        deleteWorktree: true,
        force: true,
        deleteSessionFolder: deleteSessionFolder,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Failed to delete session $sessionId after its command was refused as stale", error, stackTrace);
    }
  }

  void beginShutdown() {
    if (!_acceptingLateMetadata) return;
    _acceptingLateMetadata = false;
    _sessionMetadataRepository.beginShutdown();
  }

  Future<void> drain() => _drainFuture ??= _drain();

  List<String> _nonBlankTexts({required Iterable<String> texts}) =>
      texts.where((text) => text.trim().isNotEmpty).toList(growable: false);

  Future<WorktreeResult?> _prepareWorktree({
    required CreateSessionRequest request,
  }) async {
    if (!request.dedicatedWorktree) {
      return null;
    }
    return await _worktreeService.prepareWorktreeForSession(projectId: request.projectId);
  }

  List<DeliverablePromptPart> _buildPromptParts({
    required List<DeliverablePromptPart> parts,
    required WorktreeResult? worktreeResult,
    required String? command,
    required String? runContext,
  }) {
    if (command != null) {
      return const [];
    }
    if (parts.isEmpty) {
      return parts;
    }
    return [
      if (worktreeResult case WorktreeSuccess(:final path, :final baseBranch))
        DeliverablePromptPart.text(
          text: buildWorktreeSystemContext(
            worktreePath: path,
            baseBranch: baseBranch,
          ),
        ),
      if (runContext != null) DeliverablePromptPart.text(text: runContext),
      ...parts,
    ];
  }

  Future<void> _maybeSendCommand({
    required Session session,
    required String? command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginPromptOrigin origin,
    required SessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required PromptModel? model,
    required CommandSource? commandSource,
  }) async {
    if (command == null) {
      return;
    }
    await _sessionRepository.sendCommand(
      sessionId: session.id,
      promptId: SessionPromptService.generatePromptId(),
      command: command,
      arguments: arguments,
      userVisibleArguments: userVisibleArguments,
      origin: origin,
      variant: variant,
      fastMode: fastMode,
      agent: agent,
      model: model,
      commandSource: commandSource,
    );
  }

  Future<void> _recordNewSessionDefaults({
    required String sessionId,
    required String pluginId,
    required SessionPromptDefaults defaults,
  }) async {
    try {
      await _newSessionDefaultsRepository.write(pluginId: pluginId, defaults: defaults);
    } on Object catch (error, stackTrace) {
      // The backend session is already durable. Failing the request here would
      // invite a duplicate retry for a preference write that can safely degrade.
      Log.w(
        "Failed to remember new-session defaults for plugin $pluginId after creating session $sessionId",
        error,
        stackTrace,
      );
    }
  }

  String _buildCommandArguments({
    required String userArguments,
    required WorktreeResult? worktreeResult,
  }) {
    if (worktreeResult case WorktreeSuccess(:final path, :final baseBranch)) {
      final systemContext = buildWorktreeSystemContext(
        worktreePath: path,
        baseBranch: baseBranch,
      ).trimRight();
      final trimmedArguments = userArguments.trim();
      if (trimmedArguments.isEmpty) {
        return systemContext;
      }
      return "$systemContext\n\n$trimmedArguments";
    }
    return userArguments;
  }

  Future<_SessionCreationWorktreeState> _resolveWorktreeState({
    required String projectId,
    required String projectDirectory,
    required WorktreeResult? worktreeResult,
  }) async {
    final String directory;
    switch (worktreeResult) {
      case WorktreeSuccess(
        :final path,
        baseBranch: final resolvedBaseBranch,
        baseCommit: final resolvedBaseCommit,
      ):
        return _DedicatedSessionCreationWorktreeState(
          path: path,
          baseBranch: resolvedBaseBranch,
          baseCommit: resolvedBaseCommit,
        );
      case WorktreeFallback(:final originalPath):
        directory = originalPath;
      case null:
        directory = projectDirectory;
    }
    final startCommit = await _worktreeService.resolveHeadCommit(projectId: projectId);
    // In-place sessions have no branch baseline. The immutable HEAD commit is
    // their exact comparison point even when local changes already exist.
    return _InPlaceSessionCreationWorktreeState(
      directory: directory,
      baseCommit: startCommit,
    );
  }

  void _startLateMetadata({required Session session, required String? firstText}) {
    if (!_acceptingLateMetadata || firstText == null) return;
    unawaited(
      _lateMetadataWork.track(
        operation: _generateAndApplyMetadata(session: session, firstText: firstText),
      ),
    );
  }

  Future<void> _generateAndApplyMetadata({required Session session, required String firstText}) async {
    final GeneratedSessionMetadata metadata;
    try {
      metadata = await _sessionMetadataRepository.generateMetadata(
        firstMessage: unwrapDictatedText(text: firstText),
      );
    } on SessionMetadataRequestAbortedException catch (error) {
      if (!_acceptingLateMetadata) return;
      Log.w(
        "Generated-metadata request was aborted for session ${session.id}",
        error.innerError,
        error.innerStackTrace,
      );
      return;
    } on SessionMetadataInvalidResponseException catch (error) {
      Log.w(
        "Failed to generate metadata for session ${session.id}",
        error.innerError,
        error.innerStackTrace,
      );
      return;
    } on Object catch (error, stackTrace) {
      Log.w("Failed to generate metadata for session ${session.id}", error, stackTrace);
      return;
    }

    try {
      await _sessionMutationDispatcher.applyGeneratedTitle(
        sessionId: session.id,
        title: metadata.title,
      );
    } on Object catch (error, stackTrace) {
      Log.w("Failed to apply generated title for session ${session.id}", error, stackTrace);
    }
  }

  Future<void> _drain() async {
    beginShutdown();
    await _lateMetadataWork.drain();
  }
}

sealed class _SessionCreationWorktreeState() {
  String get directory;
  bool get isDedicated;
  String? get worktreePath;
  String? get baseBranch;
  String? get baseCommit;
}

class _DedicatedSessionCreationWorktreeState({
  required final String path,
  @override required final String baseBranch,
  @override required final String baseCommit,
}) implements _SessionCreationWorktreeState {
  @override
  String get directory => path;

  @override
  bool get isDedicated => true;

  @override
  String get worktreePath => path;
}

class _InPlaceSessionCreationWorktreeState({
  @override required final String directory,
  @override required final String? baseCommit,
}) implements _SessionCreationWorktreeState {
  @override
  bool get isDedicated => false;

  @override
  String? get worktreePath => null;

  @override
  String? get baseBranch => null;
}
