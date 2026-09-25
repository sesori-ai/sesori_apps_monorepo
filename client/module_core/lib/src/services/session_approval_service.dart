import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

/// Sets how the bridge answers one session's permission requests.
@lazySingleton
class SessionApprovalService({required final SessionRepository _repository}) {
  /// Stores [approvalOverride] for the session (null follows the bridge
  /// setting) and returns the acknowledged session.
  ///
  /// Throws the [ApiError] when the bridge does not acknowledge the change.
  Future<Session> setOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) async {
    return switch (await _repository.setApprovalOverride(sessionId: sessionId, approvalOverride: approvalOverride)) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
  }
}
