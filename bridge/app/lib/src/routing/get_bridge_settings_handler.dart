import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../repositories/bridge_settings_repository.dart";

class GetBridgeSettingsHandler({required final BridgeSettingsRepository _settingsRepository})
    extends GetRequestHandler<BridgeSettingsResponse> {
  this : super("/settings");

  @override
  Future<BridgeSettingsResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) => _settingsRepository.readCommittedResponse();
}
