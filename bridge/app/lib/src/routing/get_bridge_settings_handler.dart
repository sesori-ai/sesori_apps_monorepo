import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../repositories/bridge_settings_repository.dart";

class GetBridgeSettingsHandler extends GetRequestHandler<BridgeSettingsResponse> {
  GetBridgeSettingsHandler({required BridgeSettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository,
      super("/settings");

  final BridgeSettingsRepository _settingsRepository;

  @override
  Future<BridgeSettingsResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) => _settingsRepository.readCommittedResponse();
}
