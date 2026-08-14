import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart" show GenerateSessionMetadataRequest, jsonDecodeMap;

import "../auth/token_refresher.dart";
import "app_client_status_response.dart";
import "generate_session_metadata_response.dart";

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
}) {
  static const Duration defaultRequestDeadline = Duration(seconds: 35);

  final String _authBackendUrl = authBackendUrl.replaceFirst(RegExp(r"/+$"), "");

  Future<AppClientStatusResponse> getAppClientStatus({required String accessToken}) async {
    final uri = Uri.parse("$_authBackendUrl/auth/app-clients/status");
    final abortCompleter = Completer<void>();
    final deadlineTimer = Timer(_requestDeadline, abortCompleter.complete);
    final request = http.AbortableRequest("GET", uri, abortTrigger: abortCompleter.future)
      ..headers["Authorization"] = "Bearer $accessToken";

    try {
      final response = await http.Response.fromStream(await _client.send(request));
      if (response.statusCode != 200) {
        throw SesoriServerApiException(method: request.method, statusCode: response.statusCode, uri: uri);
      }
      return AppClientStatusResponse.fromJson(jsonDecodeMap(response.body));
    } finally {
      deadlineTimer.cancel();
    }
  }

  Future<GenerateSessionMetadataResponse> generateSessionMetadata({
    required GenerateSessionMetadataRequest request,
    required Future<void> shutdownSignal,
  }) async {
    final uri = Uri.parse("$_authBackendUrl/sessions/generate-metadata");
    final token = await _tokenRefresher.getAccessToken();
    final response = await _postSessionMetadata(
      uri: uri,
      request: request,
      accessToken: token,
      shutdownSignal: shutdownSignal,
    );
    if (response.statusCode != 401) return _parseSessionMetadata(uri: uri, response: response);

    final refreshedToken = await _tokenRefresher.getAccessToken(forceRefresh: true);
    final retryResponse = await _postSessionMetadata(
      uri: uri,
      request: request,
      accessToken: refreshedToken,
      shutdownSignal: shutdownSignal,
    );
    return _parseSessionMetadata(uri: uri, response: retryResponse);
  }

  Future<http.Response> _postSessionMetadata({
    required Uri uri,
    required GenerateSessionMetadataRequest request,
    required String accessToken,
    required Future<void> shutdownSignal,
  }) async {
    final abortCompleter = Completer<void>();
    final deadlineTimer = Timer(_requestDeadline, () {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
    });
    unawaited(
      shutdownSignal.then((_) {
        if (!abortCompleter.isCompleted) abortCompleter.complete();
      }),
    );
    final httpRequest = http.AbortableRequest("POST", uri, abortTrigger: abortCompleter.future)
      ..headers.addAll({
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      })
      ..body = jsonEncode(request.toJson());

    try {
      return await http.Response.fromStream(await _client.send(httpRequest));
    } finally {
      deadlineTimer.cancel();
    }
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
