import "package:sesori_shared/sesori_shared.dart";

/// Abstract interface for cancelling notifications by session context.
/// Implemented by Flutter platform adapter in `app/`.
abstract interface class NotificationCanceller {
  void cancelForSession({required String sessionId, required NotificationCategory category});
}
