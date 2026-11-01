import "dart:async";
import "dart:io";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _FakeEventApi() implements ProductAnalyticsEventApi {
  final List<({String userId, ProductAnalyticsEventRequest request})> sent = [];
  ApiError? error;
  Object? thrown;

  @override
  Future<ApiResponse<bool>> send({required String userId, required ProductAnalyticsEventRequest request}) async {
    sent.add((userId: userId, request: request));
    final thrown = this.thrown;
    if (thrown != null) throw thrown;
    final error = this.error;
    return error == null ? ApiResponse.success(true) : ApiResponse.error(error);
  }
}

void main() {
  late _FakeEventApi api;

  setUp(() => api = _FakeEventApi());

  Future<ProductAnalyticsEventDeliveryResult> send() => ProductAnalyticsEventRepository(api: api).send(
    userId: "user-a",
    platform: ProductAnalyticsEventPlatform.linux,
    appVersion: "1.11.0",
    envelope: ProductAnalyticsEnvelope(
      event: const ProductAnalyticsEvent.sessionQuestionAnswered(),
      occurredAtUtc: DateTime.fromMicrosecondsSinceEpoch(1793232000000000, isUtc: true),
    ),
    params: const {"key": "value"},
  );

  test("maps the envelope onto the request, and a success to delivered", () async {
    expect(await send(), const ProductAnalyticsEventDeliveryResult.delivered());

    final attempt = api.sent.single;
    expect(attempt.userId, "user-a");
    expect(attempt.request.toJson(), {
      "schemaVersion": 1,
      "platform": "LINUX",
      "appVersion": "1.11.0",
      "name": "session_question_answered",
      "occurredAtMicros": 1793232000000000,
      "params": {"key": "value"},
    });
  });

  group("a status that won't change on a retry is a permanent failure", () {
    for (final status in [400, 401, 404, 413, 429]) {
      test("$status keeps the status and the response body", () async {
        api.error = ApiError.nonSuccessCode(errorCode: status, rawErrorString: '{"error":"bad_request"}');

        expect(
          await send(),
          ProductAnalyticsEventDeliveryResult.permanentFailure(
            description: 'HTTP $status: {"error":"bad_request"}',
            cause: null,
          ),
        );
      });
    }

    for (final body in ["", null]) {
      test("a 400 with the body ${body == null ? "missing" : "empty"} keeps only the status", () async {
        api.error = ApiError.nonSuccessCode(errorCode: 400, rawErrorString: body);

        expect(
          await send(),
          const ProductAnalyticsEventDeliveryResult.permanentFailure(description: "HTTP 400", cause: null),
        );
      });
    }
  });

  test("a 2xx body that isn't JSON is a permanent failure that omits the body", () async {
    api.error = ApiError.jsonParsing(
      jsonString: "<html>",
      innerError: const FormatException("bad", "<html>", 0),
    );

    expect(
      await send(),
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
        api.error = ApiError.nonSuccessCode(errorCode: status, rawErrorString: '{"error":"internal_server_error"}');

        expect(
          await send(),
          transientFailure(
            description: 'HTTP $status: {"error":"internal_server_error"}',
            cause: isNull,
            stackTrace: isNull,
          ),
        );
      });
    }

    test("a long response body keeps only its first 500 characters", () async {
      api.error = ApiError.nonSuccessCode(errorCode: 502, rawErrorString: "x" * 2000);

      expect(
        await send(),
        transientFailure(description: "HTTP 502: ${"x" * 500}", cause: isNull, stackTrace: isNull),
      );
    });

    test("a network error keeps the original error", () async {
      const cause = SocketException("unreachable");
      api.error = ApiError.dartHttpClient(cause);

      expect(
        await send(),
        transientFailure(description: "network error", cause: same(cause), stackTrace: isNull),
      );
    });

    test("a failed token refresh or changed account", () async {
      api.error = ApiError.notAuthenticated();

      expect(
        await send(),
        transientFailure(description: "not authenticated", cause: isNull, stackTrace: isNull),
      );
    });

    test("a transport failure the HTTP client doesn't wrap keeps its error and stack trace", () async {
      const cause = HandshakeException("bad certificate");
      api.thrown = cause;

      expect(
        await send(),
        transientFailure(description: "no response", cause: same(cause), stackTrace: isNotNull),
      );
    });

    test("the API's deadline", () async {
      api.thrown = TimeoutException("attempt deadline");

      expect(
        await send(),
        transientFailure(description: "no response", cause: isA<TimeoutException>(), stackTrace: isNotNull),
      );
    });
  });
}
