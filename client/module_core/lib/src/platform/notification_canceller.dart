/// Abstract interface for dismissing all notifications for a session.
///
/// One notification identity per session (category-independent), so a single
/// call clears every notification for that session. Implemented by each
/// Flutter product shell's local-notification adapter.
abstract interface class NotificationCanceller() {
  /// Starts best-effort session cleanup without blocking the session action.
  /// Implementations retain and log native failures.
  void cancelForSession({required String sessionId});

  /// Dismisses every delivered notification owned by this application.
  ///
  /// Account-ending flows await this operation before clearing credentials.
  Future<void> cancelAll();
}
