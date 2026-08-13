import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockNotificationApi() extends Mock implements NotificationApi;

class MockNotificationPreferencesDeviceIdStorage() extends Mock implements NotificationPreferencesDeviceIdStorage;

const _deviceId = "de250236-dd17-4fbf-a37e-4fcf5dc8c86b";
const _token = "fcm-token";

void main() {
  late MockNotificationApi api;
  late MockNotificationPreferencesDeviceIdStorage deviceIdStorage;
  late NotificationRepository repository;

  setUpAll(() {
    registerFallbackValue(const RegisterTokenRequest(token: _token, platform: DevicePlatform.ios, deviceId: null));
  });

  setUp(() {
    api = MockNotificationApi();
    deviceIdStorage = MockNotificationPreferencesDeviceIdStorage();
    when(() => api.registerToken(request: any(named: "request"))).thenAnswer((_) async {});
    repository = NotificationRepository(api: api, deviceIdStorage: deviceIdStorage);
  });

  group("NotificationRepository", () {
    // This is the id the notification settings are stored under, so sending it
    // is what lets the server apply per-device filtering to this token at all.
    test("registerToken sends the stored device id", () async {
      when(() => deviceIdStorage.getOrCreate()).thenAnswer((_) async => _deviceId);

      await repository.registerToken(token: _token, platform: DevicePlatform.ios);

      final captured =
          verify(() => api.registerToken(request: captureAny(named: "request"))).captured.single
              as RegisterTokenRequest;
      expect(captured.token, _token);
      expect(captured.platform, DevicePlatform.ios);
      expect(captured.deviceId, _deviceId);
    });

    // Losing the device id costs filtering; failing the registration would cost
    // push entirely, so the token still has to reach the server.
    test("registerToken still registers when the device id cannot be read", () async {
      when(() => deviceIdStorage.getOrCreate()).thenThrow(Exception("secure storage unavailable"));

      await repository.registerToken(token: _token, platform: DevicePlatform.android);

      final captured =
          verify(() => api.registerToken(request: captureAny(named: "request"))).captured.single
              as RegisterTokenRequest;
      expect(captured.token, _token);
      expect(captured.deviceId, isNull);
    });

    test("unregisterToken delegates to the api without touching device id storage", () async {
      when(() => api.unregisterToken(token: _token)).thenAnswer((_) async {});

      await repository.unregisterToken(token: _token);

      verify(() => api.unregisterToken(token: _token)).called(1);
      verifyNever(() => deviceIdStorage.getOrCreate());
    });
  });
}
