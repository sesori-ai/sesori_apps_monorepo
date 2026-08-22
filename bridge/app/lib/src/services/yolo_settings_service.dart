import "package:sesori_shared/sesori_shared.dart";

import "../repositories/bridge_settings.dart";
import "../repositories/bridge_settings_repository.dart";
import "permission_auto_approval_service.dart";

class YoloSettingsService({
  required final BridgeSettingsRepository _bridgeSettingsRepository,
  required final PermissionAutoApprovalService _permissionAutoApprovalService,
}) {
  YoloSettingsResponse get currentSettings => _response(settings: _bridgeSettingsRepository.currentSettings);

  Future<YoloSettingsResponse> readCommittedSettings() async {
    return _response(settings: await _bridgeSettingsRepository.readCommittedSettings());
  }

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

  YoloSettingsResponse _response({required BridgeSettings settings}) {
    return YoloSettingsResponse(enabled: settings.yolo);
  }
}
