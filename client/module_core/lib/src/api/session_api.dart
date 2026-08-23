import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/session_options/session_options_request_mode.dart";
import "../logging/logging.dart";
import "../utils/bounded_json_encoder.dart";
import "client/relay_http_client.dart";

class const SessionCleanupApiRejectedException({required final SessionCleanupRejection rejection}) implements Exception;

@lazySingleton
class SessionApi({required final RelayHttpApiClient _client}) {
  static const Duration _attachmentRequestTimeout = Duration(minutes: 2);

  final BoundedJsonEncoder _attachmentEncoder = BoundedJsonEncoder(
    chunkSize: BoundedJsonEncoder.defaultChunkSize,
    yieldTurn: BoundedJsonEncoder.eventLoopTurn,
  );

  Future<ApiResponse<Agents>> listAgents({required String projectId, required String pluginId}) {
    return _client.post(
      "/agent",
      fromJson: Agents.fromJson,
      body: PluginProjectIdRequest(projectId: projectId, pluginId: pluginId),
    );
  }

  Future<ApiResponse<ProviderListResponse>> listProviders({required String projectId, required String pluginId}) {
    return _client.post(
      "/provider",
      fromJson: ProviderListResponse.fromJson,
      body: PluginProjectIdRequest(projectId: projectId, pluginId: pluginId),
    );
  }

  Future<ApiResponse<CommandListResponse>> listCommands({required String projectId, required String pluginId}) {
    return _client.post(
      "/command",
      fromJson: CommandListResponse.fromJson,
      body: PluginProjectIdRequest(projectId: projectId, pluginId: pluginId),
    );
  }

  Future<ApiResponse<SessionOptionsResponse>> loadSessionOptions({
    required String projectId,
    required String pluginId,
    required SessionOptionsRequestMode mode,
  }) {
    return _client.post(
      "/session/options",
      fromJson: SessionOptionsResponse.fromJson,
      body: PluginProjectIdRequest(projectId: projectId, pluginId: pluginId),
      queryParameters: switch (mode) {
        SessionOptionsRequestMode.dynamic => null,
        SessionOptionsRequestMode.cacheOnly => const {"refresh": "false"},
        SessionOptionsRequestMode.forceRefresh => const {"refresh": "true"},
      },
    );
  }

  Future<ApiResponse<Session>> createSessionWithMessage({
    required String projectId,
    required String pluginId,
    required String text,
    required List<ComposerAttachment> attachments,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required String? command,
    required bool dedicatedWorktree,
  }) {
    if (attachments.isEmpty) {
      return _client.post(
        "/session/create",
        fromJson: Session.fromJson,
        body: CreateSessionRequest(
          projectId: projectId,
          pluginId: pluginId,
          parts: _buildParts(text: text, attachments: attachments),
          agent: agent,
          model: model,
          variant: variant,
          command: command,
          dedicatedWorktree: dedicatedWorktree,
        ),
      );
    }

    return _createSessionWithAttachments(
      projectId: projectId,
      pluginId: pluginId,
      text: text,
      attachments: attachments,
      agent: agent,
      model: model,
      variant: variant,
      command: command,
      dedicatedWorktree: dedicatedWorktree,
    );
  }

  Future<ApiResponse<Session>> _createSessionWithAttachments({
    required String projectId,
    required String pluginId,
    required String text,
    required List<ComposerAttachment> attachments,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required String? command,
    required bool dedicatedWorktree,
  }) async {
    await BoundedJsonEncoder.eventLoopTurn();
    final request = CreateSessionRequest(
      projectId: projectId,
      pluginId: pluginId,
      parts: [if (text.isNotEmpty) PromptPart.text(text: text)],
      agent: agent,
      model: model,
      variant: variant,
      command: command,
      dedicatedWorktree: dedicatedWorktree,
    );
    return await _client.post(
      "/session/create",
      fromJson: Session.fromJson,
      body: await _attachmentEncoder.convertToString(
        value: _BoundedCreateSessionBody(request: request, attachments: attachments).toJson(),
      ),
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
    required String? command,
  }) {
    return _client.post(
      "/session/prompt_async",
      fromJson: SuccessEmptyResponse.fromJson,
      body: SendPromptRequest(
        sessionId: sessionId,
        parts: _buildParts(text: text, attachments: attachments),
        agent: agent,
        model: model,
        variant: variant,
        command: command,
        promptId: promptId,
      ),
    );
  }

  /// The bridge-owned queued prompts for a session. Old bridges without the
  /// route answer an error, which callers degrade to an empty list.
  Future<ApiResponse<QueuedPromptResponse>> getQueuedPrompts({required String sessionId}) {
    return _client.post(
      "/session/queued_prompts",
      fromJson: QueuedPromptResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  /// Cancels a bridge-queued prompt before it dispatches to the harness.
  Future<ApiResponse<void>> cancelQueuedPrompt({required String sessionId, required String promptId}) {
    return _client.post(
      "/session/prompt/cancel",
      fromJson: SuccessEmptyResponse.fromJson,
      body: CancelQueuedPromptRequest(sessionId: sessionId, promptId: promptId),
    );
  }

  /// The text part leads and is only omitted for attachment-only prompts, so
  /// text-only payloads stay byte-identical to what older clients sent.
  static List<PromptPart> _buildParts({
    required String text,
    required List<ComposerAttachment> attachments,
  }) {
    return [
      if (text.isNotEmpty || attachments.isEmpty) PromptPart.text(text: text),
      for (final attachment in attachments)
        PromptPart.fileData(
          mime: attachment.mime,
          base64: base64Encode(attachment.bytes),
          filename: attachment.filename,
        ),
    ];
  }

  Future<ApiResponse<Session>> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) async {
    final response = await _client.patch(
      "/session/update/archive",
      fromJson: Session.fromJson,
      body: UpdateSessionArchiveRequest(
        sessionId: sessionId,
        archived: true,
        deleteWorktree: deleteWorktree,
        // COMPATIBILITY 2026-08-13 (v1.7.1): Published bridges require this
        // retired field. Remove it when v1.7.1 bridges are unsupported.
        deleteBranch: false,
        force: force,
      ),
    );

    _throwIfCleanupRejected(response);
    return response;
  }

  Future<ApiResponse<Session>> renameSession({required String sessionId, required String title}) {
    return _client.patch(
      "/session/title",
      fromJson: Session.fromJson,
      body: RenameSessionRequest(sessionId: sessionId, title: title),
    );
  }

  Future<ApiResponse<void>> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) async {
    final response = await _client.delete(
      "/session/delete",
      fromJson: SuccessEmptyResponse.fromJson,
      body: DeleteSessionRequest(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        // COMPATIBILITY 2026-08-13 (v1.7.1): Published bridges require this
        // retired field. Remove it when v1.7.1 bridges are unsupported.
        deleteBranch: false,
        force: force,
      ),
    );

    _throwIfCleanupRejected(response);
    return response;
  }

