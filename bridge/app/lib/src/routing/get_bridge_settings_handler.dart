import "package:sesori_shared/sesori_shared.dart";

import "../repositories/bridge_settings_repository.dart";
import "request_handler.dart";

class GetBridgeSettingsHandler({required final BridgeSettingsRepository _settingsRepository})
    extends GetRequestHandler<BridgeSettingsResponse> {
  this : super(path: "/settings");

  @override
  Future<BridgeSettingsResponse> handle({
    required RelayRequest request,
  }) => _settingsRepository.readCommittedResponse();
}
