import "package:sesori_shared/sesori_shared.dart";

/// The canonical mutation rejection shared by bridge repositories and services.
class SessionArchivedReadOnlyException({required final SessionArchivedRejection rejection}) implements Exception {
  @override
  String toString() => "session ${rejection.sessionId} is archived and read-only";
}
