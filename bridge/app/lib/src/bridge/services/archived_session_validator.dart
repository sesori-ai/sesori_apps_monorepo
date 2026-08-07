import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

class SessionArchivedReadOnlyException implements Exception {
  final SessionArchivedRejection rejection;

  SessionArchivedReadOnlyException({required this.rejection});

  @override
  String toString() => "session ${rejection.sessionId} is archived and read-only";
}

/// The single archive-permanence rule in the bridge. Archiving is final, so an
/// archived session can never be unarchived, prompted, or otherwise mutated.
class ArchivedSessionValidator {
  final SessionRepository _sessionRepository;

  ArchivedSessionValidator({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  /// Throws [SessionArchivedReadOnlyException] when [sessionId] is archived.
  Future<void> requireNotArchived({required String sessionId}) async {
    final storedSession = await _sessionRepository.getStoredSession(sessionId: sessionId);
    if (storedSession?.archivedAt == null) return;
    throw SessionArchivedReadOnlyException(
      rejection: SessionArchivedRejection(
        sessionId: sessionId,
        reason: SessionArchivedReason.archivedReadOnly,
      ),
    );
  }
}
