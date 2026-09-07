import "dart:async";
import "dart:convert";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/relay/relay_client.dart";
import "../../capabilities/relay/relay_request_id_generator.dart";
import "../../capabilities/server_connection/connection_service.dart";
import "../../logging/logging.dart";

@lazySingleton
class RelayHttpApiClient(final ConnectionService _connectionService) {
  static const Duration _defaultRequestTimeout = Duration(seconds: 30);
  static const String _sensitiveParsingErrorMarker = "Sensitive response omitted";

  final RelayRequestIdGenerator _requestIdGenerator = RelayRequestIdGenerator();

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> get<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) => _request(
    method: HttpMethod.get,
    path: path,
    fromJson: fromJson,
    queryParameters: queryParameters,
    body: null,
    extraHeaders: headers,
    timeout: _defaultRequestTimeout,
    sensitiveResponse: false,
  );

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> post<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    // ignore: no_slop_linter/prefer_specific_type
    required Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration timeout = _defaultRequestTimeout,
  }) => _request(
    method: HttpMethod.post,
    path: path,
    fromJson: fromJson,
    queryParameters: queryParameters,
    body: body,
    extraHeaders: headers,
    timeout: timeout,
    sensitiveResponse: false,
  );

  Future<ApiResponse<T>> postWithTimeout<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    // ignore: no_slop_linter/prefer_specific_type
    required Object body,
    required Duration timeout,
  }) => _request(
    method: HttpMethod.post,
    path: path,
    fromJson: fromJson,
    queryParameters: null,
    body: body,
    extraHeaders: null,
    timeout: timeout,
    sensitiveResponse: true,
  );

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> patch<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    // ignore: no_slop_linter/prefer_specific_type
    required Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) => _request(
    method: HttpMethod.patch,
    path: path,
    fromJson: fromJson,
    queryParameters: queryParameters,
    body: body,
    extraHeaders: headers,
    timeout: _defaultRequestTimeout,
    sensitiveResponse: false,
  );

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> delete<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    // ignore: no_slop_linter/prefer_specific_type
    Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) => _request(
    method: HttpMethod.delete,
    path: path,
    fromJson: fromJson,
    queryParameters: queryParameters,
    body: body,
    extraHeaders: headers,
    timeout: _defaultRequestTimeout,
    sensitiveResponse: false,
  );

  Future<ApiResponse<T>> _request<T>({
    required HttpMethod method,
    required String path,
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, String>? queryParameters,
    // ignore: no_slop_linter/prefer_specific_type
    required Object? body,
    required Map<String, String>? extraHeaders,
    required Duration timeout,
    required bool sensitiveResponse,
  }) async {
    final relayClient = _connectionService.relayClient;
    if (relayClient == null || !relayClient.isConnected) {
      return _relayDisconnectedResponse();
    }
    return _mapAuthErrors(
      await _sendViaRelay(
        relayClient: relayClient,
        method: method,
        path: path,
        fromJson: fromJson,
        queryParameters: queryParameters,
        body: body,
        extraHeaders: extraHeaders,
        timeout: timeout,
        sensitiveResponse: sensitiveResponse,
      ),
    );
  }

  ApiResponse<T> _mapAuthErrors<T>(ApiResponse<T> response) {
    if (response case ErrorResponse(error: NonSuccessCodeError(errorCode: 401))) {
      return ApiResponse.error(ApiError.notAuthenticated());
    }
    return response;
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, optional relay request shaping parameters
  Future<ApiResponse<T>> _sendViaRelay<T>({
    required RelayClient relayClient,
    required HttpMethod method,
    required String path,
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, String>? queryParameters,
    // ignore: no_slop_linter/prefer_specific_type
    Object? body,
    Map<String, String>? extraHeaders,
    required Duration timeout,
    required bool sensitiveResponse,
  }) async {
    final requestId = _requestIdGenerator();
    final fullPath = Uri(path: path, queryParameters: queryParameters).toString();
    final bodyString = body == null
        ? null
        : body is String
        ? body
        : jsonEncode(body);

    final headers = {
      ...?extraHeaders,
      if (body != null) "content-type": "application/json",
    };

    try {
      final response = await relayClient.sendRequest(
        request: RelayRequest(
          id: requestId,
          method: method.dioName,
          path: fullPath,
          headers: headers,
          body: bodyString,
        ),
        timeout: timeout,
      );

      if (response.status < 200 || response.status >= 300) {
        return ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: response.status,
            rawErrorString: sensitiveResponse ? null : response.body,
          ),
        );
      }

      final responseBody = response.body;
      if (responseBody == null || responseBody.isEmpty) {
        return ApiResponse.error(ApiError.emptyResponse());
      }

      try {
        final json = jsonDecodeMap(responseBody);
        return ApiResponse.success(fromJson(json));
      } catch (error, stackTrace) {
        if (sensitiveResponse) {
          loge(
            "Failed to parse sensitive relay response JSON (${error.runtimeType.toString()}: ${_sourceFreeErrorMessage(error)})",
            null,
            stackTrace,
          );
          return ApiResponse.error(ApiError.jsonParsing(_sensitiveParsingErrorMarker));
        }
        loge("Failed to parse relay response JSON", error, stackTrace);
        return ApiResponse.error(ApiError.jsonParsing(responseBody));
      }
    } on TimeoutException catch (error) {
      // The request may have been dispatched before the response was lost;
      // callers (e.g. plugin mutations) must be able to treat this as an
      // uncertain outcome instead of a retryable ordinary failure.
      return ApiResponse.error(ApiError.dartHttpClient(error));
    } on RelayResponseLostException catch (error) {
      return ApiResponse.error(ApiError.dartHttpClient(error));
    } catch (error, stackTrace) {
      loge("Relay API request failed", error, stackTrace);
      return ApiResponse.error(ApiError.generic());
    }
  }

  ApiResponse<T> _relayDisconnectedResponse<T>() {
    return ApiResponse.error(ApiError.dartHttpClient(Exception("Relay is not connected")));
  }

  String _sourceFreeErrorMessage(Object error) {
    if (error case FormatException(:final offset)) {
      return "Invalid JSON syntax or shape; offset=${offset?.toString() ?? 'unknown'}";
    }
    return "Response DTO conversion failed";
  }
}
