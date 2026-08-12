import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../repositories/bridge_settings_repository.dart";

class GetBridgeSettingsHandler({required BridgeSettingsRepository settingsRepository}) extends GetRequestHandler<BridgeSettingsResponse> {
  this
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
