import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

final class const SessionAutoContinuationUnavailableException({required final ApiError innerError}) implements Exception;

/// Only a bridge acknowledgement changes the session's continuation preference.
@lazySingleton
class SessionAutoContinuationService({required final SessionRepository _repository}) {
  Future<Session> setEnabled({required String sessionId, required bool enabled}) async {
    return switch (await _repository.setAutoContinuation(sessionId: sessionId, enabled: enabled)) {
      SuccessResponse(:final data) => data,
      ErrorResponse(error: final NonSuccessCodeError error) when error.errorCode == 501 =>
        throw SessionAutoContinuationUnavailableException(innerError: error),
      // COMPATIBILITY 2026-09-24 (v1.9.0): Published bridges without the route
      // return 404/405. Remove when those bridges are unsupported.
      ErrorResponse(error: final NonSuccessCodeError error) when error.errorCode == 404 || error.errorCode == 405 =>
        throw SessionAutoContinuationUnavailableException(innerError: error),
      ErrorResponse(:final error) => throw error,
    };
  }
}
