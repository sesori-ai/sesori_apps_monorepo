import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../platform/url_launcher.dart";

sealed class const SessionExternalActionState();
final class const ExternalActionLoading() extends SessionExternalActionState;
final class const ExternalActionDisconnected() extends SessionExternalActionState;
final class const ExternalActionReadFailed({required final ApiError cause}) extends SessionExternalActionState;
sealed class const ExternalActionSettled() extends SessionExternalActionState;
final class const ExternalActionReplySent({required final ExternalActionChoice choice}) extends ExternalActionSettled;
final class const ExternalActionNoLongerPending() extends ExternalActionSettled;

final class const ExternalActionReady({
  required final PendingExternalAction action,
  required final Uri? destination,
  required final ExternalActionSubmission submission,
  required final ExternalActionBrowser browser,
}) extends SessionExternalActionState {
  ExternalActionReady withSubmission({required ExternalActionSubmission submission}) => ExternalActionReady(
    action: action,
    destination: destination,
    submission: submission,
    browser: browser,
  );
  ExternalActionReady withBrowser({required ExternalActionBrowser browser}) => ExternalActionReady(
    action: action,
    destination: destination,
    submission: submission,
    browser: browser,
  );
}

sealed class const ExternalActionSubmission();
final class const ExternalActionSubmissionIdle() extends ExternalActionSubmission;
final class const ExternalActionSubmitting({required final ExternalActionChoice choice})
    extends ExternalActionSubmission;
final class const ExternalActionSubmissionFailed({required final ApiError cause}) extends ExternalActionSubmission;
final class const ExternalActionSubmissionRefused({required final ExternalActionReplyResult result})
    extends ExternalActionSubmission;

sealed class const ExternalActionBrowser();
final class const ExternalActionBrowserIdle() extends ExternalActionBrowser;
final class const ExternalActionBrowserOpening() extends ExternalActionBrowser;
final class const ExternalActionBrowserOpened() extends ExternalActionBrowser;
final class const ExternalActionBrowserFailed({
  required final ExternalLinkLaunchFailure cause,
  required final StackTrace stackTrace,
}) extends ExternalActionBrowser;
