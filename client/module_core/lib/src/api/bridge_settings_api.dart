import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/relay/relay_client.dart";
import "client/relay_http_client.dart";

@lazySingleton
class BridgeSettingsApi({required final RelayHttpApiClient _client}) {
  Future<ApiResponse<PullRequestRefreshSettingsResponse>> getPullRequestRefreshSettings() {
    return _client.get<PullRequestRefreshSettingsResponse>(
      "/settings/pull-request-refresh",
      fromJson: PullRequestRefreshSettingsResponse.fromJson,
    );
  }

  Future<ApiResponse<BridgeSettingsResponse>> getBridgeSettings() {
    return _client.get<BridgeSettingsResponse>(
      "/settings",
      fromJson: BridgeSettingsResponse.fromJson,
    );
  }

  Future<BridgeSettingUpdateApiResult> update({required BridgeSettingUpdate update}) async {
    return switch (await _client.patch<BridgeSettingUpdate>(
      "/settings",
      body: update.toJson(),
      fromJson: BridgeSettingUpdate.fromJson,
    )) {
      SuccessResponse(:final data) => BridgeSettingUpdateApiCommitted(update: data),
      ErrorResponse(:final NonSuccessCodeError error) when error.errorCode == 400 => _mapRejection(error: error),
      ErrorResponse(:final error) => BridgeSettingUpdateApiFailure(error: error),
    };
  }

  BridgeSettingUpdateApiResult _mapRejection({required NonSuccessCodeError error}) {
    final body = error.rawErrorString;
    if (body == null) return BridgeSettingUpdateApiFailure(error: error);
    try {
      return BridgeSettingUpdateApiRejected(
        rejection: BridgeSettingUpdateRejection.fromJson(jsonDecodeMap(body)),
        error: error,
      );
    } on Object {
      return BridgeSettingUpdateApiFailure(error: error);
    }
  }
}

sealed class const BridgeSettingUpdateApiResult();

final class const BridgeSettingUpdateApiCommitted({required final BridgeSettingUpdate update})
    extends BridgeSettingUpdateApiResult;

final class const BridgeSettingUpdateApiRejected({
  required final BridgeSettingUpdateRejection rejection,
  required final NonSuccessCodeError error,
}) extends BridgeSettingUpdateApiResult;

final class const BridgeSettingUpdateApiFailure({required final ApiError error}) extends BridgeSettingUpdateApiResult {
  bool get isCommitUncertain => switch (error) {
    JsonParsingError() || EmptyResponseError() => true,
    DartHttpClientError(innerError: TimeoutException() || RelayResponseLostException()) => true,
    GenericError() || NotAuthenticatedError() || NonSuccessCodeError() || DartHttpClientError() => false,
  };
}
