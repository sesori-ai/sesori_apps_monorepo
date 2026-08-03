import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../bridge/routing/request_handler.dart";
import "../services/pull_request_refresh_settings_service.dart";

class PatchPullRequestRefreshSettingsHandler
    extends BodyRequestHandler<PullRequestRefreshSettingsRequest, PullRequestRefreshSettingsResponse> {
  PatchPullRequestRefreshSettingsHandler({required PullRequestRefreshSettingsService settingsService})
    : _settingsService = settingsService,
      super(
        HttpMethod.patch,
        "/settings/pull-request-refresh",
        fromJson: PullRequestRefreshSettingsRequest.fromJson,
      );

  final PullRequestRefreshSettingsService _settingsService;

  @override
  Future<PullRequestRefreshSettingsResponse> handle(
    RelayRequest request, {
    required PullRequestRefreshSettingsRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      return await _settingsService.update(request: body);
    } on PullRequestRefreshIntervalOutOfRangeException catch (error) {
      throw RelayResponse(
        id: request.id,
        status: 400,
        headers: const {"content-type": "application/json"},
        body: jsonEncode(
          PullRequestRefreshSettingsErrorResponse(
            code: PullRequestRefreshSettingsErrorCode.intervalOutOfRange,
            minimumIntervalSeconds: error.minimumIntervalSeconds,
            maximumIntervalSeconds: error.maximumIntervalSeconds,
          ).toJson(),
        ),
      );
    }
  }
}
