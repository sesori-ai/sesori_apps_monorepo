import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/models/stored_session.dart";
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

  /// Throws [SessionArchivedReadOnlyException] when [sessionId] is archived, or
  /// when it is a descendant of an archived root. Archiving a root makes its
  /// whole conversation audit-only, and its child sessions — the background
  /// tasks surfaced on it — are only reachable through it.
  ///
  /// The archived-state reads are store-only, so this answers even when the
  /// session's plugin is stopped. An unknown session is not archived; the
  /// caller owns that 404, and receives `null` so it does not have to read the
  /// row again.
  Future<StoredSession?> requireNotArchived({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final storedSession = await _sessionRepository.getStoredSession(sessionId: sessionId);
    if (storedSession?.archivedAt != null) throw _refusal(sessionId: sessionId);
    if (storedSession?.parentSessionId == null) return storedSession;

    // Same family resolution the dispatcher already ran for this operation, so
    // the root cannot be archived concurrently underneath the check.
    final family = await _sessionRepository.resolveSessionFamily(
      sessionId: sessionId,
      operation: operation,
    );
    final root = await _sessionRepository.getStoredSession(sessionId: family.rootSessionId);
    if (root?.archivedAt != null) throw _refusal(sessionId: sessionId);
    return storedSession;
  }

  SessionArchivedReadOnlyException _refusal({required String sessionId}) {
    return SessionArchivedReadOnlyException(
      rejection: SessionArchivedRejection(
        sessionId: sessionId,
        reason: SessionArchivedReason.archivedReadOnly,
      ),
    );
  }
}
