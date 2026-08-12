import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

const _deviceId = "123e4567-e89b-42d3-a456-426614174000";
const _userId = "user-a";

final class _RecordingAuthenticatedClient() extends Mock implements AuthenticatedHttpApiClient {
  Object? getJson;
  Object? patchJson;
  ApiError? getError;
  Uri? lastUrl;
  String? lastUserId;
  String? lastBody;

  @override
  // ignore: no_slop_linter/prefer_specific_type, inherited JSON callback
  Future<ApiResponse<T>> getForUser<T>({
    required Uri url,
    required String userId,
    required T Function(dynamic json) fromJson,
  }) async {
    lastUrl = url;
    lastUserId = userId;
    final error = getError;
    if (error != null) return ApiResponse.error(error);
    return ApiResponse.success(fromJson(getJson));
  }

  @override
  // ignore: no_slop_linter/prefer_specific_type, inherited JSON callback
  Future<ApiResponse<T>> patchForUser<T>({
    required Uri url,
    required String userId,
    required T Function(dynamic json) fromJson,
    required String body,
  }) async {
    lastUrl = url;
    lastUserId = userId;
    lastBody = body;
    return ApiResponse.success(fromJson(patchJson));
  }
}

void main() {
  late _RecordingAuthenticatedClient client;
  late NotificationPreferencesApi api;

  setUp(() {
    client = _RecordingAuthenticatedClient();
    api = NotificationPreferencesApi(client: client);
  });

  test("GET uses the device settings endpoint and parses all known preferences", () async {
    client.getJson = _response(
      preferences: {
        "aiInteraction": false,
        "sessionMessage": true,
        "connectionStatus": false,
        "systemUpdate": true,
        "futureCategory": false,
      },
    );

    final record = await api.getPreferences(userId: _userId, deviceId: _deviceId);

    expect(client.lastUrl?.path, "/auth/settings/$_deviceId");
    expect(client.lastUserId, _userId);
    expect(record.deviceId, _deviceId);
    expect(record.notifications.aiInteraction, isFalse);
    expect(record.notifications.sessionMessage, isTrue);
    expect(record.notifications.connectionStatus, isFalse);
    expect(record.notifications.systemUpdate, isTrue);
  });

  test("PATCH sends only the changed preference and returns server-confirmed state", () async {
    client.patchJson = _response(
      preferences: {
        "aiInteraction": true,
        "sessionMessage": false,
        "connectionStatus": true,
        "systemUpdate": true,
      },
    );

    final record = await api.updatePreference(
      userId: _userId,
      deviceId: _deviceId,
      request: const NotificationPreferencePatchApiRequest.sessionMessage(enabled: false),
    );

    expect(client.lastUrl?.path, "/auth/settings/$_deviceId");
    expect(client.lastUserId, _userId);
    expect(jsonDecode(client.lastBody!), {
      "notifications": {"sessionMessage": false},
    });
    expect(record.notifications.sessionMessage, isFalse);
  });

  test("response parsing requires every known preference", () {
    expect(
      () => NotificationPreferencesApiRecord.fromJson(
        _response(
          preferences: {
            "aiInteraction": true,
            "sessionMessage": true,
            "connectionStatus": true,
          },
        ),
      ),
      throwsA(anything),
    );
  });

  test("GET propagates authenticated API errors", () async {
    client.getError = ApiError.notAuthenticated();

    await expectLater(
      api.getPreferences(userId: _userId, deviceId: _deviceId),
      throwsA(isA<NotAuthenticatedError>()),
    );
  });
}

Map<String, dynamic> _response({
  String deviceId = _deviceId,
  Map<String, bool> preferences = const {
    "aiInteraction": true,
    "sessionMessage": true,
    "connectionStatus": true,
    "systemUpdate": true,
  },
}) => {
  "deviceId": deviceId,
  "notifications": preferences,
  "updatedAt": null,
};
