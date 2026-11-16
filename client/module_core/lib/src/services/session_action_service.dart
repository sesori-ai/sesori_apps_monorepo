import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../logging/logging.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "../repositories/models/send_to_session_result.dart";
import "../repositories/models/session_cleanup_rejection.dart";
import "../repositories/models/session_fork_result.dart";
import "../repositories/plugin_repository.dart";
import "../repositories/session_repository.dart";
import "models/session_cleanup_outcome.dart";
import "models/session_delete_result.dart";
import "models/session_sending.dart";
import "product_analytics_service.dart";
import "selected_computer_service.dart";
import "session_cleanup_service.dart";
import "session_send_tracker.dart";
import "session_unseen_tracker.dart";

/// Deletes sessions, marks them read or unread, forks them, and sends one
/// into another. The rows they change live in the session windows and the
/// trackers; this holds nothing a list shows.
@lazySingleton
class SessionActionService({
  required final SessionRepository _sessionRepository,
  required final SessionCleanupService _sessionCleanupService,
  required final SessionUnseenTracker _sessionUnseenTracker,
  required final FailureReporter _failureReporter,
  required final SelectedComputerService _selectedComputerService,
  required final ProductAnalyticsService _productAnalyticsService,
  required final PluginRepository _pluginRepository,
  required final SessionSendTracker _sendTracker,
}) {
  /// The harnesses whose bridge declared fork in the latest plugin listing;
  /// empty until one loads or after one fails.
  Set<String> _forkingPluginIds = const {};
  Future<void>? _forkCapabilityRefresh;

  /// Whether a session menu offers Fork for [session]: a top-level session
  /// whose harness forks, archived or not, per the latest listing. Each
  /// session screen refreshes it when it opens.
  bool canFork({required Session session}) => session.parentID == null && _forkingPluginIds.contains(session.pluginId);

  /// Reads which harnesses fork from the bridge's plugin listing. Concurrent
  /// calls share one request.
  Future<void> refreshForkCapabilities() =>
      _forkCapabilityRefresh ??= _loadForkCapabilities().whenComplete(() => _forkCapabilityRefresh = null);

  Future<void> _loadForkCapabilities() async {
    try {
      switch (await _pluginRepository.listPlugins()) {
        case SuccessResponse(:final data):
          _forkingPluginIds = {
            for (final plugin in data.plugins)
              if (plugin.sessionBranching.contains(SessionBranchingOperation.fork)) plugin.id,
          };
        case ErrorResponse(:final error):
          // The bridge may have changed, so offer no Fork it might refuse.
          _forkingPluginIds = const {};
          logw("[SessionActions] could not read which harnesses fork", error);
      }
    } on Object catch (error, stackTrace) {
      _forkingPluginIds = const {};
      logw("[SessionActions] could not read which harnesses fork", error, stackTrace);
    }
  }

  /// Forks [sessionId] at [point]; see [SessionRepository.forkSession].
  /// [pluginId] is its harness, for analytics, or null when unknown.
  Future<SessionForkResult> forkSession({
    required String sessionId,
    required String? pluginId,
    required ForkPoint point,
    required bool recreateFromBase,
  }) async {
    final result = await _sessionRepository.forkSession(
      sessionId: sessionId,
      point: point,
      recreateFromBase: recreateFromBase,
    );
    switch (result) {
      case SessionForked(:final session):
        logd("[SessionActions] forked session $sessionId into ${session.id}");
      case SessionForkNothingToFork() || SessionForkWorktreeBranchMissing():
        logd("[SessionActions] did not fork session $sessionId: ${result.runtimeType}");
      case SessionForkUnavailable() || SessionForkRejected():
        logw("[SessionActions] the bridge refused to fork session $sessionId: ${result.runtimeType}");
      case SessionForkFailed(:final error):
        loge("Failed to fork session $sessionId", error);
    }
    if (pluginId != null) {
      _reportProductEvent(
        event: ProductAnalyticsEvent.sessionForked(
          harness: AnalyticsHarness.fromPluginId(pluginId: pluginId),
          outcome: switch (result) {
            SessionForked() => AnalyticsSessionForkOutcome.succeeded,
            SessionForkUnavailable() => AnalyticsSessionForkOutcome.branchPointUnavailable,
            SessionForkNothingToFork() ||
            SessionForkWorktreeBranchMissing() ||
            SessionForkRejected() => AnalyticsSessionForkOutcome.refused,
            SessionForkFailed() => AnalyticsSessionForkOutcome.failed,
          },
        ),
      );
    }
    return result;
  }

  /// Marks a session read (clears its bold) or unread (forces bold). Applied
  /// optimistically to the tracker so the row updates immediately; the bridge
  /// echo delivers the authoritative state (including the project aggregate)
  /// within the round trip. On failure, the tracker gets back the value it
  /// held before the optimistic write, unless something newer replaced it.
  Future<void> markSessionSeen({required String projectId, required String sessionId, required bool read}) async {
    final write = _sessionUnseenTracker.applyLocalSessionUnseen(
      projectId: projectId,
      sessionId: sessionId,
      unseen: !read,
    );
    void restore() =>
        _sessionUnseenTracker.restoreLocalSessionUnseen(projectId: projectId, sessionId: sessionId, write: write);
    try {
      final response = await _sessionRepository.markSessionSeen(sessionId: sessionId, read: read);
      if (response case ErrorResponse(:final error)) {
        loge("Failed to mark session ${read ? "read" : "unread"}", error);
        restore();
      }
    } catch (e, st) {
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_list_mark_seen",
              fatal: false,
              reason: "Failed to mark session seen",
              information: [sessionId, "read=$read"],
            )
            .catchError((Object error, StackTrace stackTrace) {
              loge("Failed to report mark-seen error", error, stackTrace);
            }),
      );
      restore();
    }
  }

  /// Sends [sourceSessionId] into [targetSessionId]: the source writes a
  /// summary, then the target receives it with the source's transcript. This
  /// can take minutes, while the source writes. [sourcePluginId] is the
  /// source's harness, for analytics, and [targetTitle] the target's, for the
  /// session list, which shows the source as being sent until this completes.
  Future<SendToSessionResult> sendToSession({
    required String sourceSessionId,
    required String sourcePluginId,
    required String targetSessionId,
    required String? targetTitle,
  }) async {
    final sending = SessionSending(targetTitle: targetTitle);
    _sendTracker.start(sourceSessionId: sourceSessionId, sending: sending);
    try {
      return await _send(
        sourceSessionId: sourceSessionId,
        sourcePluginId: sourcePluginId,
        targetSessionId: targetSessionId,
      );
    } finally {
      _sendTracker.end(sourceSessionId: sourceSessionId, sending: sending);
    }
  }

  Future<SendToSessionResult> _send({
    required String sourceSessionId,
    required String sourcePluginId,
    required String targetSessionId,
  }) async {
    final computer = await _selectedComputerService.targetBridgeId();
    final result = switch (await _sessionRepository.sendToSession(
      sourceSessionId: sourceSessionId,
      targetSessionId: targetSessionId,
    )) {
      final SendToSessionUnconfirmed unconfirmed =>
        await _recoverLostOutcome(
              sourceSessionId: sourceSessionId,
              targetSessionId: targetSessionId,
              computer: computer,
            ) ??
            unconfirmed,
      final answered => answered,
    };
    // Reported even after a computer switch: the send still ran on the computer the app left.
    _reportSendOutcome(sourcePluginId: sourcePluginId, result: result);
    final description = "session $sourceSessionId to $targetSessionId";
    if (await _selectedComputerService.targetBridgeId() != computer) {
      logw("[SessionActions] sending $description ended after a computer switch: ${result.runtimeType}");
      return const SendToSessionComputerSwitched();
    }
    switch (result) {
      case SendToSessionSent() || SendToSessionComputerSwitched():
        break;
      case SendToSessionUnsupported():
        logw("[SessionActions] could not send $description: the bridge predates sending sessions");
      case SendToSessionRefused(:final code):
        logd("[SessionActions] did not send $description: ${code.name}");
      case SendToSessionNotSent():
        logd("[SessionActions] did not send $description: its request is marked not sent");
      case SendToSessionFailed(:final error):
        loge("Failed to send $description", error);
      case SendToSessionUnconfirmed(:final error):
        logw("Could not confirm sending $description", error);
    }
    return result;
  }

  /// How often a send whose answer was lost reads the two transcripts.
  static const Duration _lostOutcomeCheckInterval = Duration(seconds: 10);

  /// How long it keeps reading: the bridge waits as long for the summary, so
  /// an outcome missing by then is not coming.
  static const int _lostOutcomeChecks = 90;

  /// The newest messages read from each session, enough to hold the summary
  /// request with its reply, or the handoff prompt behind the target's reply.
  static const int _lostOutcomeMessageLimit = 30;

  /// Finds the outcome of a send whose answer never arrived, typically
  /// because a phone in the background lost its connection while the source
  /// wrote. The bridge finishes the send regardless and records it: the
  /// source's summary request is marked not sent when the send fails, and the
  /// target holds the handoff prompt once it accepted. Reads fail while the
  /// app is offline, so the next check tries again. Null when the outcome
  /// does not show in time, or the app moved to another computer.
  Future<SendToSessionResult?> _recoverLostOutcome({
    required String sourceSessionId,
    required String targetSessionId,
    required String? computer,
  }) async {
    for (var check = 0; check < _lostOutcomeChecks; check++) {
      await Future<void>.delayed(_lostOutcomeCheckInterval);
      if (await _selectedComputerService.targetBridgeId() != computer) return null;
      final request = await _newestSummaryRequest(sourceSessionId: sourceSessionId, targetSessionId: targetSessionId);
      switch (request) {
        case MessageHandoffNotSent():
          return const SendToSessionNotSent();
        case MessageHandoffSent():
          if (await _targetHoldsHandoff(sourceSessionId: sourceSessionId, targetSessionId: targetSessionId)) {
            return const SendToSessionSent();
          }
        case MessageHandoffReceived() || MessageHandoffUnknown() || null:
          break;
      }
    }
    return null;
  }

  /// The stamp on the source's newest summary request for the target, or
  /// null when the read failed or holds none yet.
  Future<MessageHandoff?> _newestSummaryRequest({
    required String sourceSessionId,
    required String targetSessionId,
  }) async {
    final messages = await _newestMessages(sessionId: sourceSessionId);
    for (final message in messages.reversed) {
      if (message.info
          case MessageUser(
            handoff: final stamp? &&
                (MessageHandoffSent(targetSessionId: final to) || MessageHandoffNotSent(targetSessionId: final to)),
          )
          when to == targetSessionId) {
        return stamp;
      }
    }
    return null;
  }

  Future<bool> _targetHoldsHandoff({required String sourceSessionId, required String targetSessionId}) async {
    final messages = await _newestMessages(sessionId: targetSessionId);
    return messages.any(
      (message) => switch (message.info) {
        MessageUser(handoff: MessageHandoffReceived(sourceSessionId: final from)) => from == sourceSessionId,
        MessageUser() || MessageAssistant() || MessageError() => false,
      },
    );
  }

  Future<List<MessageWithParts>> _newestMessages({required String sessionId}) async {
    final response = await _sessionRepository.getMessages(
      sessionId: sessionId,
      limit: _lostOutcomeMessageLimit,
      before: null,
      storedOnly: false,
    );
    return switch (response) {
      SuccessResponse(:final data) => data.messages,
      // Offline until the app reconnects; the next check reads again.
      ErrorResponse() => const [],
    };
  }

  void _reportSendOutcome({required String sourcePluginId, required SendToSessionResult result}) {
    final AnalyticsSessionSendOutcome outcome;
    switch (result) {
      case SendToSessionSent():
        outcome = AnalyticsSessionSendOutcome.sent;
      case SendToSessionRefused(:final code):
        outcome = switch (code) {
          SendToSessionErrorCode.sourceBusy ||
          SendToSessionErrorCode.sourceAwaitingInput => AnalyticsSessionSendOutcome.refusedBusy,
          SendToSessionErrorCode.sameSession ||
          SendToSessionErrorCode.sourceArchived ||
          SendToSessionErrorCode.targetArchived ||
          SendToSessionErrorCode.sourceNotRoot ||
          SendToSessionErrorCode.sourceUnavailable ||
          SendToSessionErrorCode.sourceOptionsUnavailable ||
          SendToSessionErrorCode.targetOptionsUnavailable ||
          SendToSessionErrorCode.sourceEmpty ||
          SendToSessionErrorCode.summaryStopped ||
          SendToSessionErrorCode.summaryFailed ||
          SendToSessionErrorCode.summaryTimedOut ||
          SendToSessionErrorCode.summaryMissing ||
          SendToSessionErrorCode.transcriptUnavailable ||
          SendToSessionErrorCode.targetRefused ||
          SendToSessionErrorCode.unknown => AnalyticsSessionSendOutcome.refusedOther,
        };
      // The bridge declined it; only the answer saying why was lost.
      case SendToSessionNotSent():
        outcome = AnalyticsSessionSendOutcome.refusedOther;
      case SendToSessionFailed():
        outcome = AnalyticsSessionSendOutcome.failed;
      case SendToSessionUnsupported():
        outcome = AnalyticsSessionSendOutcome.unsupported;
      case SendToSessionUnconfirmed():
        outcome = AnalyticsSessionSendOutcome.unconfirmed;
      // Only this service hides an outcome after a switch; the repository never answers with it.
      case SendToSessionComputerSwitched():
        return;
    }
    _reportProductEvent(
      event: ProductAnalyticsEvent.sessionSentToSession(
        harness: AnalyticsHarness.fromPluginId(pluginId: sourcePluginId),
        outcome: outcome,
      ),
    );
  }

  void _reportProductEvent({required ProductAnalyticsEvent event}) {
    unawaited(
      _productAnalyticsService
          .logEvent(event: event, occurredAtUtc: DateTime.now().toUtc())
          .then<void>((delivery) {
            if (delivery == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver ${event.wireName} analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report ${event.wireName} analytics event", error, stackTrace);
          }),
    );
  }

  /// Deletes a session permanently. [deleteSessionFolder] also removes a
  /// "No project" session's own folder.
  Future<SessionDeleteResult> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteSessionFolder,
    required bool force,
  }) async {
    final ApiResponse<SessionCleanupOutcome> response;
    try {
      response = await _sessionCleanupService.deleteSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteSessionFolder: deleteSessionFolder,
        force: force,
      );
    } on SessionCleanupRejectedException catch (error) {
      logd("[SessionActions] delete rejected: cleanup issues=${error.rejection.issues}");
      return SessionDeleteRejected(rejection: error.rejection);
    }
    switch (response) {
      case SuccessResponse(:final data):
        return SessionDeleted(outcome: data);
      case ErrorResponse(:final error):
        loge("Failed to delete session $sessionId", error);
        return const SessionDeleteFailed();
    }
  }
}
