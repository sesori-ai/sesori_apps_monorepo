import "package:sesori_shared/sesori_shared.dart";

import "../services/pull_request_refresh_settings_service.dart";
import "request_handler.dart";

class GetPullRequestRefreshSettingsHandler({required final PullRequestRefreshSettingsService _settingsService})
    extends GetRequestHandler<PullRequestRefreshSettingsResponse> {
  // COMPATIBILITY 2026-10-25 (v1.10.0): Apps older than v1.8.0 read the pull request refresh interval here, and it
  // no longer has any effect. Remove once public apps older than v1.8.0 are unsupported.
  this : super("/settings/pull-request-refresh");

  @override
  Future<PullRequestRefreshSettingsResponse> handle(
    RelayRequest request,
  ) => _settingsService.readCommittedSettings();
}
