import "package:sesori_shared/sesori_shared.dart";

import "../repositories/bridge_settings.dart";
import "../repositories/bridge_settings_repository.dart";

class YoloSettingsService {
  YoloSettingsService({required BridgeSettingsRepository bridgeSettingsRepository})
    : _bridgeSettingsRepository = bridgeSettingsRepository;

  final BridgeSettingsRepository _bridgeSettingsRepository;

  YoloSettingsResponse get currentSettings => _response(settings: _bridgeSettingsRepository.currentSettings);

  Future<YoloSettingsResponse> readCommittedSettings() async {
    return _response(settings: await _bridgeSettingsRepository.readCommittedSettings());
  }

  Stream<YoloSettingsResponse> get changes => _bridgeSettingsRepository.settingsChanges
      .where((change) => change.previous.yolo != change.current.yolo)
      .map((change) => _response(settings: change.current));

  Future<YoloSettingsResponse> update({required bool enabled}) async {
    final committed = await _bridgeSettingsRepository.mutateSettings(
      mutation: ({required current}) => current.yolo == enabled ? current : current.copyWith(yolo: enabled),
    );
    return _response(settings: committed);
  }

  YoloSettingsResponse _response({required BridgeSettings settings}) {
    return YoloSettingsResponse(enabled: settings.yolo);
  }
}
