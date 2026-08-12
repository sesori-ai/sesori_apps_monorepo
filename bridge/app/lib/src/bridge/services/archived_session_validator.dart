import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";

class SessionArchivedReadOnlyException({required this.rejection}) implements Exception {
  final SessionArchivedRejection rejection;

  @override
  String toString() => "session ${rejection.sessionId} is archived and read-only";
}

/// The single archive-permanence rule in the bridge. Archiving is final, so an
/// archived session can never be unarchived, prompted, or otherwise mutated.
class ArchivedSessionValidator({required SessionRepository sessionRepository}) {
  final SessionRepository _sessionRepository;

  this : _sessionRepository = sessionRepository;

  /// Throws [SessionArchivedReadOnlyException] when [sessionId] is archived.
  ///
  /// This is a store-only read, so it answers even when the session's plugin is
  /// stopped. An unknown session is not archived; the caller owns that 404, and
  /// receives `null` so it does not have to read the row again.
  Future<StoredSession?> requireNotArchived({required String sessionId}) async {
    final storedSession = await _sessionRepository.getStoredSession(sessionId: sessionId);
    if (storedSession?.archivedAt == null) return storedSession;
    throw SessionArchivedReadOnlyException(
      rejection: SessionArchivedRejection(
        sessionId: sessionId,
        reason: SessionArchivedReason.archivedReadOnly,
      ),
    );
  }
}
