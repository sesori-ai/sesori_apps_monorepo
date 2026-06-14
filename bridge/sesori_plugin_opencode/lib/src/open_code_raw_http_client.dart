import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;

/// Soft deadline applied to every OpenCode REST call unless the caller passes
/// an explicit [Duration] (or `null` to opt out).
///
/// A timeout is necessary because `http.Client` (specifically `IOClient`) does
/// NOT impose a total request/response deadline by default — only optional
/// connection/idle timeouts. An OpenCode server that accepts the connection
/// and then stalls (a frequent failure mode) would otherwise hang the call
/// indefinitely. Routing every request through this client guarantees the
/// timeout (and success check) can't be forgotten on a new endpoint.
const _defaultTimeout = Duration(seconds: 30);

/// HTTP status reported when a request exceeds its timeout. 504 (Gateway
/// Timeout) is the honest code: the bridge is a gateway and the upstream
/// (OpenCode) did not respond in time. Using a real status lets phone-side
/// error handling classify it like any other upstream failure.
const _timeoutStatusCode = 504;

enum _HttpMethod { get, post, patch, delete }

/// Transport-level HTTP client for the OpenCode REST API.
///
/// Centralizes the three cross-cutting concerns every OpenCode call needs so
/// individual endpoint methods (in [OpenCodeApi]) cannot bypass them:
///   1. applies a request [timeout] (default [_defaultTimeout]),
///   2. enforces a 2xx response (throws [OpenCodeApiException] otherwise),
///   3. computes a debug endpoint label ("METHOD /path") for error messages.
///
/// It also owns Basic-auth header computation and URI construction. It performs
/// no JSON decoding or model mapping — that stays in [OpenCodeApi].
class OpenCodeRawHttpClient {
  final String _serverURL;
  final String? _password;
  final http.Client _client;

  OpenCodeRawHttpClient({
    required String serverURL,
    required String? password,
    required http.Client client,
  }) : _serverURL = serverURL,
       _password = password,
       _client = client;

  Map<String, String> get _authHeaders {
    final password = _password;
    if (password == null) return const {};
    final creds = base64.encode(utf8.encode("opencode:$password"));
    return {"Authorization": "Basic $creds"};
  }

  Future<http.Response> get({
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout = _defaultTimeout,
  }) {
    return _send(
      method: _HttpMethod.get,
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      timeout: timeout,
    );
  }

  Future<http.Response> post({
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Object? body,
    Duration? timeout = _defaultTimeout,
  }) {
    return _send(
      method: _HttpMethod.post,
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }

  Future<http.Response> patch({
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Object? body,
    Duration? timeout = _defaultTimeout,
  }) {
    return _send(
      method: _HttpMethod.patch,
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }

  Future<http.Response> delete({
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Object? body,
    Duration? timeout = _defaultTimeout,
  }) {
    return _send(
      method: _HttpMethod.delete,
      path: path,
      queryParameters: queryParameters,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }

  /// Sends [method] to [path], applying auth headers, the optional [timeout],
  /// and a 2xx success check. A `null` [timeout] means unbounded (only for
  /// genuinely long-running synchronous endpoints).
  Future<http.Response> _send({
    required _HttpMethod method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Object? body,
    required Duration? timeout,
  }) async {
    final hasQuery = queryParameters != null && queryParameters.isNotEmpty;
    final uri = Uri.parse(
      "$_serverURL$path",
    ).replace(queryParameters: hasQuery ? queryParameters : null);
    final endpoint = "${method.name.toUpperCase()} $path";
    final mergedHeaders = {..._authHeaders, ...?headers};

    final request = switch (method) {
      _HttpMethod.get => _client.get(uri, headers: mergedHeaders),
      _HttpMethod.post => _client.post(uri, headers: mergedHeaders, body: body),
      _HttpMethod.patch => _client.patch(uri, headers: mergedHeaders, body: body),
      _HttpMethod.delete => _client.delete(uri, headers: mergedHeaders, body: body),
    };

    final http.Response response;
    if (timeout == null) {
      response = await request;
    } else {
      try {
        response = await request.timeout(timeout);
      } on TimeoutException {
        throw OpenCodeApiException(
          endpoint,
          _timeoutStatusCode,
          responseBody: "request timed out after ${timeout.inSeconds}s",
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenCodeApiException(endpoint, response.statusCode, responseBody: response.body);
    }
    return response;
  }
}

class OpenCodeApiException implements Exception {
  static const _maxBodyLength = 500;

  final String endpoint;
  final int statusCode;

  /// Upstream response body, truncated to [_maxBodyLength] characters.
  /// OpenCode error bodies carry the actual failure reason (e.g.
  /// `{"name":"UnknownError","data":{...}}`), which is essential for
  /// diagnosing failures from logs.
  final String? responseBody;

  OpenCodeApiException(this.endpoint, this.statusCode, {String? responseBody})
    : responseBody = switch (responseBody) {
        null => null,
        final body when body.length > _maxBodyLength => "${body.substring(0, _maxBodyLength)}…",
        final body => body,
      };

  @override
  String toString() {
    final bodySuffix = responseBody == null || responseBody!.isEmpty ? "" : " body=$responseBody";
    return "OpenCodeApiException: $endpoint failed with status $statusCode$bodySuffix";
  }
}
