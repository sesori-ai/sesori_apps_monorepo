import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

const String oauthSessionTokenHeader = "X-Sesori-Session-Token";

Uri _buildUri({required String base, required String path}) {
  final b = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
  return Uri.parse("$b/$path");
}

class LoginOAuthApi {
  final String authBackendUrl;
  final http.Client _client;
  final AuthClientType _clientType;
  final DeviceInfo _device;

  LoginOAuthApi({
    required this.authBackendUrl,
    required http.Client client,
    required AuthClientType clientType,
    required DeviceInfo device,
  }) : _client = client,
       _clientType = clientType,
       _device = device;

  Future<AuthInitResponse> initOAuthSession({
    required OAuthProvider provider,
    required String sessionToken,
    required DateTime deadline,
    required Duration requestTimeout,
  }) async {
    final uri = _buildUri(base: authBackendUrl, path: "${provider.apiAuthPath}/init");
    final response = await _sendOAuthRequest(
      method: "POST",
      uri: uri,
      headers: {
        "Content-Type": "application/json",
        oauthSessionTokenHeader: sessionToken,
      },
      body: jsonEncode(AuthInitRequest(clientType: _clientType, device: _device).toJson()),
      requestTimeout: requestTimeout,
    );

    if (response.statusCode == 503) {
      throw OAuthSessionRestartRequiredException(
        restartAfter: _parseRestartAfter(value: response.headers["retry-after"]),
        deadline: deadline,
        operation: OAuthSessionRestartOperation.init,
        reason: OAuthSessionRestartReason.serviceUnavailable,
      );
    }

    if (response.statusCode != 200) {
      throw Exception("init ${provider.label} auth failed: status ${response.statusCode}");
    }

    final AuthInitResponse initResp;
    try {
      initResp = AuthInitResponse.fromJson(jsonDecodeMap(response.body));
    } on Object catch (e) {
      throw Exception("auth init response malformed: $e");
    }

    if (initResp.authUrl.isEmpty || initResp.state.isEmpty) {
      throw Exception("auth init response missing authUrl/state");
    }

    return initResp;
  }

  Future<AuthSessionStatusResponse> getOAuthSessionStatus({
    required String sessionToken,
    required DateTime deadline,
    required Duration requestTimeout,
  }) async {
    final uri = _buildUri(base: authBackendUrl, path: "auth/session/status");
    final response = await _sendOAuthRequest(
      method: "GET",
      uri: uri,
      headers: {oauthSessionTokenHeader: sessionToken},
      body: null,
      requestTimeout: requestTimeout,
    );

    if (response.statusCode == 503 || response.statusCode == 404) {
      final restartAfter = response.statusCode == 404
          ? Duration.zero
          : _parseRestartAfter(value: response.headers["retry-after"]);
      throw OAuthSessionRestartRequiredException(
        restartAfter: restartAfter,
        deadline: deadline,
        operation: OAuthSessionRestartOperation.status,
        reason: response.statusCode == 404
            ? OAuthSessionRestartReason.sessionMissing
            : OAuthSessionRestartReason.serviceUnavailable,
      );
    }

    if (response.statusCode == 200 || response.statusCode == 410) {
      return AuthSessionStatusResponse.fromJson(jsonDecodeMap(response.body));
    }

    throw Exception("auth session status failed: status ${response.statusCode}");
  }

  Duration _parseRestartAfter({required String? value}) {
    final seconds = value != null && RegExp(r"^[0-9]+$").hasMatch(value) ? int.tryParse(value) : null;
    return Duration(seconds: seconds != null && seconds <= 5 ? seconds : 1);
  }

  Future<http.Response> _sendOAuthRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String? body,
    required Duration requestTimeout,
  }) async {
    final abortCompleter = Completer<void>();
    final timeoutTimer = Timer(requestTimeout, abortCompleter.complete);

    try {
      final request = http.AbortableRequest(method, uri, abortTrigger: abortCompleter.future)..headers.addAll(headers);
      if (body != null) {
        request.body = body;
      }
      return await http.Response.fromStream(await _client.send(request));
    } on http.RequestAbortedException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        _OAuthRequestTimeoutException(requestTimeout: requestTimeout, cause: error),
        stackTrace,
      );
    } finally {
      timeoutTimer.cancel();
    }
  }

  Future<void> ackOAuthSessionCompletion({required String sessionToken}) async {
    final uri = _buildUri(base: authBackendUrl, path: "auth/session/status/ack");
    final response = await _client.post(
      uri,
      headers: {oauthSessionTokenHeader: sessionToken},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("auth session ACK failed: status ${response.statusCode}");
    }
  }
}

final class _OAuthRequestTimeoutException extends TimeoutException {
  _OAuthRequestTimeoutException({
    required Duration requestTimeout,
    required this.cause,
  }) : super("OAuth request timed out", requestTimeout);

  final http.RequestAbortedException cause;
}
