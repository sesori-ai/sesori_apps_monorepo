import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockNotificationPreferencesApi extends Mock implements NotificationPreferencesApi {}

class MockNotificationPreferencesDeviceIdStorage extends Mock implements NotificationPreferencesDeviceIdStorage {}

const _deviceId = "123e4567-e89b-42d3-a456-426614174000";
const _userA = "user-a";
const _userB = "user-b";

void main() {
  late MockNotificationPreferencesApi api;
  late MockNotificationPreferencesDeviceIdStorage deviceIdStorage;
  late NotificationPreferencesRepository repository;

  setUp(() {
    api = MockNotificationPreferencesApi();
    deviceIdStorage = MockNotificationPreferencesDeviceIdStorage();
    when(() => deviceIdStorage.getOrCreate()).thenAnswer((_) async => _deviceId);
    repository = NotificationPreferencesRepository(api: api, deviceIdStorage: deviceIdStorage);
  });

  group("NotificationPreferencesRepository", () {
    test("getAll fetches and maps all preferences in one request", () async {
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer((_) async => _record());

      final all = await repository.getAll(userId: _userA);

      expect(all, _preferences);
      verify(() => api.getPreferences(userId: _userA, deviceId: _deviceId)).called(1);
    });

    test("isEnabled reuses the server-confirmed cache", () async {
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer((_) async => _record());
      await repository.getAll(userId: _userA);

      final enabled = await repository.isEnabled(
        userId: _userA,
        category: NotificationCategory.sessionMessage,
      );

      expect(enabled, isFalse);
      verify(() => api.getPreferences(userId: _userA, deviceId: _deviceId)).called(1);
    });

    test("coalesces concurrent initial reads", () async {
      final response = Completer<NotificationPreferencesApiRecord>();
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer((_) => response.future);

      final first = repository.isEnabled(userId: _userA, category: NotificationCategory.aiInteraction);
      final second = repository.isEnabled(userId: _userA, category: NotificationCategory.connectionStatus);
      response.complete(_record());

      expect(await first, isTrue);
      expect(await second, isTrue);
      verify(() => api.getPreferences(userId: _userA, deviceId: _deviceId)).called(1);
    });

    test("setEnabled applies only the category confirmed by its PATCH", () async {
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer((_) async => _record());
      when(
        () => api.updatePreference(
          userId: _userA,
          deviceId: _deviceId,
          request: const NotificationPreferencePatchApiRequest.aiInteraction(enabled: false),
        ),
      ).thenAnswer((_) async => _record(notifications: _updatedNotifications));
      await repository.getAll(userId: _userA);

      final confirmed = await repository.setEnabled(
        userId: _userA,
        category: NotificationCategory.aiInteraction,
        enabled: false,
      );

      expect(confirmed, isFalse);
      expect(
        await repository.isEnabled(userId: _userA, category: NotificationCategory.aiInteraction),
        isFalse,
      );
      expect(
        await repository.isEnabled(userId: _userA, category: NotificationCategory.sessionMessage),
        isFalse,
      );
    });

    test("concurrent PATCHes merge each confirmation into the latest cache", () async {
      final aiResponse = Completer<NotificationPreferencesApiRecord>();
      final sessionResponse = Completer<NotificationPreferencesApiRecord>();
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer((_) async => _record());
      when(
        () => api.updatePreference(
          userId: _userA,
          deviceId: _deviceId,
          request: const NotificationPreferencePatchApiRequest.aiInteraction(enabled: false),
        ),
      ).thenAnswer((_) => aiResponse.future);
      when(
        () => api.updatePreference(
          userId: _userA,
          deviceId: _deviceId,
          request: const NotificationPreferencePatchApiRequest.sessionMessage(enabled: true),
        ),
      ).thenAnswer((_) => sessionResponse.future);
      await repository.getAll(userId: _userA);

      final aiUpdate = repository.setEnabled(
        userId: _userA,
        category: NotificationCategory.aiInteraction,
        enabled: false,
      );
      final sessionUpdate = repository.setEnabled(
        userId: _userA,
        category: NotificationCategory.sessionMessage,
        enabled: true,
      );
      aiResponse.complete(_record(notifications: _updatedNotifications));
      await aiUpdate;
      sessionResponse.complete(_record(notifications: _userBNotifications));
      await sessionUpdate;

      expect(
        await repository.isEnabled(userId: _userA, category: NotificationCategory.aiInteraction),
        isFalse,
      );
      expect(
        await repository.isEnabled(userId: _userA, category: NotificationCategory.sessionMessage),
        isTrue,
      );
    });

    test("a failed PATCH preserves the previous confirmed cache", () async {
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer((_) async => _record());
      when(
        () => api.updatePreference(
          userId: _userA,
          deviceId: _deviceId,
          request: const NotificationPreferencePatchApiRequest.sessionMessage(enabled: true),
        ),
      ).thenThrow(ApiError.generic());
      await repository.getAll(userId: _userA);

      await expectLater(
        repository.setEnabled(
          userId: _userA,
          category: NotificationCategory.sessionMessage,
          enabled: true,
        ),
        throwsA(isA<GenericError>()),
      );

      expect(
        await repository.isEnabled(userId: _userA, category: NotificationCategory.sessionMessage),
        isFalse,
      );
    });

    test("keeps caches keyed by account", () async {
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer((_) async => _record());
      when(
        () => api.getPreferences(userId: _userB, deviceId: _deviceId),
      ).thenAnswer((_) async => _record(notifications: _userBNotifications));
      await repository.getAll(userId: _userA);

      final enabledForUserB = await repository.isEnabled(
        userId: _userB,
        category: NotificationCategory.sessionMessage,
      );

      expect(enabledForUserB, isTrue);
      expect(
        await repository.isEnabled(userId: _userA, category: NotificationCategory.sessionMessage),
        isFalse,
      );
      verify(() => api.getPreferences(userId: _userB, deviceId: _deviceId)).called(1);
    });

    test("clearCache rejects and does not retain an obsolete in-flight response", () async {
      final response = Completer<NotificationPreferencesApiRecord>();
      var requestCount = 0;
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer((_) {
        requestCount++;
        return requestCount == 1 ? response.future : Future.value(_record());
      });

      final obsolete = repository.getAll(userId: _userA);
      await Future<void>.delayed(Duration.zero);
      repository.clearCache(userId: _userA);
      response.complete(_record());

      await expectLater(obsolete, throwsA(isA<NotAuthenticatedError>()));
      expect(await repository.getAll(userId: _userA), _preferences);
      verify(() => api.getPreferences(userId: _userA, deviceId: _deviceId)).called(2);
    });

    test("rejects a response for another device", () async {
      when(
        () => api.getPreferences(userId: _userA, deviceId: _deviceId),
      ).thenAnswer(
        (_) async => _record(deviceId: "223e4567-e89b-42d3-a456-426614174000"),
      );

      await expectLater(
        repository.getAll(userId: _userA),
        throwsFormatException,
      );
    });

    test("unknown categories remain enabled without calling the settings API", () async {
      expect(
        await repository.isEnabled(userId: _userA, category: NotificationCategory.unknown),
        isTrue,
      );
      verifyNever(
        () => api.getPreferences(
          userId: any(named: "userId"),
          deviceId: any(named: "deviceId"),
        ),
      );
    });
  });
}

const _preferences = <NotificationCategory, bool>{
  NotificationCategory.aiInteraction: true,
  NotificationCategory.sessionMessage: false,
  NotificationCategory.connectionStatus: true,
  NotificationCategory.systemUpdate: true,
};

const _notifications = NotificationPreferencesApiNotifications(
  aiInteraction: true,
  sessionMessage: false,
  connectionStatus: true,
  systemUpdate: true,
);

const _updatedNotifications = NotificationPreferencesApiNotifications(
  aiInteraction: false,
  sessionMessage: true,
  connectionStatus: true,
  systemUpdate: true,
);

const _userBNotifications = NotificationPreferencesApiNotifications(
  aiInteraction: true,
  sessionMessage: true,
  connectionStatus: true,
  systemUpdate: true,
);

NotificationPreferencesApiRecord _record({
  String deviceId = _deviceId,
  NotificationPreferencesApiNotifications notifications = _notifications,
}) => NotificationPreferencesApiRecord(
  deviceId: deviceId,
  notifications: notifications,
  updatedAt: null,
);
