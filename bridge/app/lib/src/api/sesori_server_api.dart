import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart" show GenerateSessionMetadataRequest, jsonDecodeMap;

import "../auth/token_refresher.dart";
import "../foundation/abortable_request_client.dart";
import "../foundation/auth_backend_url.dart";
import "models/app_client_status_response.dart";
import "models/generate_session_metadata_response.dart";

class SesoriServerApiException({
  required final String method,
  required final int statusCode,
  required final Uri uri,
}) implements Exception {
  @override
  String toString() => "SesoriServerApiException: $method $uri returned status $statusCode";
}

class SesoriServerApiResponseException({
  required final String method,
  required final Uri uri,
  required final Object innerError,
  required final StackTrace innerStackTrace,
}) implements Exception {
  @override
  String toString() => "SesoriServerApiResponseException: $method $uri returned an invalid response";
}

class SesoriServerApi({
  required String authBackendUrl,
  required final http.Client _client,
  required final Duration _requestDeadline,
  required final TokenRefresher _tokenRefresher,
  required final AbortableRequestClient _requestClient,
}) {
  static const Duration defaultRequestDeadline = Duration(seconds: 35);

  final String _authBackendUrl = normalizeAuthBackendUrl(url: authBackendUrl);

  Future<AppClientStatusResponse> getAppClientStatus({required String accessToken}) async {
    final uri = Uri.parse("$_authBackendUrl/auth/app-clients/status");
    final response = await _requestClient.send(
      client: _client,
      method: "GET",
      url: uri,
      headers: {"Authorization": "Bearer $accessToken"},
      body: null,
      deadline: _requestDeadline,
      abortSignal: null,
    );
    if (response.statusCode != 200) {
      throw SesoriServerApiException(method: "GET", statusCode: response.statusCode, uri: uri);
    }
    return AppClientStatusResponse.fromJson(jsonDecodeMap(response.body));
  }

  Future<GenerateSessionMetadataResponse> generateSessionMetadata({
    required GenerateSessionMetadataRequest request,
    required AbortSignal abortSignal,
  }) async {
    final uri = Uri.parse("$_authBackendUrl/sessions/generate-metadata");
    final token = await _getAccessTokenUnlessAborted(
      uri: uri,
      abortSignal: abortSignal,
      forceRefresh: false,
    );
    final response = await _postSessionMetadata(
      uri: uri,
      request: request,
      accessToken: token,
      abortSignal: abortSignal,
    );
    if (response.statusCode != 401) return _parseSessionMetadata(uri: uri, response: response);

    final refreshedToken = await _getAccessTokenUnlessAborted(
      uri: uri,
      abortSignal: abortSignal,
      forceRefresh: true,
    );
    final retryResponse = await _postSessionMetadata(
      uri: uri,
      request: request,
      accessToken: refreshedToken,
      abortSignal: abortSignal,
    );
    return _parseSessionMetadata(uri: uri, response: retryResponse);
  }

  Future<String> _getAccessTokenUnlessAborted({
    required Uri uri,
    required AbortSignal abortSignal,
    required bool forceRefresh,
  }) async {
    _throwIfAborted(uri: uri, abortSignal: abortSignal);
    final result = Completer<String>();
    final abortSubscription = abortSignal.aborts.listen((_) {
      if (!result.isCompleted) result.completeError(http.RequestAbortedException(uri));
    });
    if (abortSignal.isAborted && !result.isCompleted) {
      result.completeError(http.RequestAbortedException(uri));
    }

    try {
      if (!result.isCompleted) {
        final token = _tokenRefresher.getAccessToken(forceRefresh: forceRefresh);
        // Token refresh has no cancellation contract. Keep observing its late
        // completion so shutdown can stop waiting without leaking an error.
        unawaited(
          token.then<void>(
            (value) {
              if (!result.isCompleted) result.complete(value);
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!result.isCompleted) result.completeError(error, stackTrace);
            },
          ),
        );
      }
      return await result.future;
    } finally {
      await abortSubscription.cancel();
    }
  }

  Future<http.Response> _postSessionMetadata({
    required Uri uri,
    required GenerateSessionMetadataRequest request,
    required String accessToken,
    required AbortSignal abortSignal,
  }) {
    return _requestClient.send(
      client: _client,
      method: "POST",
      url: uri,
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(request.toJson()),
      deadline: _requestDeadline,
      abortSignal: abortSignal,
    );
  }

  void _throwIfAborted({required Uri uri, required AbortSignal abortSignal}) {
    if (abortSignal.isAborted) throw http.RequestAbortedException(uri);
  }

  GenerateSessionMetadataResponse _parseSessionMetadata({required Uri uri, required http.Response response}) {
    const method = "POST";
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SesoriServerApiException(method: method, statusCode: response.statusCode, uri: uri);
    }
    try {
      return GenerateSessionMetadataResponse.fromJson(jsonDecodeMap(response.body));
    } on Object catch (error, stackTrace) {
      throw SesoriServerApiResponseException(
        method: method,
        uri: uri,
        innerError: error,
        innerStackTrace: stackTrace,
      );
    }
  }
}
