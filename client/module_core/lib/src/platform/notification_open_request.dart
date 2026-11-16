import "package:freezed_annotation/freezed_annotation.dart";

part "notification_open_request.freezed.dart";

/// Product-neutral request to open a notification target.
///
/// Desktop requires [accountId] to match the active account. Mobile requests
/// leave it null and retain their push-registration ownership checks.
///
/// [bridgeId] names the computer the target lives on; mobile switches to it
/// before opening the target. It is null when the notification did not say,
/// and the target then opens on the current computer.
@immutable
class const NotificationOpenRequest({
  required final NotificationOpenTarget target,
  required final String? accountId,
  required final String? bridgeId,
});

/// What a notification opens: a session's conversation, or a scheduled
/// task's page for a run that could not start.
@freezed
sealed class NotificationOpenTarget with _$NotificationOpenTarget {
  const factory session({
    required String projectId,
    required String sessionId,
    required String? sessionTitle,
  }) = NotificationOpenSession;

  const factory task({required String taskId}) = NotificationOpenTask;

  /// The target a notification's ids name: its session when it names one,
  /// otherwise its scheduled task, and null when it names neither.
  static NotificationOpenTarget? of({
    required String? projectId,
    required String? sessionId,
    required String? sessionTitle,
    required String? taskId,
  }) => switch ((projectId, sessionId, taskId)) {
    (final projectId?, final sessionId?, _) => NotificationOpenTarget.session(
      projectId: projectId,
      sessionId: sessionId,
      sessionTitle: sessionTitle,
    ),
    (_, _, final taskId?) => NotificationOpenTarget.task(taskId: taskId),
    _ => null,
  };
}
