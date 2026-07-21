import "dart:async";
import "dart:convert";
import "dart:developer" as developer;
import "dart:io";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";

import "api_error.dart";
import "api_response.dart";
import "safe_api_client.dart";

/// Timeout for [HttpApiClient.getText]. The documents it fetches are static and
/// small, so a hung request is a failure, not slow progress.
const _textTimeout = Duration(seconds: 15);

@lazySingleton
class HttpApiClient implements SafeApiClient {
  final http.Client _client;

  HttpApiClient(http.Client client) : _client = client;

  /// GETs a document served as plain text (e.g. markdown) and returns the body
  /// verbatim.
  ///
  /// The JSON methods below run every body through [jsonDecode]; a text
  /// endpoint's body would fail that parse, so this one skips it. It stays off
  /// the [SafeApiClient] interface, whose contract is JSON-shaped.
  ///
  /// The deadline aborts the request rather than only abandoning its future, so
  /// a retry after a timeout does not leave the previous connection hanging.
  Future<ApiResponse<String>> getText({required Uri url}) async {
    final deadline = Completer<void>();
    final timer = Timer(_textTimeout, deadline.complete);

    try {
      final request = http.AbortableRequest("GET", url, abortTrigger: deadline.future);
      final response = await http.Response.fromStream(await _client.send(request));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: response.statusCode,
            rawErrorString: response.body,
          ),
        );
      }
      if (response.body.isEmpty) return ApiResponse.error(ApiError.emptyResponse());

      return ApiResponse.success(response.body);
    } on http.ClientException catch (e) {
      // Covers RequestAbortedException, which the deadline raises.
      return ApiResponse.error(ApiError.dartHttpClient(e));
    } on SocketException catch (e) {
      return ApiResponse.error(ApiError.dartHttpClient(e));
    } on HandshakeException catch (e) {
      return ApiResponse.error(ApiError.dartHttpClient(e));
    } finally {
      timer.cancel();
    }
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, json parsing function
  Future<ApiResponse<T>> get<T>(
    final Uri url, {
    required final T Function(dynamic json) fromJson,
    final Map<String, String>? headers,
    final ContentType? contentType,
    final bool logBody = false,
  }) {
    return _execute(
      method: HttpMethod.get,
      url: url,
      fromJson: fromJson,
      headers: headers,
      contentType: contentType,
    );
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, json parsing function
  Future<ApiResponse<T>> post<T>(
    final Uri url, {
    required final T Function(dynamic json) fromJson,
    final Map<String, String>? headers,
    required final Object? body,
    final ContentType? contentType,
    final bool logBody = false,
  }) {
    return _execute(
      method: HttpMethod.post,
      url: url,
      fromJson: fromJson,
      headers: headers,
      body: body,
      contentType: contentType,
    );
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, json parsing function
  Future<ApiResponse<T>> patch<T>(
    final Uri url, {
    required final T Function(dynamic json) fromJson,
    final Map<String, String>? headers,
    required final Object? body,
    final ContentType? contentType,
    final bool logBody = false,
  }) {
    return _execute(
      method: HttpMethod.patch,
      url: url,
      fromJson: fromJson,
      headers: headers,
      body: body,
      contentType: contentType,
    );
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, json parsing function
  Future<ApiResponse<T>> delete<T>(
    final Uri url, {
    required final T Function(dynamic json) fromJson,
    final Map<String, String>? headers,
    final ContentType? contentType,
    final bool logBody = false,
  }) {
    return _execute(
      method: HttpMethod.delete,
      url: url,
      fromJson: fromJson,
      headers: headers,
      contentType: contentType,
    );
  }

  /// Sends a multipart POST request. All [http.Client] usage stays in this layer.
  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> postMultipart<T>(
    final Uri url, {
    // ignore: no_slop_linter/prefer_specific_type, json parsing callback
    required final T Function(dynamic json) fromJson,
    required final List<http.MultipartFile> files,
    final Map<String, String>? headers,
    final Map<String, String>? fields,
    final Duration? timeout,
  }) async {
    final request = http.MultipartRequest("POST", url)
      ..headers.addAll(headers ?? {})
      ..fields.addAll(fields ?? {})
      ..files.addAll(files);

    try {
      final Future<http.StreamedResponse> sendFuture = _client.send(request);
      final streamedResponse = timeout != null ? await sendFuture.timeout(timeout) : await sendFuture;
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          // ignore: no_slop_linter/prefer_specific_type, json parsing
          return ApiResponse.success(fromJson(null));
        }
        try {
          // ignore: no_slop_linter/prefer_specific_type, json decoding
          final json = jsonDecode(response.body);
          return ApiResponse.success(fromJson(json));
        } catch (e) {
          developer.log("Failed to parse multipart response JSON", name: "sesori_auth", error: e, level: 1000);
          return ApiResponse.error(ApiError.jsonParsing(response.body));
        }
      } else {
        return ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: response.statusCode,
            rawErrorString: response.body,
          ),
        );
      }
    } on http.ClientException catch (e) {
      return ApiResponse.error(ApiError.dartHttpClient(e));
    }
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<ApiResponse<T>> _execute<T>({
    required HttpMethod method,
    required Uri url,
    // ignore: no_slop_linter/prefer_specific_type, json parsing callback
    required T Function(dynamic json) fromJson,
    Map<String, String>? headers,
    // ignore: no_slop_linter/prefer_specific_type
    Object? body,
    ContentType? contentType,
  }) async {
    final effectiveContentType = contentType ?? ContentType.json;
    final allHeaders = {
      ...?headers,
      HttpHeaders.contentTypeHeader: effectiveContentType.toString(),
    };

    try {
      final http.Response response;
      switch (method) {
        case HttpMethod.get:
          response = await _client.get(url, headers: allHeaders);
        case HttpMethod.post:
          response = await _client.post(
            url,
            headers: allHeaders,
            body: body is String ? body : jsonEncode(body),
          );
        case HttpMethod.patch:
          response = await _client.patch(
            url,
            headers: allHeaders,
            body: body is String ? body : jsonEncode(body),
          );
        case HttpMethod.delete:
          response = await _client.delete(url, headers: allHeaders);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          // ignore: no_slop_linter/prefer_specific_type, json parsing
          return ApiResponse.success(fromJson(null));
        }
        try {
          // ignore: no_slop_linter/prefer_specific_type, json decoding
          final json = jsonDecode(response.body);
          return ApiResponse.success(fromJson(json));
        } catch (e) {
          developer.log("Failed to parse response JSON", name: "sesori_auth", error: e, level: 1000);
          return ApiResponse.error(ApiError.jsonParsing(response.body));
        }
      } else {
        return ApiResponse.error(
          ApiError.nonSuccessCode(
            errorCode: response.statusCode,
            rawErrorString: response.body,
          ),
        );
      }
    } on http.ClientException catch (e) {
      return ApiResponse.error(ApiError.dartHttpClient(e));
    }
  }
}
