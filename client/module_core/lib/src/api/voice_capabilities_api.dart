import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "models/voice_capabilities_api_model.dart";

const _capabilitiesTimeout = Duration(seconds: 5);

/// HTTP boundary for the public realtime voice capability endpoint.
@lazySingleton
class VoiceCapabilitiesApi({required final HttpApiClient client}) {
  final HttpApiClient _client = client;

  Future<ApiResponse<VoiceCapabilitiesApiModel>> discover() async {
    try {
      return await _client
          .get(
            Uri.parse("$authBaseUrl/voice/capabilities"),
            fromJson: VoiceCapabilitiesApiModel.parse,
          )
          .timeout(_capabilitiesTimeout);
    } on TimeoutException catch (error) {
      return ApiResponse.error(ApiError.dartHttpClient(error));
    } on FormatException catch (error) {
      return ApiResponse.error(ApiError.jsonParsing(error.message));
    }
  }
}
