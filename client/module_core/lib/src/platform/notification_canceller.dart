/// Abstract interface for dismissing session-specific or application-wide
/// notifications.
///
/// One notification identity per session (category-independent), so a single
/// session call clears every notification for that session. Implemented by each
/// Flutter product shell's local-notification adapter.
abstract interface class NotificationCanceller() {
  /// Dismisses every delivered notification for [sessionId].
  ///
  /// Session actions may dispatch this without waiting, while owners that
  /// serialize native writes can await completion. Implementations retain and
  /// log native failures.
  Future<void> cancelForSession({required String sessionId});

  /// Dismisses every delivered notification owned by this application.
  ///
  /// Account-ending flows await this operation before clearing credentials.
  Future<void> cancelAll();
}
