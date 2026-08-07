import "package:sesori_shared/sesori_shared.dart";

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
  /// Matches the ancestry bound [SessionRepository.resolveSessionFamily] uses.
  static const _maxAncestryDepth = 256;

  final SessionRepository _sessionRepository;

  ArchivedSessionValidator({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  /// Throws [SessionArchivedReadOnlyException] when [sessionId] or any of its
  /// ancestors is archived. Archiving a session makes its whole conversation
  /// audit-only: its descendants — the background tasks surfaced on it — are
  /// only reachable through it.
  ///
  /// The archived-state reads are store-only, so this answers even when the
  /// session's plugin is stopped. An unknown session is not archived; the
  /// caller owns that 404, and receives `null` so it does not have to read the
  /// row again.
  Future<StoredSession?> requireNotArchived({required String sessionId}) async {
    final storedSession = await _sessionRepository.getStoredSession(sessionId: sessionId);

    final visited = <String>{};
    var current = storedSession;
    for (var depth = 0; current != null && depth < _maxAncestryDepth; depth++) {
      if (current.archivedAt != null) {
        throw SessionArchivedReadOnlyException(
          rejection: SessionArchivedRejection(
            sessionId: sessionId,
            reason: SessionArchivedReason.archivedReadOnly,
          ),
        );
      }
      final parentSessionId = current.parentSessionId;
      // A cycle cannot reach an archived ancestor the walk has not already
      // seen, so stopping here refuses nothing a full walk would refuse.
      if (parentSessionId == null || !visited.add(current.id)) break;
      current = await _sessionRepository.getStoredSession(sessionId: parentSessionId);
    }

    return storedSession;
  }
}
