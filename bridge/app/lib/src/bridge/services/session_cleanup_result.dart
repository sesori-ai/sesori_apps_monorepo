import "package:sesori_shared/sesori_shared.dart";

sealed class CleanupResult {}

final class CleanupSuccess extends CleanupResult {}

final class CleanupRejected extends CleanupResult {
  final SessionCleanupRejection rejection;

  CleanupRejected({required this.rejection});
}
