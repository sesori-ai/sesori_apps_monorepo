/// Computes a deterministic, session-scoped push notification identity.
///
/// This is the single source of truth for the per-session notification
/// identity shared across the bridge and the mobile app. The bridge sends its
/// string form as the FCM collapse key (which the auth server maps to the
/// Android `notification.tag` and the iOS `apns-collapse-id`), and the mobile
/// app uses the same integer as the `flutter_local_notifications` id and
/// Android tag. Keeping one implementation here guarantees both ends agree on
/// the same value, so notifications for a session replace one another and can
/// be dismissed regardless of whether they were rendered in the foreground
/// (local plugin) or background (OS/FCM).
///
/// Deliberately session-scoped only — category is NOT part of the identity, so
/// every notification for a session collapses to one.
///
/// Uses FNV-1a 32-bit hashing to ensure:
/// - Same input always produces the same output (deterministic)
/// - Different sessions produce different outputs (collision-resistant)
/// - Output stays within the Android PendingIntent safe range [0, 2^27 - 1]
int sessionNotificationId({required String sessionId}) {
  const fnvOffsetBasis = 0x811c9dc5;
  const fnvPrime = 0x01000193;
  var hash = fnvOffsetBasis;

  for (var i = 0; i < sessionId.length; i++) {
    hash ^= sessionId.codeUnitAt(i);
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }

  return hash % 134217728; // safe positive range [0, 2^27 - 1]
}
