import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart"
    show GenerateSessionMetadataRequest, ProjectGlossaryWordsRequest, isValidProjectGlossaryKey, jsonDecodeMap;

import "../auth/token_refresher.dart";
import "../foundation/abortable_request.dart";
import "../foundation/auth_backend_url.dart";
import "models/app_client_status_response.dart";
import "models/generate_session_metadata_response.dart";
import "models/project_glossary_response.dart";

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

  final String _authBackendUrl = normalizeAuthBackendUrl(url: authBackendUrl);

  Future<AppClientStatusResponse> getAppClientStatus({required String accessToken}) async {
    final uri = Uri.parse("$_authBackendUrl/auth/app-clients/status");
    final response = await sendAbortableRequest(
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

  Future<ProjectGlossaryWordsResponse> getProjectGlossary({
    required String projectKey,
    required AbortSignal abortSignal,
  }) async {
    _requireProjectGlossaryKey(projectKey: projectKey);
    final uri = Uri.parse("$_authBackendUrl/voice/glossary").replace(
      queryParameters: {"projectKey": projectKey},
    );
    final response = await _sendProjectGlossaryRequest(
      method: "GET",
      uri: uri,
      body: null,
      abortSignal: abortSignal,
    );
    return _parseProjectGlossaryResponse<ProjectGlossaryWordsResponse>(
      method: "GET",
      uri: uri,
      response: response,
      fromJson: ProjectGlossaryWordsResponse.fromJson,
    );
  }

  Future<ProjectGlossaryAddedWordsResponse> addProjectGlossaryWords({
    required ProjectGlossaryWordsRequest request,
    required AbortSignal abortSignal,
  }) async {
    _requireProjectGlossaryKey(projectKey: request.projectKey);
    final uri = Uri.parse("$_authBackendUrl/voice/glossary");
    final response = await _sendProjectGlossaryRequest(
      method: "POST",
      uri: uri,
      body: jsonEncode(request.toJson()),
      abortSignal: abortSignal,
    );
    return _parseProjectGlossaryResponse<ProjectGlossaryAddedWordsResponse>(
      method: "POST",
      uri: uri,
      response: response,
      fromJson: ProjectGlossaryAddedWordsResponse.fromJson,
    );
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
    return sendAbortableRequest(
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

  Future<http.Response> _sendProjectGlossaryRequest({
    required String method,
    required Uri uri,
    required String? body,
    required AbortSignal abortSignal,
  }) async {
    final response = await _sendProjectGlossaryAttempt(
      method: method,
      uri: uri,
      body: body,
      forceRefresh: false,
      abortSignal: abortSignal,
    );
    if (response.statusCode != 401) return response;

    return await _sendProjectGlossaryAttempt(
      method: method,
      uri: uri,
      body: body,
      forceRefresh: true,
      abortSignal: abortSignal,
    );
  }

  Future<http.Response> _sendProjectGlossaryAttempt({
    required String method,
    required Uri uri,
    required String? body,
    required bool forceRefresh,
    required AbortSignal abortSignal,
  }) async {
    final accessToken = await _getAccessTokenUnlessAborted(
      uri: uri,
      abortSignal: abortSignal,
      forceRefresh: forceRefresh,
    );
    return await sendAbortableRequest(
      client: _client,
      method: method,
      url: uri,
      headers: {
        "Authorization": "Bearer $accessToken",
        if (body != null) "Content-Type": "application/json",
      },
      body: body,
      deadline: _requestDeadline,
      abortSignal: abortSignal,
    );
  }

  void _requireProjectGlossaryKey({required String projectKey}) {
    if (!isValidProjectGlossaryKey(value: projectKey)) {
      throw ArgumentError.value(projectKey, "projectKey", "Expected opaque project glossary key");
    }
  }

  T _parseProjectGlossaryResponse<T>({
    required String method,
    required Uri uri,
    required http.Response response,
    required T Function(Map<String, dynamic> json) fromJson,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SesoriServerApiException(method: method, statusCode: response.statusCode, uri: uri);
    }
    try {
      return fromJson(jsonDecodeMap(response.body));
    } on Object catch (error, stackTrace) {
      throw SesoriServerApiResponseException(
        method: method,
        uri: uri,
        innerError: error,
        innerStackTrace: stackTrace,
      );
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
