import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockNotificationPreferencesService extends Mock implements NotificationPreferencesService {}

void main() {
  late MockNotificationPreferencesService mockService;
  final initialPreferences = <NotificationCategory, bool>{
    NotificationCategory.aiInteraction: true,
    NotificationCategory.sessionMessage: false,
    NotificationCategory.connectionStatus: true,
    NotificationCategory.systemUpdate: true,
  };

  setUp(() {
    mockService = MockNotificationPreferencesService();
  });

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "loads stored preferences on initialization",
    setUp: () {
      when(() => mockService.getAll()).thenAnswer((_) async => initialPreferences);
    },
    build: () => NotificationPreferencesCubit(mockService),
    expect: () => [
      NotificationPreferencesState.loaded(preferences: initialPreferences),
    ],
    verify: (_) {
      verify(() => mockService.getAll()).called(1);
    },
  );

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "toggle persists and emits updated loaded state",
    setUp: () {
      when(() => mockService.getAll()).thenAnswer((_) async => initialPreferences);
      when(
        () => mockService.setEnabled(
          NotificationCategory.sessionMessage,
          enabled: true,
        ),
      ).thenAnswer((_) async {});
    },
    build: () => NotificationPreferencesCubit(mockService),
    act: (cubit) => cubit.toggle(
      NotificationCategory.sessionMessage,
      enabled: true,
    ),
    expect: () => [
      NotificationPreferencesState.loaded(preferences: initialPreferences),
      NotificationPreferencesState.loaded(
        preferences: {
          ...initialPreferences,
          NotificationCategory.sessionMessage: true,
        },
      ),
    ],
    verify: (_) {
      verify(() => mockService.getAll()).called(1);
      verify(
        () => mockService.setEnabled(
          NotificationCategory.sessionMessage,
          enabled: true,
        ),
      ).called(1);
    },
  );

  test("toggle while loading only persists preference", () async {
    when(
      () => mockService.getAll(),
    ).thenAnswer((_) => Future<Map<NotificationCategory, bool>>.value(initialPreferences));
    when(
      () => mockService.setEnabled(
        NotificationCategory.systemUpdate,
        enabled: false,
      ),
    ).thenAnswer((_) async {});

    final cubit = NotificationPreferencesCubit(mockService);
    await cubit.toggle(NotificationCategory.systemUpdate, enabled: false);

    verify(
      () => mockService.setEnabled(
        NotificationCategory.systemUpdate,
        enabled: false,
      ),
    ).called(1);
    await cubit.close();
  });
}
