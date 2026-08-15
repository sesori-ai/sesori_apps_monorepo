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

class SesoriServerRequestAbortSignal() {
  final StreamController<void> _controller = StreamController<void>.broadcast(sync: true);
  bool _aborted = false;

  bool get isAborted => _aborted;
  Stream<void> get aborts => _controller.stream;

  void abort() {
    if (_aborted) return;
    _aborted = true;
    _controller.add(null);
    unawaited(_controller.close());
  }
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
    required SesoriServerRequestAbortSignal abortSignal,
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

  Future<String> _getAccessTokenUnlessAborted({
    required Uri uri,
    required SesoriServerRequestAbortSignal abortSignal,
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
    required SesoriServerRequestAbortSignal abortSignal,
  }) async {
    final abortCompleter = Completer<void>();
    final deadlineTimer = Timer(_requestDeadline, () {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
    });
    final abortSubscription = abortSignal.aborts.listen((_) {
      if (!abortCompleter.isCompleted) abortCompleter.complete();
    });
    if (abortSignal.isAborted && !abortCompleter.isCompleted) abortCompleter.complete();
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
      await abortSubscription.cancel();
    }
  }

  void _throwIfAborted({required Uri uri, required SesoriServerRequestAbortSignal abortSignal}) {
    if (abortSignal.isAborted) throw http.RequestAbortedException(uri);
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
