/// Abstract interface for dismissing all notifications for a session.
///
/// One notification identity per session (category-independent), so a single
/// call clears every notification for that session. Implemented by each
/// Flutter product shell's local-notification adapter.
abstract interface class NotificationCanceller() {
  void cancelForSession({required String sessionId});

  /// Dismisses every delivered notification owned by this application.
  Future<void> cancelAll();
}
