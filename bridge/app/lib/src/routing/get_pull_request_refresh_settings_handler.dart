import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/pull_request_refresh_settings_service.dart";

class GetPullRequestRefreshSettingsHandler extends GetRequestHandler<PullRequestRefreshSettingsResponse> {
  GetPullRequestRefreshSettingsHandler({required PullRequestRefreshSettingsService settingsService})
    : _settingsService = settingsService,
      super("/settings/pull-request-refresh");

  final PullRequestRefreshSettingsService _settingsService;

  @override
  Future<PullRequestRefreshSettingsResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async => _settingsService.currentSettings;
}
