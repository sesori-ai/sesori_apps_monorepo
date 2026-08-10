import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/yolo_settings_service.dart";

class GetYoloSettingsHandler extends GetRequestHandler<YoloSettingsResponse> {
  GetYoloSettingsHandler({required YoloSettingsService settingsService})
    : _settingsService = settingsService,
      super("/settings/yolo");

  final YoloSettingsService _settingsService;

  @override
  Future<YoloSettingsResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) => _settingsService.readCommittedSettings();
}
