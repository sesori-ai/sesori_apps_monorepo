import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

/// The bridge has no route to cancel wake-ups: it predates them, so it never
/// sent one.
final class const SessionWakeUpCancelUnavailableException({required final ApiError innerError}) implements Exception;

/// Cancels the wake-ups agents set for a session. Only the bridge's answer
/// changes the session's wake-ups.
@lazySingleton
class SessionWakeUpService({required final SessionRepository _repository}) {
  /// The session after the bridge cancelled [wakeUpId], or after it found the
  /// wake-up already gone.
  Future<Session> cancel({required String sessionId, required String wakeUpId}) async {
    return switch (await _repository.cancelWakeUp(sessionId: sessionId, wakeUpId: wakeUpId)) {
      SuccessResponse(:final data) => data,
      // COMPATIBILITY 2026-11-24 (v1.16.0): bridges before wake-ups answer with
      // the router's route-not-found 404. Remove once no supported bridge
      // predates the route.
      ErrorResponse(:final NonSuccessCodeError error)
          when error.errorCode == 404 && (error.rawErrorString?.startsWith("no handler found for ") ?? false) =>
        throw SessionWakeUpCancelUnavailableException(innerError: error),
      ErrorResponse(:final error) => throw error,
    };
  }
}
