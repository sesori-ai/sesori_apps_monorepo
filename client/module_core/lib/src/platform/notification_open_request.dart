import "package:meta/meta.dart";

/// Product-neutral request to open a notification target.
///
/// Desktop requires [accountId] to match the active account. Mobile requests
/// leave it null and retain their push-registration ownership checks.
///
/// [bridgeId] names the computer the session runs on; mobile switches to it
/// before opening the session. It is null when the notification did not say,
/// and the session then opens on the current computer.
@immutable
class const NotificationOpenRequest({
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final String? accountId,
  required final String? bridgeId,
});
