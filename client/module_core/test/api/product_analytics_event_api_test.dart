import "dart:async";
import "dart:convert";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

const _userId = "user-a";

const _request = ProductAnalyticsEventRequest(
  schemaVersion: ProductAnalyticsEventSchemaVersion.v1,
  platform: ProductAnalyticsEventPlatform.macos,
  appVersion: "1.11.0",
  name: "session_message_sent",
  occurredAtMicros: 1793232000000000,
  params: {"submission_kind": "text", "input_mode": "typed"},
);

class _RecordingAuthenticatedClient() extends Mock implements AuthenticatedHttpApiClient {
  ApiError? error;
  Object? thrown;
  bool hang = false;
  Uri? lastUrl;
  String? lastUserId;
  String? lastBody;

  @override
  // ignore: no_slop_linter/prefer_specific_type, inherited JSON callback
  Future<ApiResponse<T>> postForUser<T>({
    required Uri url,
    required String userId,
    required T Function(dynamic json) fromJson,
    required String body,
  }) async {
    lastUrl = url;
    lastUserId = userId;
    lastBody = body;
    if (hang) return await Completer<ApiResponse<T>>().future;
    final thrown = this.thrown;
    if (thrown != null) throw thrown;
    final error = this.error;
    if (error != null) return ApiResponse.error(error);
    // A 204 has an empty body, which HttpApiClient hands to fromJson as null.
    return ApiResponse.success(fromJson(null));
  }
}

void main() {
  late _RecordingAuthenticatedClient client;
  late ProductAnalyticsEventApi api;

  setUp(() {
    client = _RecordingAuthenticatedClient();
    api = ProductAnalyticsEventApi(client: client);
  });

  test("posts the pinned contract's exact body to the pinned URL for the given account", () async {
    final response = await api.send(userId: _userId, request: _request);

    expect(response, isA<SuccessResponse<bool>>());
    expect(client.lastUrl, Uri.parse("https://api.sesori.com/product-analytics/events"));
    expect(client.lastUserId, _userId);
    expect(jsonDecode(client.lastBody ?? ""), {
      "schemaVersion": 1,
      "platform": "MACOS",
      "appVersion": "1.11.0",
      "name": "session_message_sent",
      "occurredAtMicros": 1793232000000000,
      "params": {"submission_kind": "text", "input_mode": "typed"},
    });
  });

  test("keeps empty params as a required empty object", () async {
    await api.send(
      userId: _userId,
      request: _request.copyWith(name: "session_abort_succeeded", params: const {}),
    );

    expect(jsonDecode(client.lastBody ?? ""), containsPair("params", <String, String>{}));
  });

  test("names each OS in uppercase", () {
    expect(ProductAnalyticsEventPlatform.values.map((platform) => platform.wireValue), ["MACOS", "LINUX", "WINDOWS"]);
  });

  test("hands back an error response as it is", () async {
    final error = ApiError.nonSuccessCode(errorCode: 503, rawErrorString: "unavailable");
    client.error = error;

    final response = await api.send(userId: _userId, request: _request);

    expect(response, isA<ErrorResponse<bool>>().having((response) => response.error, "error", same(error)));
  });

  test("lets a failure the HTTP client doesn't wrap through", () async {
    const cause = HandshakeException("bad certificate");
    client.thrown = cause;

    await expectLater(api.send(userId: _userId, request: _request), throwsA(same(cause)));
  });

  test("throws at the attempt's 5 second deadline, not before", () {
    fakeAsync((async) {
      client.hang = true;
      Object? thrown;
      unawaited(
        api.send(userId: _userId, request: _request).catchError((Object error) {
          thrown = error;
          return ApiResponse<bool>.success(true);
        }),
      );

      async.elapse(const Duration(seconds: 4, milliseconds: 999));
      expect(thrown, isNull);

      async.elapse(const Duration(milliseconds: 1));
      expect(thrown, isA<TimeoutException>());
    });
  });
}