  void _throwIfCleanupRejected<T>(ApiResponse<T> response) {
    if (response case ErrorResponse(error: NonSuccessCodeError(errorCode: 409, rawErrorString: final rawBody))) {
      try {
        if (rawBody == null) {
          throw const FormatException("invalid cleanup rejection json");
        }
        final rejection = SessionCleanupRejection.fromJson(jsonDecodeMap(rawBody));
        throw SessionCleanupApiRejectedException(rejection: rejection);
      } on SessionCleanupApiRejectedException {
        rethrow;
      } on Object catch (e) {
        logw("Failed to parse 409 cleanup rejection body: ${e.toString()}");
        return;
      }
    }
  }

  Future<ApiResponse<SessionListResponse>> getChildren({required String sessionId}) {
    return _client.post(
      "/session/children",
      fromJson: SessionListResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<SessionStatusResponse>> getSessionStatuses() {
    return _client.get(
      "/session/status",
      fromJson: SessionStatusResponse.fromJson,
    );
  }

  Future<ApiResponse<SessionDiffsResponse>> getSessionDiffs({required String sessionId}) {
    return _client.post(
      "/session/diffs",
      fromJson: SessionDiffsResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<Session>> getSession({required String sessionId}) {
    return _client.post(
      "/session/detail",
      fromJson: Session.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<SessionAttachmentResponse>> getAttachment({
    required String sessionId,
    required String attachmentId,
    required SessionAttachmentRendition rendition,
  }) {
    return _client.postWithTimeout(
      "/session/attachment",
      fromJson: SessionAttachmentResponse.fromJson,
      body: SessionAttachmentRequest(
        sessionId: sessionId,
        attachmentId: attachmentId,
        rendition: rendition,
      ),
      timeout: _attachmentRequestTimeout,
    );
  }

  /// A page of the session's messages. A null [limit] requests the whole
  /// transcript, which is also what an older bridge always returns.
  Future<ApiResponse<MessageWithPartsResponse>> getMessages({
    required String sessionId,
    required int? limit,
    required int? before,
  }) {
    return _client.post(
      "/session/messages",
      fromJson: MessageWithPartsResponse.fromJson,
      body: SessionMessagesRequest(
        sessionId: sessionId,
        limit: limit,
        before: before,
        attachmentDelivery: MessageAttachmentDelivery.storedReference,
      ),
    );
  }

  Future<ApiResponse<SuccessEmptyResponse>> abortSession({required String sessionId}) {
    return _client.post(
      "/session/abort",
      fromJson: SuccessEmptyResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  /// Marks a session read ([read] == true) or unread ([read] == false).
  Future<ApiResponse<SuccessEmptyResponse>> markSessionSeen({
    required String sessionId,
    required bool read,
  }) {
    return _client.post(
      "/session/seen",
      fromJson: SuccessEmptyResponse.fromJson,
      body: MarkSessionSeenRequest(sessionId: sessionId, read: read),
    );
  }

  Future<ApiResponse<PendingQuestionResponse>> getPendingQuestions({required String sessionId}) {
    return _client.post(
      "/session/questions",
      fromJson: PendingQuestionResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<PendingPermissionResponse>> getPendingPermissions({required String sessionId}) {
    return _client.post(
      "/session/permissions",
      fromJson: PendingPermissionResponse.fromJson,
      body: SessionIdRequest(sessionId: sessionId),
    );
  }

  Future<ApiResponse<void>> replyToQuestion({
    required String requestId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) {
    return _client.post(
      "/question/reply",
      fromJson: SuccessEmptyResponse.fromJson,
      body: ReplyToQuestionRequest(requestId: requestId, sessionId: sessionId, answers: answers),
    );
  }

  Future<ApiResponse<void>> rejectQuestion({required String requestId, required String sessionId}) {
    return _client.post(
      "/question/reject",
      fromJson: SuccessEmptyResponse.fromJson,
      body: RejectQuestionRequest(requestId: requestId, sessionId: sessionId),
    );
  }
}

final class _BoundedCreateSessionBody({
  required final CreateSessionRequest request,
  required final List<ComposerAttachment> attachments,
}) {
  Map<String, dynamic> toJson() {
    return request.toJson()
      ..["parts"] = [
        for (final part in request.parts) part.toJson(),
        for (final attachment in attachments)
          {
            "mime": attachment.mime,
            "base64": BoundedBase64Value(bytes: attachment.bytes),
            "filename": ?attachment.filename,
            "type": "file_data",
          },
      ];
  }
}
