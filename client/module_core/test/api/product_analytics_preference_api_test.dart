import "dart:async";
import "dart:convert";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

const _userKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const _userId = "user-a";

class _RecordingAuthenticatedClient extends Mock implements AuthenticatedHttpApiClient {
  Object? getJson;
  Object? putJson;
  ApiError? getError;
  ApiError? putError;
  bool hangGet = false;
  bool hangPut = false;
  Uri? lastUrl;
  String? lastUserId;
  String? lastBody;

  @override
  // ignore: no_slop_linter/prefer_specific_type, inherited JSON callback
  Future<ApiResponse<T>> getForUser<T>(
    Uri url, {
    required String userId,
    required T Function(dynamic json) fromJson,
  }) async {
    lastUrl = url;
    lastUserId = userId;
    if (hangGet) return Completer<ApiResponse<T>>().future;
    final error = getError;
    if (error != null) return ApiResponse.error(error);
    return ApiResponse.success(fromJson(getJson));
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, inherited JSON callback
  Future<ApiResponse<T>> putForUser<T>(
    Uri url, {
    required String userId,
    required T Function(dynamic json) fromJson,
    required String body,
  }) async {
    lastUrl = url;
    lastUserId = userId;
    lastBody = body;
    if (hangPut) return Completer<ApiResponse<T>>().future;
    final error = putError;
    if (error != null) return ApiResponse.error(error);
    return ApiResponse.success(fromJson(putJson));
  }
}

void main() {
  late _RecordingAuthenticatedClient client;
  late ProductAnalyticsPreferenceApi api;

  setUp(() {
    client = _RecordingAuthenticatedClient();
    api = ProductAnalyticsPreferenceApi(client: client);
  });

  test("GET parses the closed preference response and validated server key", () async {
    client.getJson = {"preference": "enabled", "revision": 4, "userKey": _userKey};

    final result = await api.getPreference(userId: _userId);

    expect(client.lastUrl?.path, "/product-analytics/preference");
    expect(client.lastUserId, _userId);
    expect(result, isA<ProductAnalyticsPreferenceApiSuccess>());
    final record = (result as ProductAnalyticsPreferenceApiSuccess).record;
    expect(record.preference, ProductAnalyticsPreference.enabled);
    expect(record.revision, 4);
    expect(record.userKey, _userKey);
  });

  test("GET rejects unknown preference, revision, and malformed user keys", () async {
    for (final json in [
      {"preference": "unknown", "revision": 1, "userKey": _userKey},
      {"preference": "enabled", "revision": 0, "userKey": _userKey},
      {"preference": "enabled", "revision": 1, "userKey": List.filled(64, "A").join()},
    ]) {
      client.getJson = json;
      expect(await api.getPreference(userId: _userId), isA<ProductAnalyticsPreferenceApiFailure>());
    }
  });

  test("PUT sends revisioned idempotent body and parses success", () async {
    client.putJson = {"preference": "disabled", "revision": 3, "userKey": _userKey};

    final result = await api.updatePreference(
      userId: _userId,
      preference: ProductAnalyticsPreference.disabled,
      expectedRevision: 2,
      operationId: "123e4567-e89b-42d3-a456-426614174000",
    );

    expect(client.lastUrl?.path, "/product-analytics/preference");
    expect(jsonDecode(client.lastBody!), {
      "preference": "disabled",
      "expectedRevision": 2,
      "operationId": "123e4567-e89b-42d3-a456-426614174000",
    });
    expect(result, isA<ProductAnalyticsPreferenceApiSuccess>());
  });

  test("PUT parses an explicit conflict record", () async {
    client.putError = ApiError.nonSuccessCode(
      errorCode: 409,
      rawErrorString: '{"error":"conflict","preference":"disabled","revision":9,"userKey":"$_userKey"}',
    );

    final result = await api.updatePreference(
      userId: _userId,
      preference: ProductAnalyticsPreference.enabled,
      expectedRevision: 8,
      operationId: "123e4567-e89b-42d3-a456-426614174000",
    );

    expect(result, isA<ProductAnalyticsPreferenceApiConflict>());
    final record = (result as ProductAnalyticsPreferenceApiConflict).record;
    expect(record.preference, ProductAnalyticsPreference.disabled);
    expect(record.revision, 9);
    expect(record.userKey, _userKey);
  });

  test("malformed conflicts and ordinary errors remain explicit failures", () async {
    client.putError = ApiError.nonSuccessCode(errorCode: 409, rawErrorString: '{"error":"conflict"}');
    expect(
      await api.updatePreference(
        userId: _userId,
        preference: ProductAnalyticsPreference.disabled,
        expectedRevision: 1,
        operationId: "123e4567-e89b-42d3-a456-426614174000",
      ),
      isA<ProductAnalyticsPreferenceApiFailure>(),
    );

    client.putError = ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "unavailable");
    expect(
      await api.updatePreference(
        userId: _userId,
        preference: ProductAnalyticsPreference.disabled,
        expectedRevision: 1,
        operationId: "123e4567-e89b-42d3-a456-426614174000",
      ),
      isA<ProductAnalyticsPreferenceApiFailure>(),
    );
  });

  test("GET and PUT release callers after the fixed ten-second deadline", () {
    fakeAsync((async) {
      client.hangGet = true;
      ProductAnalyticsPreferenceApiResult? getResult;
      api.getPreference(userId: _userId).then((value) => getResult = value);

      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();

      expect(getResult, isA<ProductAnalyticsPreferenceApiTimeout>());

      client.hangPut = true;
      ProductAnalyticsPreferenceApiResult? putResult;
      api
          .updatePreference(
            userId: _userId,
            preference: ProductAnalyticsPreference.disabled,
            expectedRevision: 1,
            operationId: "123e4567-e89b-42d3-a456-426614174000",
          )
          .then((value) => putResult = value);

      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();

      expect(putResult, isA<ProductAnalyticsPreferenceApiTimeout>());
    });
  });
}
