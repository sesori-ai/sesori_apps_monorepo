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
        () => api.readValue(category: NotificationCategory.aiInteraction),
      ).thenAnswer((_) async => null);

      final enabled = await repository.isEnabled(category: NotificationCategory.aiInteraction);

      expect(enabled, isTrue);
      verify(() => api.readValue(category: NotificationCategory.aiInteraction)).called(1);
    });

    test("stored false disables category", () async {
      when(
        () => api.readValue(category: NotificationCategory.sessionMessage),
      ).thenAnswer((_) async => false);

      final enabled = await repository.isEnabled(category: NotificationCategory.sessionMessage);

      expect(enabled, isFalse);
    });

    test("setEnabled persists disabled value through api", () async {
      when(
        () => api.writeValue(category: NotificationCategory.connectionStatus, enabled: false),
      ).thenAnswer((_) async {});

      await repository.setEnabled(category: NotificationCategory.connectionStatus, enabled: false);

      verify(
        () => api.writeValue(category: NotificationCategory.connectionStatus, enabled: false),
      ).called(1);
    });

    test("setEnabled removes stored value when enabling defaulted category", () async {
      when(
        () => api.deleteValue(category: NotificationCategory.connectionStatus),
      ).thenAnswer((_) async {});

      await repository.setEnabled(category: NotificationCategory.connectionStatus, enabled: true);

      verify(() => api.deleteValue(category: NotificationCategory.connectionStatus)).called(1);
    });

    test("getAll returns all category values with repository defaults", () async {
      when(
        () => api.readValue(category: NotificationCategory.aiInteraction),
      ).thenAnswer((_) async => false);
      when(
        () => api.readValue(category: NotificationCategory.sessionMessage),
      ).thenAnswer((_) async => true);
      when(
        () => api.readValue(category: NotificationCategory.connectionStatus),
      ).thenAnswer((_) async => null);
      when(
        () => api.readValue(category: NotificationCategory.systemUpdate),
      ).thenAnswer((_) async => false);
      when(
        () => api.readValue(category: NotificationCategory.unknown),
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
