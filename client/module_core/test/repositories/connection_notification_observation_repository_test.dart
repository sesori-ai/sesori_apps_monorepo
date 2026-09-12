import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/api/connection_notification_observation_api.dart";
import "package:sesori_dart_core/src/api/storage/notification_preferences_device_id_storage.dart";
import "package:sesori_dart_core/src/repositories/connection_notification_observation_repository.dart";
import "package:test/test.dart";

class MockConnectionNotificationObservationApi() extends Mock implements ConnectionNotificationObservationApi;

class MockNotificationPreferencesDeviceIdStorage() extends Mock implements NotificationPreferencesDeviceIdStorage;

class MockConnectionNotificationObservationToken() extends Mock implements ConnectionNotificationObservationToken;

void main() {
  test("deduplicates one connection and preserves its token across async device ID lookup", () async {
    final api = MockConnectionNotificationObservationApi();
    final storage = MockNotificationPreferencesDeviceIdStorage();
    final connection = MockConnectionNotificationObservationToken();
    final deviceId = Completer<String>();
    when(api.captureCurrentConnection).thenReturn(connection);
    when(storage.getOrCreate).thenAnswer((_) => deviceId.future);
    when(
      () => api.reportObserved(
        connection: connection,
        deviceId: any(named: "deviceId"),
      ),
    ).thenReturn(true);
    final repository = ConnectionNotificationObservationRepository(api: api, deviceIdStorage: storage);

    final first = repository.reportCurrentConnectionObserved();
    await repository.reportCurrentConnectionObserved();
    deviceId.complete("123e4567-e89b-42d3-a456-426614174000");
    await first;

    verify(api.captureCurrentConnection).called(2);
    verify(storage.getOrCreate).called(1);
    verify(
      () => api.reportObserved(
        connection: connection,
        deviceId: "123e4567-e89b-42d3-a456-426614174000",
      ),
    ).called(1);
  });
}
