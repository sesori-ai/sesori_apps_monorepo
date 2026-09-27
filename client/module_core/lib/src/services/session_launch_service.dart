import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../errors/api_error_remote_failure_x.dart";
import "../foundation/models/composer/composer_draft.dart";
import "../foundation/models/composer/new_session_submission_snapshot.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
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
/// outcome analytics and its selection cleanup.
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

  static AnalyticsSubmission _analyticsSubmission({required NewSessionSubmissionSnapshot submission}) =>
      switch (submission) {
        NewSessionCommandSubmissionSnapshot() => const AnalyticsSubmission.command(),
        NewSessionTextSubmissionSnapshot(:final draft) => AnalyticsSubmission.text(
          inputMode: switch (draft.inputMode) {
            ComposerInputMode.typed => AnalyticsInputMode.typed,
            ComposerInputMode.voiceAssisted => AnalyticsInputMode.voiceAssisted,
          },
        ),
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
