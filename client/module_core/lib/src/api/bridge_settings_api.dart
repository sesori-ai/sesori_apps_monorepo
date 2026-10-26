import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/relay/relay_client.dart";
import "client/relay_http_client.dart";

@lazySingleton
class BridgeSettingsApi({required final RelayHttpApiClient _client}) {
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
      ErrorResponse(:final error) => BridgeSettingUpdateApiFailure(error: error),
    };
  }
}

sealed class const BridgeSettingUpdateApiResult();

final class const BridgeSettingUpdateApiCommitted({required final BridgeSettingUpdate update})
    extends BridgeSettingUpdateApiResult;

final class const BridgeSettingUpdateApiFailure({required final ApiError error}) extends BridgeSettingUpdateApiResult {
  bool get isCommitUncertain => switch (error) {
    JsonParsingError() || EmptyResponseError() => true,
    DartHttpClientError(innerError: TimeoutException() || RelayResponseLostException()) => true,
    GenericError() || NotAuthenticatedError() || NonSuccessCodeError() || DartHttpClientError() => false,
  };
}
