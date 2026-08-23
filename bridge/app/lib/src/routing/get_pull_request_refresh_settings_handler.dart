import "package:sesori_shared/sesori_shared.dart";

import "../services/pull_request_refresh_settings_service.dart";
import "request_handler.dart";

class GetPullRequestRefreshSettingsHandler({required final PullRequestRefreshSettingsService _settingsService})
    extends GetRequestHandler<PullRequestRefreshSettingsResponse> {
  // COMPATIBILITY 2026-08-10 (v1.8.0): Released clients read this route. Remove after the minimum client uses GET /settings.
  this : super("/settings/pull-request-refresh");

  @override
  Future<PullRequestRefreshSettingsResponse> handle(
    RelayRequest request,
  ) => _settingsService.readCommittedSettings();
}
