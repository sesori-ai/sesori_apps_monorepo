import "dart:async";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "app_client_status_response.dart";

class SesoriServerApiException implements Exception {
  SesoriServerApiException({required this.statusCode, required this.uri});

  final int statusCode;
  final Uri uri;

  @override
  String toString() => "SesoriServerApiException: GET $uri returned status $statusCode";
}

/// Provider-level HTTP boundary for new Sesori auth-server operations.
///
/// Existing auth APIs remain in their current use-case-specific boundaries.
class SesoriServerApi {
  SesoriServerApi({
    required String authBackendUrl,
    required http.Client client,
    required Duration requestDeadline,
  }) : _authBackendUrl = authBackendUrl.replaceFirst(RegExp(r"/+$"), ""),
       _client = client,
       _requestDeadline = requestDeadline;

  static const Duration defaultRequestDeadline = Duration(seconds: 35);

  final String _authBackendUrl;
  final http.Client _client;
  final Duration _requestDeadline;

  Future<AppClientStatusResponse> getAppClientStatus({
    required String accessToken,
    required bool wait,
  }) async {
    final endpoint = Uri.parse("$_authBackendUrl/auth/app-clients/status");
    final uri = wait ? endpoint.replace(queryParameters: const {"wait": "true"}) : endpoint;
    final abortCompleter = Completer<void>();
    final deadlineTimer = Timer(_requestDeadline, abortCompleter.complete);
    final request = http.AbortableRequest("GET", uri, abortTrigger: abortCompleter.future)
      ..headers["Authorization"] = "Bearer $accessToken";

    try {
      final response = await http.Response.fromStream(await _client.send(request));
      if (response.statusCode != 200) {
        throw SesoriServerApiException(statusCode: response.statusCode, uri: uri);
      }
      return AppClientStatusResponse.fromJson(jsonDecodeMap(response.body));
    } finally {
      deadlineTimer.cancel();
    }
  }
}
