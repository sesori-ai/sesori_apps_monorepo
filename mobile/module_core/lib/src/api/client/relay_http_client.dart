import "dart:convert";
import "dart:math";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/relay/relay_client.dart";
import "../../capabilities/server_connection/connection_service.dart";
import "../../logging/logging.dart";

@lazySingleton
class RelayHttpApiClient {
  final ConnectionService _connectionService;
  int _requestCounter = 0;
  final Random _requestIdRandom = Random();

  RelayHttpApiClient(ConnectionService connectionService) : _connectionService = connectionService;

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> get<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final relayClient = _connectionService.relayClient;
    if (relayClient != null && relayClient.isConnected) {
      return _mapAuthErrors(
        await _sendViaRelay(
          relayClient: relayClient,
          method: HttpMethod.get,
          path: path,
          fromJson: fromJson,
          queryParameters: queryParameters,
          extraHeaders: headers,
        ),
      );
    }
    return _relayDisconnectedResponse();
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> post<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    required Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final relayClient = _connectionService.relayClient;
    if (relayClient != null && relayClient.isConnected) {
      return _mapAuthErrors(
        await _sendViaRelay(
          relayClient: relayClient,
          method: HttpMethod.post,
          path: path,
          fromJson: fromJson,
          queryParameters: queryParameters,
          body: body,
          extraHeaders: headers,
        ),
      );
    }
    return _relayDisconnectedResponse();
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> patch<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    required Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final relayClient = _connectionService.relayClient;
    if (relayClient != null && relayClient.isConnected) {
      return _mapAuthErrors(
        await _sendViaRelay(
          relayClient: relayClient,
          method: HttpMethod.patch,
          path: path,
          fromJson: fromJson,
          queryParameters: queryParameters,
          body: body,
          extraHeaders: headers,
        ),
      );
    }
    return _relayDisconnectedResponse();
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> delete<T>(
    String path, {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
    required T Function(Map<String, dynamic> json) fromJson,
    Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final relayClient = _connectionService.relayClient;
    if (relayClient != null && relayClient.isConnected) {
      return _mapAuthErrors(
        await _sendViaRelay(
          relayClient: relayClient,
          method: HttpMethod.delete,
          path: path,
          fromJson: fromJson,
          queryParameters: queryParameters,
          body: body,
          extraHeaders: headers,
        ),
      );
    }
    return _relayDisconnectedResponse();
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
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final requestId = _nextRelayRequestId();
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
        RelayRequest(
          id: requestId,
          method: method.dioName,
          path: fullPath,
          headers: headers,
          body: bodyString,
        ),
      );

      if (response.status < 200 || response.status >= 300) {
        return ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: response.status,
            rawErrorString: response.body,
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
        loge("Failed to parse relay response JSON", error, stackTrace);
        return ApiResponse.error(ApiError.jsonParsing(responseBody));
      }
    } catch (error, stackTrace) {
      loge("Relay API request failed", error, stackTrace);
      return ApiResponse.error(ApiError.generic());
    }
  }

  ApiResponse<T> _relayDisconnectedResponse<T>() {
    return ApiResponse.error(ApiError.dartHttpClient(Exception("Relay is not connected")));
  }

  String _nextRelayRequestId() {
    _requestCounter = (_requestCounter + 1) & 0xFFFF;
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final counter = _requestCounter.toRadixString(16).padLeft(4, "0");
    final random = _requestIdRandom.nextInt(0x10000).toRadixString(16).padLeft(4, "0");
    return "$timestamp-$counter$random";
  }
}
