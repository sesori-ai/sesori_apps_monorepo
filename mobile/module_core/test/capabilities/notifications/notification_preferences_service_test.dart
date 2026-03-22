import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockSecureStorage mockStorage;
  late NotificationPreferencesService service;

  setUp(() {
    mockStorage = MockSecureStorage();
    service = NotificationPreferencesService(mockStorage);
  });

  group("NotificationPreferencesService", () {
    test("isEnabled defaults to true when value is missing", () async {
      when(
        () => mockStorage.read(key: NotificationCategoryPreference.aiInteraction.storageKey),
      ).thenAnswer((_) async => null);

      final enabled = await service.isEnabled(NotificationCategoryPreference.aiInteraction);

      expect(enabled, isTrue);
      verify(
        () => mockStorage.read(key: NotificationCategoryPreference.aiInteraction.storageKey),
      ).called(1);
    });

    test("isEnabled returns false when stored value is false", () async {
      when(
        () => mockStorage.read(key: NotificationCategoryPreference.sessionMessage.storageKey),
      ).thenAnswer((_) async => "false");

      final enabled = await service.isEnabled(NotificationCategoryPreference.sessionMessage);

      expect(enabled, isFalse);
    });

    test("setEnabled persists boolean value as string", () async {
      when(
        () => mockStorage.write(
          key: NotificationCategoryPreference.connectionStatus.storageKey,
          value: "false",
        ),
      ).thenAnswer((_) async {});

      await service.setEnabled(NotificationCategoryPreference.connectionStatus, enabled: false);

      verify(
        () => mockStorage.write(
          key: NotificationCategoryPreference.connectionStatus.storageKey,
          value: "false",
        ),
      ).called(1);
    });

    test("getAll returns all category values with defaults", () async {
      when(
        () => mockStorage.read(key: NotificationCategoryPreference.aiInteraction.storageKey),
      ).thenAnswer((_) async => "false");
      when(
        () => mockStorage.read(key: NotificationCategoryPreference.sessionMessage.storageKey),
      ).thenAnswer((_) async => "true");
      when(
        () => mockStorage.read(key: NotificationCategoryPreference.connectionStatus.storageKey),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.read(key: NotificationCategoryPreference.systemUpdate.storageKey),
      ).thenAnswer((_) async => "false");

      final all = await service.getAll();

      expect(all, hasLength(NotificationCategoryPreference.values.length));
      expect(all[NotificationCategoryPreference.aiInteraction], isFalse);
      expect(all[NotificationCategoryPreference.sessionMessage], isTrue);
      expect(all[NotificationCategoryPreference.connectionStatus], isTrue);
      expect(all[NotificationCategoryPreference.systemUpdate], isFalse);
    });
  });
}
