import "dart:async";
import "dart:convert" show utf8;

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeSseSessionError, BridgeSseSessionIdle, Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mappers/session_transcript_markdown_builder.dart";
import "../repositories/models/history_window.dart";
import "../repositories/models/normalized_bridge_event.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/permission_repository.dart";
import "../repositories/prompt_upload_repository.dart";
import "../repositories/question_repository.dart";
import "../repositories/session_repository.dart";
import "chat_history_service.dart";
import "plugin_lifecycle_service.dart";
import "session_abort_service.dart";
import "session_event_dispatcher.dart";
import "session_operation_dispatcher.dart";
import "session_prompt_refused_exception.dart";
import "session_prompt_service.dart";
import "session_send_rejected_exception.dart";
import "session_view_service.dart";
import "stale_session_prompt_options_exception.dart";

/// Sends one session into another: the source's agent writes a handoff
/// summary in a normal turn, the source's transcript is saved for the target,
/// and the target receives both as a normal prompt.
///
/// Every failure is a [SessionSendRejectedException] with its reason. Logs
/// carry ids, counts, sizes and the transcript path, never prompt, summary or
/// transcript text.
class SessionSendService({
  required final SessionRepository _sessions,
  required final SessionViewService _views,
  required final PermissionRepository _permissions,
  required final QuestionRepository _questions,
  required final SessionOperationDispatcher _operations,
  required final SessionPromptService _prompts,
  required final SessionEventDispatcher _events,
  required final SessionAbortService _aborts,
  required final ChatHistoryService _history,
  required final PromptUploadRepository _transcripts,
  required final SessionTranscriptMarkdownBuilder _markdown,
  required final PluginLifecycleService _plugins,
  required final Clock _clock,

  /// How long the source may take to write the summary.
  required final Duration _summaryTimeout,

  /// How long a source whose summary turn failed may take to settle before
  /// its stored history is searched for a request it never echoed.
  required final Duration _settleTimeout,
}) {
  /// Fails every summary wait still open, so bridge shutdown does not wait
  /// out the summary timeout.
  final Set<void Function()> _shutdownHooks = {};
  bool _shuttingDown = false;

  /// Ends every send still waiting for its summary as `summaryStopped`. The
  /// orchestrator calls this before it removes event producers and drains
  /// routes.
  void beginShutdown() {
    _shuttingDown = true;
    for (final hook in _shutdownHooks.toList(growable: false)) {
      hook();
    }
  }

  /// Completes once the target has accepted the handoff prompt.
  Future<void> send({required String sourceSessionId, required String targetSessionId}) async {
    if (sourceSessionId == targetSessionId) throw _rejected(code: SendToSessionErrorCode.sameSession);
    final source = await _views.get(sessionId: sourceSessionId);
    final target = await _views.get(sessionId: targetSessionId);
    if (source.time?.archived != null) throw _rejected(code: SendToSessionErrorCode.sourceArchived);
    if (target.time?.archived != null) throw _rejected(code: SendToSessionErrorCode.targetArchived);
    if (source.parentID != null) throw _rejected(code: SendToSessionErrorCode.sourceNotRoot);
    if (await _hasNoMessages(sessionId: source.id)) throw _rejected(code: SendToSessionErrorCode.sourceEmpty);

    final promptId = SessionPromptService.generatePromptId();
    Log.i("Sending session ${source.id} to ${target.id}; requesting the summary as prompt $promptId");
    // Watching starts before the send, so the echo cannot be missed.
    final requestText = _summaryRequestText(targetTitle: target.title);
    final notSent = MessageHandoffNotSent(
      targetSessionId: target.id,
      targetTitle: _nonBlank(text: target.title),
    );
    final turn = _watchSummaryTurn(sessionId: source.id, promptId: promptId);
    var summaryRequested = false;
    try {
      await _requestSummary(source: source, target: target, promptId: promptId, requestText: requestText);
      summaryRequested = true;
      await _finishAfterSummaryRequest(
        source: source,
        target: target,
        turn: turn,
        requestText: requestText,
        notSent: notSent,
      );
    } on Object {
      // A send that did not complete keeps its summary exchange hidden behind
      // its marker: the request's stamp turns to not sent, first for an echo
      // that has yet to arrive, then in the stored history.
      _sessions.markHandoffNotSent(sessionId: source.id, promptId: promptId);
      switch (turn.requestMessageId()) {
        case final messageId?:
          await _markStoredRequestNotSent(sessionId: source.id, messageId: messageId, notSent: notSent);
        case null when summaryRequested:
          await _markUnechoedRequestNotSent(
            sessionId: source.id,
            promptId: promptId,
            turn: turn,
            requestText: requestText,
            notSent: notSent,
          );
        // A refused request, or a check that failed before it, left no stamp.
        case null:
          break;
      }
      rethrow;
    } finally {
      await turn.stop();
    }
    Log.i("Sent session ${source.id} to ${target.id}");
  }

  /// Runs once the source has accepted the summary request: waits for the
  /// summary, then hands it off with the transcript.
  Future<void> _finishAfterSummaryRequest({
    required Session source,
    required Session target,
    required _SummaryTurn turn,
    required String requestText,
    required MessageHandoffNotSent notSent,
  }) async {
    final String summaryRequestMessageId;
    try {
      summaryRequestMessageId = await turn.ended.timeout(_summaryTimeout);
    } on TimeoutException {
      throw _rejected(code: SendToSessionErrorCode.summaryTimedOut);
    }
    await turn.stop();
    final (:transcript, :summary, :storedRequestMessageId) = await _readSummary(
      sessionId: source.id,
      summaryRequestMessageId: summaryRequestMessageId,
      requestText: requestText,
    );
    try {
      if (summary == null) throw _rejected(code: SendToSessionErrorCode.summaryMissing);
      await _deliverHandoff(source: source, target: target, transcript: transcript, summary: summary);
    } on Object {
      // The refresh can have replaced the live echo with a replayed message
      // under another id, which carries the stamp now.
      if (storedRequestMessageId != summaryRequestMessageId) {
        await _markStoredRequestNotSent(sessionId: source.id, messageId: storedRequestMessageId, notSent: notSent);
      }
      rethrow;
    }
  }

  /// Marks a summary request the source stored without echoing it live, so
  /// no prompt id names it: Claude records a request it was stopped before
  /// echoing. Once the source has settled, the request is the last user
  /// message with its exact text in the refreshed history, as in the split.
  /// A stamped match is an earlier send's request, kept as it is.
  Future<void> _markUnechoedRequestNotSent({
    required String sessionId,
    required String promptId,
    required _SummaryTurn turn,
    required String requestText,
    required MessageHandoffNotSent notSent,
  }) async {
    try {
      await turn.settled.timeout(_settleTimeout);
    } on TimeoutException {
      Log.w("Session $sessionId did not settle after its summary turn failed; looking up prompt $promptId anyway");
    }
    if (_shuttingDown) return;
    final List<MessageWithParts> messages;
    try {
      messages = await _refreshedHistory(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      Log.w("Could not read session $sessionId to mark summary prompt $promptId as not sent", error, stackTrace);
      return;
    }
    final request = messages.where((message) => _isRequest(message: message, requestText: requestText)).lastOrNull;
    if (request?.info case MessageUser(:final id, handoff: null)) {
      Log.i("Marking summary request $id of session $sessionId, stored without its echo, as not sent");
      await _markStoredRequestNotSent(sessionId: sessionId, messageId: id, notSent: notSent);
    } else {
      Log.i("Session $sessionId stored no unstamped summary request for prompt $promptId");
    }
  }

  Future<void> _markStoredRequestNotSent({
    required String sessionId,
    required String messageId,
    required MessageHandoffNotSent notSent,
  }) async {
    try {
      await _history.markHandoffNotSent(sessionId: sessionId, messageId: messageId, notSent: notSent);
    } on Object catch (error, stackTrace) {
      Log.w("Could not mark summary request $messageId of session $sessionId as not sent", error, stackTrace);
    }
  }

  Future<bool> _hasNoMessages({required String sessionId}) async {
    final newest = await _history.getSessionMessages(
      sessionId: sessionId,
      window: const HistoryWindowNewest(limit: 1, before: null),
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
      toolOutputDelivery: ToolOutputDelivery.onExpand,
      storedOnly: false,
      backgroundRefresh: false,
    );
    return newest.messages.isEmpty;
  }

  /// Checks that the source is ready and sends the summary request inside one
  /// reservation of the source, so no other prompt can start in between. The
  /// reservation ends with the send, so the user can still stop the turn or
  /// answer its questions while the summary is written.
  Future<void> _requestSummary({
    required Session source,
    required Session target,
    required String promptId,
    required String requestText,
  }) => _operations.dispatch(
    sessionId: source.id,
    operation: SessionOperation.sendToSession,
    body: () async {
      // A send still validating when shutdown began must not start a turn.
      if (_shuttingDown) throw _rejected(code: SendToSessionErrorCode.sourceUnavailable);
      if (await _sourceRefusal(sessionId: source.id, pluginId: source.pluginId) case final code?) {
        throw _rejected(code: code);
      }
      final settings = SessionPromptService.settingsFrom(defaults: source.promptDefaults);
      try {
        await _prompts.sendPromptAlreadyReserved(
          sessionId: source.id,
          promptId: promptId,
          parts: [PromptPart.text(text: requestText)],
          variant: settings.variant,
          fastMode: settings.fastMode,
          agent: settings.agent,
          model: settings.model,
          command: null,
          commandSource: null,
          handoff: MessageHandoff.sent(
            targetSessionId: target.id,
            targetTitle: _nonBlank(text: target.title),
          ),
        );
      } on Object catch (error, stackTrace) {
        throw SessionSendRejectedException(
          code: error is StaleSessionPromptOptionsException
              ? SendToSessionErrorCode.sourceOptionsUnavailable
              : SendToSessionErrorCode.sourceUnavailable,
          userFacingReason: null,
          cause: error,
          causeStackTrace: stackTrace,
        );
      }
    },
  );

  /// Why the source cannot write a summary now, or null when it is ready.
  ///
  /// A plugin whose backend is not running reports no statuses, and a stopped
  /// backend runs no turn, so its sessions count as idle. A running backend
  /// that could not report statuses leaves readiness unknown, so the send is
  /// refused.
  Future<SendToSessionErrorCode?> _sourceRefusal({required String sessionId, required String pluginId}) async {
    final statuses = await _sessions.getSessionStatuses();
    switch (statuses.statuses[sessionId]) {
      case SessionStatusBusy() || SessionStatusRetry():
        return SendToSessionErrorCode.sourceBusy;
      case null when statuses.unavailablePluginIds.contains(pluginId) && _sessions.isPluginActive(pluginId: pluginId):
        return SendToSessionErrorCode.sourceUnavailable;
      case SessionStatusIdle() || null:
        break;
    }
    final permissions = await _permissions.getPendingPermissions(sessionId: sessionId);
    if (permissions.isNotEmpty) return SendToSessionErrorCode.sourceAwaitingInput;
    final questions = await _questions.getPendingQuestions(sessionId: sessionId);
    if (questions.isNotEmpty) return SendToSessionErrorCode.sourceAwaitingInput;
    return null;
  }

  /// Watches [sessionId] for the end of the turn that prompt [promptId]
  /// starts. [_SummaryTurn.ended] completes with the id of the user message
  /// that carried the prompt, once the source goes idle after it, and fails
  /// when the source is stopped or reports a session error.
  /// [_SummaryTurn.settled] completes at the source's first idle once the
  /// wait has ended, so a failed wait can tell when the turn it left is over.
  _SummaryTurn _watchSummaryTurn({required String sessionId, required String promptId}) {
    final ended = Completer<String>();
    // Stop or an error can arrive before anyone awaits the outcome.
    ended.future.ignore();
    final settled = Completer<void>();
    void settle() {
      if (!settled.isCompleted) settled.complete();
    }

    String? summaryRequestMessageId;
    void fail({required SendToSessionErrorCode code}) {
      if (!ended.isCompleted) ended.completeError(_rejected(code: code));
    }

    void observe({required NormalizedBridgeEvent event}) {
      final (payload, forcedStop) = switch (event) {
        NormalizedTerminalHandoff(:final payload) => (payload, true),
        final NormalizedBridgePayload payload => (payload, false),
      };
      switch (payload) {
        // Harnesses report the end of a turn as either event.
        case NormalizedStatusEvent(sessionId: final idleSessionId, status: SessionStatusIdle()) ||
                NormalizedOtherEvent(event: BridgeSseSessionIdle(sessionID: final idleSessionId))
            when idleSessionId == sessionId:
          // A plugin stopping mid-turn ends it without a finished summary.
          if (forcedStop) {
            fail(code: SendToSessionErrorCode.summaryFailed);
          } else if (summaryRequestMessageId case final messageId? when !ended.isCompleted) {
            ended.complete(messageId);
          }
          if (ended.isCompleted) settle();
        case _ when ended.isCompleted:
          break;
        case NormalizedMessageEvent(message: MessageUser(:final id, :final sessionID, promptId: final echoed))
            when sessionID == sessionId && echoed == promptId:
          summaryRequestMessageId = id;
        case NormalizedOtherEvent(event: BridgeSseSessionError(:final sessionID)) when sessionID == sessionId:
          fail(code: SendToSessionErrorCode.summaryFailed);
        // Some harnesses end a failed turn with an error message and a plain idle.
        case NormalizedMessageEvent(message: MessageError(:final sessionID))
            when sessionID == sessionId && summaryRequestMessageId != null:
          fail(code: SendToSessionErrorCode.summaryFailed);
        case NormalizedMessageEvent() ||
            NormalizedStatusEvent() ||
            NormalizedQueuedPromptsEvent() ||
            NormalizedQuotaInterruptionEvent() ||
            NormalizedOtherEvent():
          break;
      }
    }

    final eventSubscription = _events.events.listen(
      (sourced) => observe(event: sourced.event),
      // The dispatcher's own consumers report source errors; the wait simply
      // has nothing to observe for a failed event.
      onError: (Object _) {},
    );
    // Fires on every user stop and on archive's stop, before the plugin
    // confirms. A half-written summary must never reach the target.
    final abortSubscription = _aborts.abortStartedSessions.listen((stopped) {
      if (stopped == sessionId) fail(code: SendToSessionErrorCode.summaryStopped);
    });
    void onShutdown() {
      fail(code: SendToSessionErrorCode.summaryStopped);
      settle();
    }

    _shutdownHooks.add(onShutdown);
    return (
      ended: ended.future,
      settled: settled.future,
      requestMessageId: () => summaryRequestMessageId,
      stop: () async {
        _shutdownHooks.remove(onShutdown);
        await eventSubscription.cancel();
        await abortSubscription.cancel();
      },
    );
  }

  /// Reads the source's whole history and splits it at the summary request:
  /// the transcript is every message before it, and the summary is the text
  /// of the agent's replies after it, up to the next user message, or null
  /// when the agent wrote none.
  ///
  /// A history refresh can replace the live echo with a replayed message under
  /// another id, so a request missing under its echo id is found by its exact text.
  Future<({List<MessageWithParts> transcript, String? summary, String storedRequestMessageId})> _readSummary({
    required String sessionId,
    required String summaryRequestMessageId,
    required String requestText,
  }) async {
    final List<MessageWithParts> messages;
    try {
      messages = await _refreshedHistory(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      throw SessionSendRejectedException(
        code: SendToSessionErrorCode.transcriptUnavailable,
        userFacingReason: null,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
    final echoIndex = messages.indexWhere((message) => message.info.id == summaryRequestMessageId);
    final requestIndex = echoIndex >= 0
        ? echoIndex
        : messages.lastIndexWhere((message) => _isRequest(message: message, requestText: requestText));
    if (requestIndex < 0) {
      Log.w(
        "Session $sessionId history (${messages.length} messages) lacks summary request message "
        "$summaryRequestMessageId",
      );
      throw _rejected(code: SendToSessionErrorCode.summaryMissing);
    }
    final text = [
      // A prompt queued behind the summary starts the next turn.
      for (final message in messages.skip(requestIndex + 1).takeWhile((message) => message.info is! MessageUser))
        if (message.info case MessageAssistant(sender: MessageSender.agent))
          for (final part in message.parts)
            if (part case MessagePartText(:final text) when text.trim().isNotEmpty) text.trim(),
    ].join("\n\n");
    Log.i(
      "Session $sessionId summary has ${text.length} characters after $requestIndex transcript messages",
    );
    return (
      transcript: _withoutSummaryExchanges(messages: messages.sublist(0, requestIndex)),
      summary: text.isEmpty ? null : text,
      storedRequestMessageId: messages[requestIndex].info.id,
    );
  }

  /// The source's whole history, after a refresh from the backend.
  Future<List<MessageWithParts>> _refreshedHistory({required String sessionId}) async {
    // The live capture of the reply's parts can trail the idle event, so the
    // store is brought current first, as archive export does. A backend that
    // cannot replay leaves the store as the live stream filled it.
    try {
      await _history.backfillSession(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      Log.w(
        "Could not refresh the history of session $sessionId before sending it; using stored history",
        error,
        stackTrace,
      );
    }
    return (await _history.getSessionMessages(
      sessionId: sessionId,
      window: const HistoryWindowAll(),
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
      toolOutputDelivery: ToolOutputDelivery.inline,
      storedOnly: false,
      backgroundRefresh: false,
    )).messages;
  }

  /// Whether [message] is the summary request [requestText], as a replay
  /// under another id or a request stored without its echo reads.
  static bool _isRequest({required MessageWithParts message, required String requestText}) =>
      message.info is MessageUser && _textOf(message: message) == requestText;

  /// [messages] without the summary exchanges of earlier sends: each request
  /// Sesori wrote to the source, and the replies up to the next user message.
  /// They stay hidden behind their marker in the source, so the target never
  /// reads them either.
  static List<MessageWithParts> _withoutSummaryExchanges({required List<MessageWithParts> messages}) {
    final kept = <MessageWithParts>[];
    var inSummaryExchange = false;
    for (final message in messages) {
      if (message.info case final MessageUser user) {
        inSummaryExchange = switch (user.handoff) {
          MessageHandoffSent() || MessageHandoffNotSent() => true,
          MessageHandoffReceived() || MessageHandoffUnknown() || null => false,
        };
      }
      if (!inSummaryExchange) kept.add(message);
    }
    return kept;
  }

  /// Saves [transcript] for [target] and prompts [target] with [summary] and
  /// the transcript's path.
  Future<void> _deliverHandoff({
    required Session source,
    required Session target,
    required List<MessageWithParts> transcript,
    required String summary,
  }) async {
    final harnessName = _harnessName(pluginId: source.pluginId);
    final bytes = utf8.encode(
      _markdown.build(session: source, harnessName: harnessName, exportedAt: _clock.now(), messages: transcript),
    );
    final String transcriptPath;
    try {
      transcriptPath = await _transcripts.save(
        sessionId: target.id,
        bytes: bytes,
        filename: "${_nonBlank(text: source.title) ?? "transcript"}.md",
      );
    } on Object catch (error, stackTrace) {
      throw SessionSendRejectedException(
        code: SendToSessionErrorCode.transcriptUnavailable,
        userFacingReason: null,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
    Log.i("Saved the transcript of session ${source.id} for ${target.id} at $transcriptPath (${bytes.length} bytes)");

    final settings = SessionPromptService.settingsFrom(defaults: target.promptDefaults);
    try {
      await _prompts.sendPrompt(
        sessionId: target.id,
        promptId: null,
        parts: [
          PromptPart.text(
            text: _handoffText(
              sourceTitle: source.title,
              harnessName: harnessName,
              sourceDirectory: source.directory,
              summary: summary,
              transcriptPath: transcriptPath,
            ),
          ),
        ],
        variant: settings.variant,
        fastMode: settings.fastMode,
        agent: settings.agent,
        model: settings.model,
        command: null,
        commandSource: null,
        handoff: MessageHandoff.received(
          sourceSessionId: source.id,
          sourceTitle: _nonBlank(text: source.title),
          summary: summary,
          transcriptPath: transcriptPath,
        ),
      );
    } on Object catch (error, stackTrace) {
      throw SessionSendRejectedException(
        code: error is StaleSessionPromptOptionsException
            ? SendToSessionErrorCode.targetOptionsUnavailable
            : SendToSessionErrorCode.targetRefused,
        userFacingReason: error is SessionPromptRefusedException ? error.userFacingReason : null,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  String _harnessName({required String pluginId}) =>
      _plugins.selectableMetadataSnapshot.where((plugin) => plugin.id == pluginId).firstOrNull?.displayName ?? pluginId;

  static String _summaryRequestText({required String? targetTitle}) {
    final target = switch (_nonBlank(text: targetTitle)) {
      null => "another session",
      final title => 'another session, "$title"',
    };
    return "Sesori is sending this conversation to $target. Write a handoff summary for the agent there: the goal, "
        "what was done and decided, the current state, open questions and next steps, and the files that matter. "
        "Reply with the summary only, and don't use tools.";
  }

  static String _handoffText({
    required String? sourceTitle,
    required String harnessName,
    required String sourceDirectory,
    required String summary,
    required String transcriptPath,
  }) {
    final source = switch (_nonBlank(text: sourceTitle)) {
      null => "another Sesori session",
      final title => 'another Sesori session, "$title"',
    };
    return "This is a handoff from $source ($harnessName, in `$sourceDirectory`). Its agent wrote this summary:\n\n"
        "$summary\n\n"
        "The full transcript is at `$transcriptPath`. Read it only if you need details the summary leaves out.";
  }

  static String _textOf({required MessageWithParts message}) => [
    for (final part in message.parts)
      if (part case MessagePartText(:final text)) text,
  ].join();

  static String? _nonBlank({required String? text}) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// A rejection that no other failure caused.
  static SessionSendRejectedException _rejected({required SendToSessionErrorCode code}) =>
      SessionSendRejectedException(code: code, userFacingReason: null, cause: null, causeStackTrace: null);
}

/// The summary turn being watched: [ended] completes with the summary
/// request's user message id, [settled] once the source is idle after the
/// wait ended, [requestMessageId] reads that id once its echo has arrived,
/// and [stop] ends the watch. Stopping twice is harmless.
typedef _SummaryTurn = ({
  Future<String> ended,
  Future<void> settled,
  String? Function() requestMessageId,
  Future<void> Function() stop,
});
