import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

/// Cancels the wake-ups agents set for a session. Only the bridge's answer
/// changes the session's wake-ups.
@lazySingleton
class SessionWakeUpService({required final SessionRepository _repository}) {
  /// The session after the bridge cancelled [wakeUpId], or after it found the
  /// wake-up already gone.
  Future<Session> cancel({required String sessionId, required String wakeUpId}) async {
    return switch (await _repository.cancelWakeUp(sessionId: sessionId, wakeUpId: wakeUpId)) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
  }
}
