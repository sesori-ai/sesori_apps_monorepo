import "package:meta/meta.dart";

/// Product-neutral request to open a notification target.
///
/// Desktop requires [accountId] to match the active account. Mobile requests
/// leave it null and retain their push-registration ownership checks.
@immutable
class const NotificationOpenRequest({
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final String? accountId,
});
