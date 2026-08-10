import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/pull_request_refresh_settings_service.dart";

class GetPullRequestRefreshSettingsHandler extends GetRequestHandler<PullRequestRefreshSettingsResponse> {
  // COMPATIBILITY 2026-08-10 (v1.8.0): Released clients read this route. Remove after the minimum client uses GET /settings.
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
  }) => _settingsService.readCommittedSettings();
}
