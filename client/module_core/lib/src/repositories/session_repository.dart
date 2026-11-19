import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

import "../api/session_api.dart";
import "../capabilities/relay/relay_client.dart";
import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/composer/prompt_send_failure.dart";
import "../foundation/models/session_options/session_options_request_mode.dart";
import "../logging/logging.dart";
import "models/send_to_session_result.dart";
import "models/session_abort_not_accepted_exception.dart";
import "models/session_abort_rejected_exception.dart";
import "models/session_cleanup_rejection.dart";
import "models/session_diff_summary_result.dart";
import "models/session_fork_result.dart";
import "models/session_messages_through_result.dart";
import "models/session_options_repository_result.dart";
import "models/session_page_result.dart";
import "models/session_pin_result.dart";
import "models/session_prompt_index_result.dart";
import "models/session_prompt_search_result.dart";
import "models/session_rewind_result.dart";
import "models/tool_output_result.dart";

@lazySingleton
class SessionRepository({
  required final SessionApi _api,
}) {
  Future<ApiResponse<Session>> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) async {
    try {
      return await _api.archiveSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        force: force,
      );
    } on SessionCleanupApiRejectedException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SessionCleanupRejectedException(
          rejection: SessionCleanupRejection(issues: error.rejection.issues),
          innerError: error,
        ),
        stackTrace,
      );
    }
  }

  Future<ApiResponse<Session>> renameSession({required String sessionId, required String title}) {
    return _api.renameSession(sessionId: sessionId, title: title);
  }

  Future<ApiResponse<Session>> setAutoContinuation({required String sessionId, required bool enabled}) {
    return _api.setAutoContinuation(sessionId: sessionId, enabled: enabled);
  }

  Future<ApiResponse<Session>> setApprovalOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) {
    return _api.setApprovalOverride(sessionId: sessionId, approvalOverride: approvalOverride);
  }

  Future<ApiResponse<SuccessEmptyResponse>> stopAcceptingEdits({required String sessionId}) {
    return _api.stopAcceptingEdits(sessionId: sessionId);
  }

  Future<SessionPinResult> setPinned({required String sessionId, required bool pinned}) async {
    final response = await _api.setPinned(sessionId: sessionId, pinned: pinned);
    return switch (response) {
      SuccessResponse(:final data) => SessionPinUpdated(session: data),
      // COMPATIBILITY 2026-11-14 (v1.14.0): a bridge without the
      // /session/pinned route answers with the router's route-not-found 404.
      // Remove once no supported bridge predates the route.
      ErrorResponse(:final error) when _isMissingRoute(error: error) => const SessionPinUnsupported(),
      ErrorResponse(:final error) => SessionPinFailure(error: error),
    };
  }

  Future<ApiResponse<MoveSessionPinResponse>> movePin({required String sessionId, required String? afterSessionId}) {
    return _api.movePin(sessionId: sessionId, afterSessionId: afterSessionId);
  }

  Future<SendToSessionResult> sendToSession({required String sourceSessionId, required String targetSessionId}) async {
    final response = await _api.sendToSession(sourceSessionId: sourceSessionId, targetSessionId: targetSessionId);
    return switch (response) {
      SuccessResponse() => const SendToSessionSent(),
      // COMPATIBILITY 2026-11-15 (v1.14.0): Bridges before session sending
      // have no /session/send-to-session route and answer with the router's
      // route-not-found 404. Remove the unsupported result once the minimum
      // supported bridge has the route.
      ErrorResponse(:final error) when _isMissingRoute(error: error) => const SendToSessionUnsupported(),
      ErrorResponse(:final NonSuccessCodeError error) when error.errorCode == 409 => _sendRefusal(error: error),
      // The request went out, so the bridge may have sent it.
      ErrorResponse(:final DartHttpClientError error)
          when error.innerError is TimeoutException || error.innerError is RelayResponseLostException =>
        SendToSessionUnconfirmed(error: error),
      ErrorResponse(:final error) => SendToSessionFailed(error: error),
    };
  }

  static SendToSessionResult _sendRefusal({required NonSuccessCodeError error}) {
    final body = error.rawErrorString;
    if (body == null) return SendToSessionFailed(error: error);
    try {
      final refusal = SendToSessionErrorResponse.fromJson(jsonDecodeMap(body));
      return SendToSessionRefused(code: refusal.code, message: refusal.message);
    } on Object catch (parseError, stackTrace) {
      // The type only: a parse error quotes the body, which can hold the harness's message.
      logw("Failed to parse the send-to-session refusal: ${parseError.runtimeType}", null, stackTrace);
      return SendToSessionFailed(error: error);
    }
  }

  Future<ApiResponse<void>> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteSessionFolder,
    required bool force,
  }) async {
    try {
      return await _api.deleteSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteSessionFolder: deleteSessionFolder,
        force: force,
      );
    } on SessionCleanupApiRejectedException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SessionCleanupRejectedException(
          rejection: SessionCleanupRejection(issues: error.rejection.issues),
          innerError: error,
        ),
        stackTrace,
      );
    }
  }

  /// Throws typed exceptions only for exact non-mutating 409 outcomes.
  Future<ApiResponse<bool>> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
  }) async {
    try {
      return switch (await _api.abortSession(sessionId: sessionId, subAgents: subAgents)) {
        SuccessResponse(:final data) => ApiResponse.success(data.subAgentsHandled),
        ErrorResponse(:final error) => ApiResponse.error(error),
      };
    } on SessionAbortApiRejectedException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SessionAbortRejectedException(rejection: error.rejection, innerError: error),
        stackTrace,
      );
    } on SessionAbortApiNotAcceptedException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SessionAbortNotAcceptedException(refusal: error.refusal, innerError: error),
        stackTrace,
      );
    }
  }

  Future<ApiResponse<void>> markSessionSeen({required String sessionId, required bool read}) {
    return _api.markSessionSeen(sessionId: sessionId, read: read);
  }

  Future<ApiResponse<void>> replyToQuestion({
    required String requestId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) {
    return _api.replyToQuestion(requestId: requestId, sessionId: sessionId, answers: answers);
  }

  Future<ApiResponse<void>> rejectQuestion({required String requestId, required String sessionId}) {
    return _api.rejectQuestion(requestId: requestId, sessionId: sessionId);
  }

  Future<ApiResponse<MessageWithPartsResponse>> getMessages({
    required String sessionId,
    required int? limit,
    required int? before,
    required bool storedOnly,
  }) {
    return _api.getMessages(sessionId: sessionId, limit: limit, before: before, storedOnly: storedOnly);
  }

  Future<SessionMessagesThroughResult> getMessagesThrough({
    required String sessionId,
    required int throughSeq,
    required int before,
    required bool storedOnly,
  }) async {
    final response = await _api.getMessagesThrough(
      sessionId: sessionId,
      throughSeq: throughSeq,
      before: before,
      storedOnly: storedOnly,
    );
    return switch (response) {
      SuccessResponse(:final data) => SessionMessagesThroughAvailable(
        messages: data.messages,
        olderMessagesCursor: data.nextCursor,
        userMessagesBefore: data.userMessagesBefore,
      ),
      ErrorResponse(:final error) => SessionMessagesThroughFailure(error: error),
    };
  }

  Future<SessionPromptIndexResult> getPromptIndex({required String sessionId}) async {
    final response = await _api.getPromptIndex(sessionId: sessionId);
    return switch (response) {
      SuccessResponse(:final data) => SessionPromptIndexAvailable(entries: data.entries),
      // COMPATIBILITY 2026-10-07 (v1.9.1): a bridge without the
      // /session/prompts route answers with the router's route-not-found 404.
      // A 404 from the route itself stays a failure. Remove once no supported
      // bridge predates the route.
      ErrorResponse(:final error) when _isMissingRoute(error: error) => const SessionPromptIndexUnsupported(),
      ErrorResponse(:final error) => SessionPromptIndexFailure(error: error),
    };
  }

  Future<SessionPageResult> getSessionPage({required SessionPageRequest request}) async {
    final response = await _api.getSessionPage(request: request);
    return switch (response) {
      SuccessResponse(:final data) => SessionPageLoaded(page: data),
      // COMPATIBILITY 2026-10-28 (v1.10.2): a bridge without the
      // /sessions/page route answers with the router's route-not-found 404.
      // Remove once no supported bridge predates the route.
      ErrorResponse(:final error) when _isMissingRoute(error: error) => const SessionPageUnsupported(),
      ErrorResponse(:final error) => SessionPageFailure(error: error),
    };
  }

  Future<SessionPromptSearchResult> searchPrompts({required String sessionId, required String query}) async {
    final response = await _api.searchPrompts(sessionId: sessionId, query: query);
    return switch (response) {
      SuccessResponse(:final data) => SessionPromptSearchAvailable(matches: data.matches),
      ErrorResponse(:final error) => SessionPromptSearchFailure(error: error),
    };
  }

  Future<ToolOutputResult> getToolOutput({
    required String sessionId,
    required String messageId,
    required String partId,
  }) async {
    final response = await _api.getToolOutput(sessionId: sessionId, messageId: messageId, partId: partId);
    return switch (response) {
      SuccessResponse(:final data) => ToolOutputAvailable(output: data.output, error: data.error),
      ErrorResponse(:final error) => ToolOutputFailure(error: error),
    };
  }

  /// Whether [error] is the bridge router's own 404 for a route it does not
  /// have, as opposed to a 404 a route returned.
  static bool _isMissingRoute({required ApiError error}) =>
      error is NonSuccessCodeError &&
      error.errorCode == 404 &&
      (error.rawErrorString?.startsWith("no handler found for ") ?? false);

  Future<ApiResponse<PendingQuestionResponse>> getPendingQuestions({required String sessionId}) {
    return _api.getPendingQuestions(sessionId: sessionId);
  }

  Future<ApiResponse<PendingExternalActionsResponse>> getPendingExternalActions({required String sessionId}) {
    return _api.getPendingExternalActions(sessionId: sessionId);
  }

  Future<ApiResponse<ExternalActionReplyResult>> replyToExternalAction({
    required ReplyToExternalActionRequest request,
  }) {
    return _api.replyToExternalAction(request: request);
  }

  Future<ApiResponse<PendingFormsResponse>> getPendingForms({required String sessionId}) =>
      _api.getPendingForms(sessionId: sessionId);

  Future<ApiResponse<FormReplyResult>> replyToForm({required ReplyToFormRequest request}) =>
      _api.replyToForm(request: request);

  Future<ApiResponse<FormReplyResult>> declineForm({required DeclineFormRequest request}) =>
      _api.declineForm(request: request);

  Future<ApiResponse<PageLookupResponse>> lookupPage({required PageLookupRequest request}) =>
      _api.lookupPage(request: request);

  Future<ApiResponse<PageSubmitResult>> submitPage({required SubmitPageRequest request}) =>
      _api.submitPage(request: request);

  Future<ApiResponse<PendingPermissionResponse>> getPendingPermissions({required String sessionId}) {
    return _api.getPendingPermissions(sessionId: sessionId);
  }

  Future<ApiResponse<SessionListResponse>> getChildren({required String sessionId}) {
    return _api.getChildren(sessionId: sessionId);
  }

  Future<ApiResponse<SessionStatusResponse>> getSessionStatuses() {
    return _api.getSessionStatuses();
  }

  Future<ApiResponse<SessionDiffsResponse>> getSessionDiffs({required String sessionId}) {
    return _api.getSessionDiffs(sessionId: sessionId);
  }

  Future<SessionDiffSummaryResult> getSessionDiffSummary({required String sessionId}) async {
    final response = await _api.getSessionDiffSummary(sessionId: sessionId);
    return switch (response) {
      SuccessResponse(:final data) => SessionDiffSummaryAvailable(
        additions: data.additions,
        deletions: data.deletions,
      ),
      // COMPATIBILITY 2026-09-25 (v1.9.1): a bridge before v1.9.1 has no
      // /session/diff-summary route and answers with a bare 404, while this
      // bridge gives its own 404 a SessionDiffSummaryErrorResponse body.
      // Remove once no supported bridge predates the route.
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404, :final rawErrorString))
          when !_isSessionDiffSummaryError(rawErrorString: rawErrorString) =>
        const SessionDiffSummaryUnsupported(),
      ErrorResponse(:final error) => SessionDiffSummaryFailure(error: error),
    };
  }

  bool _isSessionDiffSummaryError({required String? rawErrorString}) {
    if (rawErrorString == null) return false;
    try {
      SessionDiffSummaryErrorResponse.fromJson(jsonDecodeMap(rawErrorString));
      return true;
    } on Object {
      // Not this route's body: the bridge that answered does not know the route.
      return false;
    }
  }

  Future<ApiResponse<Session>> getSession({required String sessionId}) {
    return _api.getSession(sessionId: sessionId);
  }

  Future<LegacySessionOptionsRepositoryResult> loadLegacySessionOptions({
    required String projectId,
    required String pluginId,
  }) async {
    final (agents, providers, commands) = await (
      _api.listAgents(projectId: projectId, pluginId: pluginId),
      _api.listProviders(projectId: projectId, pluginId: pluginId),
      _api.listCommands(projectId: projectId, pluginId: pluginId),
    ).wait;
    final catalog = SessionOptionsCatalog(
      agents: switch (agents) {
        SuccessResponse(:final data) => data.agents,
        ErrorResponse() => const <AgentInfo>[],
      },
      providers: switch (providers) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => const <ProviderInfo>[],
      },
      providersConnectedOnly: switch (providers) {
        SuccessResponse(:final data) => data.connectedOnly,
        ErrorResponse() => false,
      },
      commands: switch (commands) {
        SuccessResponse(:final data) => data.items,
        ErrorResponse() => const <CommandInfo>[],
      },
      lastUsedPromptDefaults: null,
    );
    final errors = <LegacySessionOptionError>[
      if (agents case ErrorResponse(:final error))
        LegacySessionOptionError(source: LegacySessionOptionSource.agents, error: error),
      if (providers case ErrorResponse(:final error))
        LegacySessionOptionError(source: LegacySessionOptionSource.providers, error: error),
      if (commands case ErrorResponse(:final error))
        LegacySessionOptionError(source: LegacySessionOptionSource.commands, error: error),
    ];
    if (errors.isEmpty) return LegacySessionOptionsRepositoryAvailable(catalog: catalog);
    final anyAvailable = agents is SuccessResponse || providers is SuccessResponse || commands is SuccessResponse;
    return anyAvailable
        ? LegacySessionOptionsRepositoryPartial(catalog: catalog, errors: errors)
        : LegacySessionOptionsRepositoryFailure(errors: errors);
  }

  Future<SessionOptionsRepositoryResult> loadSessionOptions({
    required String projectId,
    required String pluginId,
    required SessionOptionsRequestMode mode,
  }) async {
    final response = await _api.loadSessionOptions(
      projectId: projectId,
      pluginId: pluginId,
      mode: mode,
    );
    return _mapSessionOptionsResponse(response: response);
  }

  SessionOptionsRepositoryResult _mapSessionOptionsResponse({
    required ApiResponse<SessionOptionsResponse> response,
  }) {
    return switch (response) {
      SuccessResponse(:final data) => SessionOptionsRepositoryAvailable(
        catalog: SessionOptionsCatalog(
          agents: data.agents.agents,
          providers: data.providers.items,
          providersConnectedOnly: data.providers.connectedOnly,
          commands: data.commands.items,
          lastUsedPromptDefaults: data.lastUsedPromptDefaults,
        ),
        isStale: data.stale,
      ),
      ErrorResponse(:final error) => _mapSessionOptionsError(error: error),
    };
  }

  SessionOptionsRepositoryResult _mapSessionOptionsError({required ApiError error}) {
    if (error case NonSuccessCodeError(:final errorCode, :final rawErrorString)) {
      if (rawErrorString != null) {
        try {
          final response = SessionOptionsErrorResponse.fromJson(jsonDecodeMap(rawErrorString));
          final actionHint = response.actionHint?.trim();
          return switch (response.code) {
            SessionOptionsErrorCode.cacheUnavailable => const SessionOptionsRepositoryCacheUnavailable(),
            SessionOptionsErrorCode.projectNotFound => SessionOptionsRepositoryProjectNotFound(error: error),
            SessionOptionsErrorCode.authenticationRequired when actionHint != null && actionHint.isNotEmpty =>
              SessionOptionsRepositoryAuthenticationRequired(actionHint: actionHint),
            SessionOptionsErrorCode.authenticationRequired => SessionOptionsRepositoryFailure(error: error),
            SessionOptionsErrorCode.refreshFailedRetained => const SessionOptionsRepositoryRefreshFailedRetained(),
            SessionOptionsErrorCode.refreshFailedUnavailable =>
              const SessionOptionsRepositoryRefreshFailedUnavailable(),
            SessionOptionsErrorCode.unknown => SessionOptionsRepositoryFailure(error: error),
          };
        } on Object {
          // Route absence is classified below; other transport failures retain
          // the original error as their explicit observable outcome.
        }
      }
      if (errorCode == 404) return const SessionOptionsRepositoryUnsupported();
    }
    return SessionOptionsRepositoryFailure(error: error);
  }

  Future<ApiResponse<Session>> createSessionWithMessage({
    required String projectId,
    required String pluginId,
    required String text,
    required List<ComposerAttachment> attachments,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required bool fastMode,
    required String? command,
    required CommandSource? commandSource,
    required bool dedicatedWorktree,
  }) {
    return _api.createSessionWithMessage(
      projectId: projectId,
      pluginId: pluginId,
      text: text,
      attachments: attachments,
      agent: agent,
      model: _normalizeModel(model: model),
      variant: variant,
      fastMode: fastMode,
      command: command?.normalize(),
      commandSource: commandSource,
      dedicatedWorktree: dedicatedWorktree,
    );
  }

  Future<ApiResponse<void>> sendMessage({
    required String sessionId,
    required String promptId,
    required String text,
    required List<ComposerAttachment> attachments,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required bool fastMode,
    required String? command,
    required CommandSource? commandSource,
  }) {
    return _api.sendMessage(
      sessionId: sessionId,
      promptId: promptId,
      text: text,
      attachments: attachments,
      agent: agent,
      model: _normalizeModel(model: model),
      variant: variant,
      fastMode: fastMode,
      command: command?.normalize(),
      commandSource: commandSource,
    );
  }

  /// Edits [messageId], a user message that opens a turn: the bridge removes
  /// it and every later message, then sends [text] and [attachments] instead.
  Future<SessionRewindResult> rewindSession({
    required String sessionId,
    required String messageId,
    required String promptId,
    required String text,
    required List<ComposerAttachment> attachments,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required bool fastMode,
  }) async {
    final response = await _api.rewindSession(
      sessionId: sessionId,
      messageId: messageId,
      promptId: promptId,
      text: text,
      attachments: attachments,
      agent: agent,
      model: _normalizeModel(model: model),
      variant: variant,
      fastMode: fastMode,
    );
    return switch (response) {
      SuccessResponse() => const SessionRewindAccepted(),
      ErrorResponse(:final NonSuccessCodeError error) when error.errorCode >= 400 && error.errorCode < 500 =>
        switch (_branchErrorResponse(error: error)) {
          SessionBranchErrorResponse(code: SessionBranchErrorCode.sessionBusy) => const SessionRewindBusy(),
          SessionBranchErrorResponse(code: SessionBranchErrorCode.branchPointUnavailable, :final message) =>
            SessionRewindUnavailable(reason: message),
          SessionBranchErrorResponse(code: SessionBranchErrorCode.staleSessionOptions) =>
            const SessionRewindOptionsChanged(),
          SessionBranchErrorResponse(code: SessionBranchErrorCode.refused, :final message) => SessionRewindRejected(
            reason: message,
          ),
          // Fork-only codes never answer an edit.
          SessionBranchErrorResponse(
            code: SessionBranchErrorCode.nothingToFork ||
                SessionBranchErrorCode.worktreeBranchMissing ||
                SessionBranchErrorCode.unknown,
          ) =>
            const SessionRewindRejected(reason: null),
          // Without a refusal the bridge may have rewound before failing, so
          // this stays a failure the same prompt id can retry.
          null => SessionRewindFailed(error: error),
        },
      ErrorResponse(error: NotAuthenticatedError()) => const SessionRewindRejected(reason: null),
      ErrorResponse(:final error) => SessionRewindFailed(error: error),
    };
  }

  /// Forks [sessionId] at [point]. [recreateFromBase] answers a
  /// [SessionForkWorktreeBranchMissing] with a new worktree from the base
  /// branch.
  Future<SessionForkResult> forkSession({
    required String sessionId,
    required ForkPoint point,
    required bool recreateFromBase,
  }) async {
    final response = await _api.forkSession(sessionId: sessionId, point: point, recreateFromBase: recreateFromBase);
    return switch (response) {
      SuccessResponse(:final data) => SessionForked(session: data),
      ErrorResponse(:final NonSuccessCodeError error) when error.errorCode >= 400 && error.errorCode < 500 =>
        switch (_branchErrorResponse(error: error)) {
          SessionBranchErrorResponse(code: SessionBranchErrorCode.nothingToFork) => const SessionForkNothingToFork(),
          SessionBranchErrorResponse(code: SessionBranchErrorCode.branchPointUnavailable, :final message) =>
            SessionForkUnavailable(reason: message),
          SessionBranchErrorResponse(code: SessionBranchErrorCode.worktreeBranchMissing) =>
            const SessionForkWorktreeBranchMissing(),
          // A point inside a turn that started since the menu opened answers sessionBusy.
          SessionBranchErrorResponse(
            code: SessionBranchErrorCode.refused || SessionBranchErrorCode.sessionBusy,
            :final message,
          ) =>
            SessionForkRejected(reason: message),
          // Edit-only codes never answer a fork.
          SessionBranchErrorResponse(
            code: SessionBranchErrorCode.staleSessionOptions || SessionBranchErrorCode.unknown,
          ) =>
            const SessionForkRejected(reason: null),
          null => SessionForkFailed(error: error),
        },
      ErrorResponse(error: NotAuthenticatedError()) => const SessionForkRejected(reason: null),
      ErrorResponse(:final error) => SessionForkFailed(error: error),
    };
  }

  static SessionBranchErrorResponse? _branchErrorResponse({required NonSuccessCodeError error}) {
    if (error.rawErrorString case final raw?) {
      try {
        return SessionBranchErrorResponse.fromJson(jsonDecodeMap(raw));
      } on Object catch (parseError, stackTrace) {
        logw("Session branch error carried no structured refusal", parseError, stackTrace);
      }
    }
    return null;
  }

  PromptModel? _normalizeModel({required PromptModel? model}) {
    final normalizedProviderID = model?.providerID.normalize();
    final normalizedModelID = model?.modelID.normalize();
    if (normalizedProviderID == null || normalizedModelID == null) return null;
    return PromptModel(providerID: normalizedProviderID, modelID: normalizedModelID);
  }

  static bool isStalePromptOptionsError({required ApiError error}) =>
      _sendPromptErrorResponse(error: error)?.code == SendPromptErrorCode.staleSessionOptions;

  /// Only a client-error answer proves the prompt was not accepted. A 5xx (an
  /// OpenCode 502 can still run the prompt), a transport error or a timeout
  /// may have reached the harness anyway.
  static PromptSendFailure sendFailureFor({required ApiError error}) => switch (error) {
    NonSuccessCodeError(errorCode: >= 400 && < 500) => switch (_sendPromptErrorResponse(error: error)) {
      SendPromptErrorResponse(code: SendPromptErrorCode.staleSessionOptions) =>
        const PromptSendFailure.optionsChanged(),
      SendPromptErrorResponse(code: SendPromptErrorCode.refused, :final message) => PromptSendFailure.rejected(
        reason: message,
      ),
      _ => const PromptSendFailure.rejected(reason: null),
    },
    NotAuthenticatedError() => const PromptSendFailure.rejected(reason: null),
    NonSuccessCodeError() ||
    DartHttpClientError() ||
    GenericError() ||
    EmptyResponseError() ||
    JsonParsingError() => const PromptSendFailure.uncertain(),
  };

  static SendPromptErrorResponse? _sendPromptErrorResponse({required ApiError error}) {
    if (error case NonSuccessCodeError(:final rawErrorString?)) {
      try {
        return SendPromptErrorResponse.fromJson(jsonDecodeMap(rawErrorString));
      } on Object {
        // Older bridges answer with plain-text errors, which carry no
        // structured send error.
      }
    }
    return null;
  }

  Future<ApiResponse<QueuedPromptResponse>> getQueuedPrompts({required String sessionId}) {
    return _api.getQueuedPrompts(sessionId: sessionId);
  }

  Future<ApiResponse<void>> cancelQueuedPrompt({required String sessionId, required String promptId}) {
    return _api.cancelQueuedPrompt(sessionId: sessionId, promptId: promptId);
  }
}
