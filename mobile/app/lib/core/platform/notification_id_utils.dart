import 'package:sesori_shared/sesori_shared.dart';

/// Computes a deterministic notification ID from a session ID and notification category.
///
/// Uses FNV-1a 32-bit hash to ensure:
/// - Same inputs always produce the same output (deterministic)
/// - Different inputs produce different outputs (collision-resistant)
/// - Output is within Android PendingIntent safe range [0, 2^27 - 1]
///
/// This is suitable for use as a notification ID in Android/iOS notification systems.
int computeNotificationId(String sessionId, NotificationCategory category) {
  final input = '$sessionId:${category.id}';
  const fnvOffsetBasis = 0x811c9dc5;
  const fnvPrime = 0x01000193;
  var hash = fnvOffsetBasis;

  for (var i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }

  return hash % 134217728; // safe positive range [0, 2^27 - 1]
}
