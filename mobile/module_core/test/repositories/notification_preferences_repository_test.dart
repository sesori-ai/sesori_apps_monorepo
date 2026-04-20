import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockNotificationPreferencesApi extends Mock implements NotificationPreferencesApi {}

void main() {
  late MockNotificationPreferencesApi api;
  late NotificationPreferencesRepository repository;

  setUp(() {
    api = MockNotificationPreferencesApi();
    repository = NotificationPreferencesRepository(api: api);
  });

  group("NotificationPreferencesRepository", () {
    test("missing preference defaults to enabled", () async {
      when(
        () => api.readValue(key: "notification_pref_aiInteraction"),
      ).thenAnswer((_) async => null);

      final enabled = await repository.isEnabled(category: NotificationCategory.aiInteraction);

      expect(enabled, isTrue);
      verify(() => api.readValue(key: "notification_pref_aiInteraction")).called(1);
    });

    test("stored false disables category", () async {
      when(
        () => api.readValue(key: "notification_pref_sessionMessage"),
      ).thenAnswer((_) async => "false");

      final enabled = await repository.isEnabled(category: NotificationCategory.sessionMessage);

      expect(enabled, isFalse);
    });

    test("setEnabled persists boolean string through api", () async {
      when(
        () => api.writeValue(key: "notification_pref_connectionStatus", value: "false"),
      ).thenAnswer((_) async {});

      await repository.setEnabled(category: NotificationCategory.connectionStatus, enabled: false);

      verify(
        () => api.writeValue(key: "notification_pref_connectionStatus", value: "false"),
      ).called(1);
    });

    test("setEnabled removes stored value when enabling defaulted category", () async {
      when(
        () => api.deleteValue(key: "notification_pref_connectionStatus"),
      ).thenAnswer((_) async {});

      await repository.setEnabled(category: NotificationCategory.connectionStatus, enabled: true);

      verify(() => api.deleteValue(key: "notification_pref_connectionStatus")).called(1);
    });

    test("getAll returns all category values with repository defaults", () async {
      when(
        () => api.readValue(key: "notification_pref_aiInteraction"),
      ).thenAnswer((_) async => "false");
      when(
        () => api.readValue(key: "notification_pref_sessionMessage"),
      ).thenAnswer((_) async => "true");
      when(
        () => api.readValue(key: "notification_pref_connectionStatus"),
      ).thenAnswer((_) async => null);
      when(
        () => api.readValue(key: "notification_pref_systemUpdate"),
      ).thenAnswer((_) async => "false");
      when(
        () => api.readValue(key: "notification_pref_unknown"),
      ).thenAnswer((_) async => null);

      final all = await repository.getAll();

      expect(all, hasLength(NotificationCategory.values.length));
      expect(all[NotificationCategory.aiInteraction], isFalse);
      expect(all[NotificationCategory.sessionMessage], isTrue);
      expect(all[NotificationCategory.connectionStatus], isTrue);
      expect(all[NotificationCategory.systemUpdate], isFalse);
      expect(all[NotificationCategory.unknown], isTrue);
    });
  });
}
