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
    final result = await api.send(userId: _userId, request: _request);

    expect(result, isA<ProductAnalyticsEventDelivered>());
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

  group("a status that won't change on a retry is a permanent failure", () {
    for (final status in [400, 401, 404, 413, 429]) {
      test("$status keeps the status and the response body", () async {
        client.error = ApiError.nonSuccessCode(errorCode: status, rawErrorString: '{"error":"bad_request"}');

        final result = await api.send(userId: _userId, request: _request);

        expect(
          result,
          ProductAnalyticsEventDeliveryResult.permanentFailure(
            description: 'HTTP $status: {"error":"bad_request"}',
            cause: null,
          ),
        );
      });
    }

    for (final body in ["", null]) {
      test("a 400 with the body ${body == null ? "missing" : "empty"} keeps only the status", () async {
        client.error = ApiError.nonSuccessCode(errorCode: 400, rawErrorString: body);

        final result = await api.send(userId: _userId, request: _request);

        expect(
          result,
          const ProductAnalyticsEventDeliveryResult.permanentFailure(description: "HTTP 400", cause: null),
        );
      });
    }
  });

  test("a 2xx body that isn't JSON is a permanent failure that omits the body", () async {
    client.error = ApiError.jsonParsing(
      jsonString: "<html>",
      innerError: const FormatException("bad", "<html>", 0),
    );

    final result = await api.send(userId: _userId, request: _request);

    expect(
      result,
      isA<ProductAnalyticsEventPermanentFailure>()
          .having((failure) => failure.description, "description", "unusable response")
          .having(
            (failure) => failure.cause.toString(),
            "cause",
            allOf(contains("offset=0"), isNot(contains("<html>"))),
          ),
    );
  });

  group("a failure that can pass is a transient failure", () {
    Matcher transientFailure({required String description, required Matcher cause, required Matcher stackTrace}) =>
        isA<ProductAnalyticsEventTransientFailure>()
            .having((failure) => failure.description, "description", description)
            .having((failure) => failure.cause, "cause", cause)
            .having((failure) => failure.stackTrace, "stackTrace", stackTrace);

    for (final status in [500, 502, 503]) {
      test("$status keeps the status and the response body", () async {
        client.error = ApiError.nonSuccessCode(errorCode: status, rawErrorString: '{"error":"internal_server_error"}');

        expect(
          await api.send(userId: _userId, request: _request),
          transientFailure(
            description: 'HTTP $status: {"error":"internal_server_error"}',
            cause: isNull,
            stackTrace: isNull,
          ),
        );
      });
    }

    test("a long response body keeps only its first 500 characters", () async {
      client.error = ApiError.nonSuccessCode(errorCode: 502, rawErrorString: "x" * 2000);

      expect(
        await api.send(userId: _userId, request: _request),
        transientFailure(description: "HTTP 502: ${"x" * 500}", cause: isNull, stackTrace: isNull),
      );
    });

    test("a network error keeps the original error", () async {
      const cause = SocketException("unreachable");
      client.error = ApiError.dartHttpClient(cause);

      expect(
        await api.send(userId: _userId, request: _request),
        transientFailure(description: "network error", cause: same(cause), stackTrace: isNull),
      );
    });

    test("a failed token refresh or changed account", () async {
      client.error = ApiError.notAuthenticated();

      expect(
        await api.send(userId: _userId, request: _request),
        transientFailure(description: "not authenticated", cause: isNull, stackTrace: isNull),
      );
    });

    test("a transport failure the HTTP client doesn't wrap keeps its error and stack trace", () async {
      const cause = HandshakeException("bad certificate");
      client.thrown = cause;

      expect(
        await api.send(userId: _userId, request: _request),
        transientFailure(description: "no response", cause: same(cause), stackTrace: isNotNull),
      );
    });

    test("an attempt still pending at its 5 second deadline", () {
      fakeAsync((async) {
        client.hang = true;
        ProductAnalyticsEventDeliveryResult? result;
        unawaited(api.send(userId: _userId, request: _request).then((value) => result = value));

        async.elapse(const Duration(seconds: 4, milliseconds: 999));
        expect(result, isNull);

        async.elapse(const Duration(milliseconds: 1));
        expect(
          result,
          transientFailure(description: "no response", cause: isA<TimeoutException>(), stackTrace: isNotNull),
        );
      });
    });
  });
}
