import "dart:async";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "app_client_status_response.dart";

class SesoriServerApiException({required final int statusCode, required final Uri uri}) implements Exception {
  @override
  String toString() => "SesoriServerApiException: GET $uri returned status $statusCode";
}

/// Provider-level HTTP boundary for new Sesori auth-server operations.
///
/// Existing auth APIs remain in their current use-case-specific boundaries.
class SesoriServerApi({
  required String authBackendUrl,
  required final http.Client _client,
  required final Duration _requestDeadline,
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
        throw SesoriServerApiException(statusCode: response.statusCode, uri: uri);
      }
      return AppClientStatusResponse.fromJson(jsonDecodeMap(response.body));
    } finally {
      deadlineTimer.cancel();
    }
  }
}
