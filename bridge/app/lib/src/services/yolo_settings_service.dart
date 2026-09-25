import "package:sesori_shared/sesori_shared.dart";

import "../repositories/bridge_settings.dart";
import "../repositories/bridge_settings_repository.dart";
import "permission_auto_approval_service.dart";
import "session_mutation_dispatcher.dart";

/// Changes YOLO, for the bridge or for one session, and approves what the
/// change puts in YOLO.
class YoloSettingsService({
  required final BridgeSettingsRepository _bridgeSettingsRepository,
  required final PermissionAutoApprovalService _permissionAutoApprovalService,
  required final SessionMutationDispatcher _sessionMutationDispatcher,
}) {
  Future<YoloSettingsResponse> update({required bool enabled}) async {
    var shouldApprovePending = false;
    final committed = await _bridgeSettingsRepository.mutateSettings(
      mutation: ({required current}) {
        if (current.yolo == enabled) return current;
        shouldApprovePending = enabled;
        return current.copyWith(yolo: enabled);
      },
    );
    if (shouldApprovePending) await _permissionAutoApprovalService.approvePending();
    return _response(settings: committed);
  }

  /// Stores [sessionId]'s approval override (null follows the bridge setting)
  /// and, when the session ends up in YOLO, approves what it has pending.
  Future<Session> setSessionOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) async {
    final session = await _sessionMutationDispatcher.setApprovalOverride(
      sessionId: sessionId,
      approvalOverride: approvalOverride,
    );
    if (await _permissionAutoApprovalService.isYolo(sessionId: sessionId)) {
      await _permissionAutoApprovalService.approvePending();
    }
    return session;
  }

  YoloSettingsResponse _response({required BridgeSettings settings}) {
    return YoloSettingsResponse(enabled: settings.yolo, supportsSessionOverride: true);
  }
}
