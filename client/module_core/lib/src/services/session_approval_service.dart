import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

/// Sets how the bridge answers one session's permission requests.
@lazySingleton
class SessionApprovalService({required final SessionRepository _repository}) {
  /// Asks the bridge to answer the session's requests in [mode] and returns the
  /// acknowledged session. Picking the bridge's default clears the override,
  /// so the session follows the bridge setting again when it changes.
  ///
  /// Throws the [ApiError] when the bridge does not acknowledge the change.
  Future<Session> choose({
    required String sessionId,
    required SessionApprovalMode mode,
    required SessionApprovalMode bridgeDefault,
  }) async {
    final approvalOverride = mode == bridgeDefault ? null : mode;
    return switch (await _repository.setApprovalOverride(sessionId: sessionId, approvalOverride: approvalOverride)) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
  }
}
