import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/api/notification_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockNotificationApi() extends Mock implements NotificationApi;

class MockNotificationPreferencesDeviceIdStorage() extends Mock implements NotificationPreferencesDeviceIdStorage;

const _deviceId = "de250236-dd17-4fbf-a37e-4fcf5dc8c86b";
const _fid = "fid-1";

void main() {
  late MockNotificationApi api;
  late MockNotificationPreferencesDeviceIdStorage deviceIdStorage;
  late NotificationRepository repository;

  setUpAll(() {
    registerFallbackValue(const RegisterFidRequest(fid: _fid, platform: DevicePlatform.ios, deviceId: _deviceId));
  });

  setUp(() {
    api = MockNotificationApi();
    deviceIdStorage = MockNotificationPreferencesDeviceIdStorage();
    when(() => api.registerFid(request: any(named: "request"))).thenAnswer((_) async {});
    repository = NotificationRepository(api: api, deviceIdStorage: deviceIdStorage);
  });

  group("NotificationRepository", () {
    // This is the id the notification settings are stored under, and the one
    // the server retires this device's pre-FID push token by, so it has to
    // reach the server with the FID.
    test("registerFid sends the stored device id", () async {
      when(() => deviceIdStorage.getOrCreate()).thenAnswer((_) async => _deviceId);

      await repository.registerFid(fid: _fid, platform: DevicePlatform.ios);

      final captured =
          verify(() => api.registerFid(request: captureAny(named: "request"))).captured.single as RegisterFidRequest;
      expect(captured.fid, _fid);
      expect(captured.platform, DevicePlatform.ios);
      expect(captured.deviceId, _deviceId);
    });

    // An FID row without a device id could not replace this device's old token
    // row, so the install would get each push twice; sending nothing lets a
    // later report, login or launch retry with the id.
    test("registerFid fails without sending when the device id cannot be read", () async {
      when(() => deviceIdStorage.getOrCreate()).thenThrow(Exception("secure storage unavailable"));

      await expectLater(repository.registerFid(fid: _fid, platform: DevicePlatform.android), throwsException);

      verifyNever(() => api.registerFid(request: any(named: "request")));
    });

    test("unregisterFid delegates to the api without touching device id storage", () async {
      when(() => api.unregisterFid(fid: _fid)).thenAnswer((_) async {});

      await repository.unregisterFid(fid: _fid);

      verify(() => api.unregisterFid(fid: _fid)).called(1);
      verifyNever(() => deviceIdStorage.getOrCreate());
    });
  });
}
