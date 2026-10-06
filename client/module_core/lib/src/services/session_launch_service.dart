import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../errors/api_error_remote_failure_x.dart";
import "../foundation/models/composer/composer_draft.dart";
import "../foundation/models/composer/new_session_submission_snapshot.dart";
import "../foundation/models/composer/prompt_send_failure.dart";
import "../foundation/models/composer/queued_session_submission.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/models/session_launch/launch_follow_up.dart";
import "../foundation/models/session_launch/session_launch_handoff.dart";
import "../foundation/models/session_launch/session_launch_outcome.dart";
import "../logging/logging.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "../repositories/session_launch_repository.dart";
import "../repositories/session_repository.dart";
import "feedback_prompt_service.dart";
import "new_session_selection_tracker.dart";
import "product_analytics_service.dart";

/// Owns creating a session with its first message, for the app's lifetime,
/// so a user who leaves the composer mid-create still gets the session, its
/// outcome analytics and its selection cleanup, and delivers the messages sent
/// after the first one whether or not any screen is open.
@lazySingleton
class SessionLaunchService({
  required final SessionRepository _sessionRepository,
  required final SessionLaunchRepository _launchRepository,
  required final FeedbackPromptService _feedbackPromptService,
  required final ProductAnalyticsService _productAnalyticsService,
  required final NewSessionSelectionTracker _selectionTracker,
}) {
  Stream<SessionLaunchOutcome> get outcomes => _launchRepository.outcomes;

  void releaseHandoff({required String launchId}) => _launchRepository.releaseHandoff(launchId: launchId);

  SessionLaunchHandoff? takeHandoff({required String sessionId}) => _launchRepository.takeHandoff(sessionId: sessionId);

  Stream<List<LaunchFollowUp>> watchForSession({required String sessionId}) =>
      _launchRepository.watchForSession(sessionId: sessionId);

  /// Queues a message sent after the first one. It is sent once the session
  /// exists and every follow-up before it was accepted, in press order.
  void addFollowUp({required String launchId, required QueuedSessionSubmission submission}) {
    _launchRepository.addFollowUp(launchId: launchId, submission: submission);
    unawaited(_deliverFollowUps(launchId: launchId));
  }

  /// Sends a failed follow-up again under its original promptId.
  void retryFollowUp({required String promptId}) {
    final launchId = _launchRepository.retryFollowUp(promptId: promptId);
    if (launchId != null) unawaited(_deliverFollowUps(launchId: launchId));
  }

  /// Drops an unsent follow-up so the ones behind it can send.
  void cancelFollowUp({required String promptId}) {
    final launchId = _launchRepository.cancelFollowUp(promptId: promptId);
    if (launchId != null) unawaited(_deliverFollowUps(launchId: launchId));
  }

  /// Forgets a follow-up the bridge already delivered or settled, whatever its
  /// send reported or will report, so the ones behind it can send.
  void settleFollowUp({required String promptId}) {
    final launchId = _launchRepository.settleFollowUp(promptId: promptId);
    if (launchId != null) unawaited(_deliverFollowUps(launchId: launchId));
  }

  /// Creates the session and publishes its outcome on [outcomes].
  ///
  /// Success clears the composer selection captured here at Send, whether or
  /// not the composer is still open, so a deliberately chosen option is not
  /// reapplied to the next new session. A selection changed while creating is
  /// kept.
  Future<void> launch({
    required String launchId,
    required String projectId,
    required String pluginId,
    required DateTime startedAt,
    required NewSessionSubmissionSnapshot submission,
    required String? agent,
    required PromptModel? model,
    required SessionVariant? variant,
    required bool fastMode,
    required bool dedicatedWorktree,
  }) async {
    final selectionRevision = _selectionTracker.currentRevision(projectId: projectId, pluginId: pluginId);
    _launchRepository.start(
      launchId: launchId,
      projectId: projectId,
      pluginId: pluginId,
      startedAt: startedAt,
      submission: submission,
    );
    final response = await _sessionRepository.createSessionWithMessage(
      projectId: projectId,
      pluginId: pluginId,
      text: submission.draft.text,
      attachments: switch (submission) {
        NewSessionTextSubmissionSnapshot(:final attachments) => attachments,
        NewSessionCommandSubmissionSnapshot() => const [],
      },
      agent: agent,
      model: model,
      variant: variant,
      fastMode: fastMode,
      command: switch (submission) {
        NewSessionTextSubmissionSnapshot() => null,
        NewSessionCommandSubmissionSnapshot(:final command) => command,
      },
      dedicatedWorktree: dedicatedWorktree,
    );

    switch (response) {
      case SuccessResponse(data: final session):
        _selectionTracker.clearIfRevision(projectId: projectId, pluginId: pluginId, revision: selectionRevision);
        _reportProductEvent(
          event: ProductAnalyticsEvent.sessionCreatedWithMessage(
            submission: _analyticsSubmission(submission: submission),
            workspaceKind: session.hasWorktree
                ? AnalyticsWorkspaceKind.dedicatedWorktree
                : AnalyticsWorkspaceKind.project,
          ),
        );
        unawaited(_feedbackPromptService.recordPositiveInteraction());
        _launchRepository.promote(launchId: launchId, session: session);
        unawaited(_deliverFollowUps(launchId: launchId));
      case ErrorResponse(:final error):
        loge("New session creation failed", error);
        unawaited(_feedbackPromptService.recordFailure());
        // Until creation is idempotent, unconfirmed outcomes remain counted by
        // the released failure event rather than being guessed as successes.
        _reportProductEvent(
          event: ProductAnalyticsEvent.sessionCreationFailed(
            failureReason: _analyticsFailureReason(error.remoteFailureReason),
            workspaceKind: dedicatedWorktree
                ? AnalyticsWorkspaceKind.dedicatedWorktree
                : AnalyticsWorkspaceKind.project,
          ),
        );
        _launchRepository.fail(launchId: launchId, reason: error.remoteFailureReason);
    }
  }

  /// Sends the launch's follow-ups one at a time until none is queued. The
  /// repository marks each one sending before it goes, so a second call while
  /// one is in flight finds nothing to begin; a failure stops delivery until
  /// the user retries or cancels it, or the bridge settles it anyway. A
  /// follow-up settled while in flight is gone, so its outcome records nothing.
  Future<void> _deliverFollowUps({required String launchId}) async {
    while (true) {
      final next = _launchRepository.beginFollowUp(launchId: launchId);
      if (next == null) return;
      final (:sessionId, :submission) = next;
      final context = "follow-up ${submission.promptId} of launch $launchId to session $sessionId";
      PromptSendFailure failure;
      try {
        final result = await _sessionRepository.sendMessage(
          sessionId: sessionId,
          promptId: submission.promptId,
          text: submission.text,
          attachments: submission.attachments,
          agent: submission.agent,
          model: switch (submission.agentModel) {
            null => null,
            final agentModel => PromptModel(providerID: agentModel.providerID, modelID: agentModel.modelID),
          },
          variant: switch (submission.agentModel?.variant) {
            null => null,
            final variant => SessionVariant(id: variant),
          },
          fastMode: submission.fastMode,
          command: submission.command,
        );
        switch (result) {
          case SuccessResponse():
            _launchRepository.followUpAccepted(launchId: launchId, promptId: submission.promptId);
            _reportProductEvent(
              event: ProductAnalyticsEvent.sessionMessageSent(
                submission: switch (submission) {
                  QueuedTextSubmission(:final inputMode) => _analyticsTextSubmission(inputMode: inputMode),
                  QueuedCommandSubmission() ||
                  UnavailableQueuedCommandSubmission() => const AnalyticsSubmission.command(),
                },
              ),
            );
            unawaited(_feedbackPromptService.recordPositiveInteraction());
            continue;
          case ErrorResponse(:final error):
            logw("Failed to send $context", error);
            failure = SessionRepository.sendFailureFor(error: error);
        }
      } on Object catch (error, stackTrace) {
        logw("Failed to send $context", error, stackTrace);
        failure = PromptSendFailure.uncertain;
      }
      if (!_launchRepository.followUpFailed(launchId: launchId, promptId: submission.promptId, failure: failure)) {
        continue;
      }
      unawaited(_feedbackPromptService.recordFailure());
      return;
    }
  }

  static AnalyticsSubmission _analyticsTextSubmission({required ComposerInputMode inputMode}) =>
      AnalyticsSubmission.text(
        inputMode: switch (inputMode) {
          ComposerInputMode.typed => AnalyticsInputMode.typed,
          ComposerInputMode.voiceAssisted => AnalyticsInputMode.voiceAssisted,
        },
      );

  static AnalyticsSubmission _analyticsSubmission({required NewSessionSubmissionSnapshot submission}) =>
      switch (submission) {
        NewSessionCommandSubmissionSnapshot() => const AnalyticsSubmission.command(),
        NewSessionTextSubmissionSnapshot(:final draft) => _analyticsTextSubmission(inputMode: draft.inputMode),
      };

  static AnalyticsSessionCreationFailureReason _analyticsFailureReason(RemoteFailureReason reason) => switch (reason) {
    RemoteFailureReason.notAuthenticated => AnalyticsSessionCreationFailureReason.notAuthenticated,
    RemoteFailureReason.serverRejected => AnalyticsSessionCreationFailureReason.serverRejected,
    RemoteFailureReason.networkDown => AnalyticsSessionCreationFailureReason.networkDown,
    RemoteFailureReason.badResponse => AnalyticsSessionCreationFailureReason.badResponse,
    RemoteFailureReason.unknown => AnalyticsSessionCreationFailureReason.unknown,
  };

  void _reportProductEvent({required ProductAnalyticsEvent event}) {
    unawaited(
      _productAnalyticsService
          .logEvent(event: event, occurredAtUtc: DateTime.now().toUtc())
          .then<void>((result) {
            if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver new-session outcome analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report new-session outcome analytics event", error, stackTrace);
          }),
    );
  }
}
