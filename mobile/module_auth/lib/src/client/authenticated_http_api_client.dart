import "dart:io";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";

import "../auth_manager.dart";
import "api_error.dart";
import "api_response.dart";
import "http_api_client.dart";
import "safe_api_client.dart";

/// Decorates [HttpApiClient] with bearer-token injection and one-time retry on 401.
@lazySingleton
class AuthenticatedHttpApiClient implements SafeApiClient {
  final HttpApiClient _client;
  final AuthManager _authManager;

  AuthenticatedHttpApiClient(
    HttpApiClient client,
    AuthManager authManager,
  ) : _client = client,
      _authManager = authManager;

  @override
  // ignore: no_slop_linter/prefer_specific_type, json parsing callback
  Future<ApiResponse<T>> get<T>(
    Uri url, {
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    ContentType? contentType,
    bool logBody = false,
  }) {
    return _withAuth(
      makeRequest: (token) => _client.get(
        url,
        fromJson: fromJson,
        headers: _withAuthHeader(headers, token: token),
        contentType: contentType,
        logBody: logBody,
      ),
    );
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, json parsing callback
  Future<ApiResponse<T>> post<T>(
    Uri url, {
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    required Object? body,
    ContentType? contentType,
    bool logBody = false,
  }) {
    return _withAuth(
      makeRequest: (token) => _client.post(
        url,
        fromJson: fromJson,
        headers: _withAuthHeader(headers, token: token),
        body: body,
        contentType: contentType,
        logBody: logBody,
      ),
    );
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, json parsing callback
  Future<ApiResponse<T>> patch<T>(
    Uri url, {
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    required Object? body,
    ContentType? contentType,
    bool logBody = false,
  }) {
    return _withAuth(
      makeRequest: (token) => _client.patch(
        url,
        fromJson: fromJson,
        headers: _withAuthHeader(headers, token: token),
        body: body,
        contentType: contentType,
        logBody: logBody,
      ),
    );
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, json parsing callback
  Future<ApiResponse<T>> delete<T>(
    Uri url, {
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    ContentType? contentType,
    bool logBody = false,
  }) {
    return _withAuth(
      makeRequest: (token) => _client.delete(
        url,
        fromJson: fromJson,
        headers: _withAuthHeader(headers, token: token),
        contentType: contentType,
        logBody: logBody,
      ),
    );
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> postMultipart<T>(
    Uri url, {
    // ignore: no_slop_linter/prefer_specific_type, json parsing callback
    required T Function(dynamic json) fromJson,
    required Future<List<http.MultipartFile>> Function() createFiles,
    Map<String, String>? headers,
    Map<String, String>? fields,
    Duration? timeout,
  }) {
    return _withAuth(
      makeRequest: (token) async {
        final files = await createFiles();
        return _client.postMultipart(
          url,
          fromJson: fromJson,
          files: files,
          headers: _withAuthHeader(headers, token: token),
          fields: fields,
          timeout: timeout,
        );
      },
    );
  }

  Future<ApiResponse<T>> _withAuth<T>({
    required Future<ApiResponse<T>> Function(String token) makeRequest,
  }) async {
    final token = await _authManager.getFreshAccessToken();
    if (token == null) {
      return ApiResponse.error(ApiError.notAuthenticated());
    }

    final response = await makeRequest(token);
    if (response case ErrorResponse<T>(error: NonSuccessCodeError(errorCode: 401))) {
      final refreshedToken = await _authManager.getFreshAccessToken(forceRefresh: true);
      if (refreshedToken == null) {
        return response;
      }
      return makeRequest(refreshedToken);
    }

    return response;
  }

  Map<String, String> _withAuthHeader(Map<String, String>? headers, {required String token}) => {
    ...?headers,
    "Authorization": "Bearer $token",
  };
}
