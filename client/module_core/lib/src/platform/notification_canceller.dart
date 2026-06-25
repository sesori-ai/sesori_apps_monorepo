/// Abstract interface for dismissing all notifications for a session.
///
/// One notification identity per session (category-independent), so a single
/// call clears every notification for that session. Implemented by the Flutter
/// platform adapter in `app/`.
abstract interface class NotificationCanceller {
  void cancelForSession({required String sessionId});
}
