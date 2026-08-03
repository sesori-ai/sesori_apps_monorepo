import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/pull_request_refresh_settings_api.dart";
import "../capabilities/relay/relay_client.dart";
import "models/pull_request_refresh_settings_result.dart";

@lazySingleton
class PullRequestRefreshSettingsRepository {
  PullRequestRefreshSettingsRepository({required PullRequestRefreshSettingsApi api}) : _api = api;

  final PullRequestRefreshSettingsApi _api;

  Future<PullRequestRefreshSettingsLoadResult> load() async {
    return switch (await _api.getSettings()) {
      SuccessResponse(:final data) => PullRequestRefreshSettingsLoadSupported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const PullRequestRefreshSettingsLoadUnsupported(),
      ErrorResponse(:final error) => PullRequestRefreshSettingsLoadFailure(error: error),
    };
  }

  Future<PullRequestRefreshSettingsMutationResult> update({
    required PullRequestRefreshSettingsRequest request,
  }) async {
    return switch (await _api.updateSettings(request: request)) {
      SuccessResponse(:final data) => PullRequestRefreshSettingsMutationCommitted(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) =>
        const PullRequestRefreshSettingsMutationUnsupported(),
      ErrorResponse(error: final NonSuccessCodeError error) when error.errorCode == 400 => _mapBadRequest(error: error),
      ErrorResponse(error: final error) when _isUncertain(error: error) =>
        const PullRequestRefreshSettingsMutationUncertain(),
      ErrorResponse(:final error) => PullRequestRefreshSettingsMutationFailure(error: error),
    };
  }

  PullRequestRefreshSettingsMutationResult _mapBadRequest({required NonSuccessCodeError error}) {
    final body = error.rawErrorString;
    if (body != null) {
      try {
        final response = PullRequestRefreshSettingsErrorResponse.fromJson(jsonDecodeMap(body));
        if (response.code == PullRequestRefreshSettingsErrorCode.intervalOutOfRange) {
          return PullRequestRefreshSettingsMutationRejected(error: response);
        }
      } on Object {
        // The explicit typed failure below is the observable outcome.
      }
    }
    return PullRequestRefreshSettingsMutationFailure(error: error);
  }
}

bool _isUncertain({required ApiError error}) => switch (error) {
  JsonParsingError() || EmptyResponseError() => true,
  DartHttpClientError(innerError: TimeoutException() || RelayResponseLostException()) => true,
  GenericError() || NotAuthenticatedError() || NonSuccessCodeError() || DartHttpClientError() => false,
};
