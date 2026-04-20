import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockNotificationPreferencesRepository extends Mock implements NotificationPreferencesRepository {}

void main() {
  late MockNotificationPreferencesRepository mockRepository;
  final initialPreferences = <NotificationCategory, bool>{
    NotificationCategory.aiInteraction: true,
    NotificationCategory.sessionMessage: false,
    NotificationCategory.connectionStatus: true,
    NotificationCategory.systemUpdate: true,
  };

  setUp(() {
    mockRepository = MockNotificationPreferencesRepository();
  });

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "loads stored preferences on initialization",
    setUp: () {
      when(() => mockRepository.getAll()).thenAnswer((_) async => initialPreferences);
    },
    build: () => NotificationPreferencesCubit(mockRepository),
    expect: () => [
      NotificationPreferencesState.loaded(preferences: initialPreferences),
    ],
    verify: (_) {
      verify(() => mockRepository.getAll()).called(1);
    },
  );

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "toggle persists and emits updated loaded state",
    setUp: () {
      when(() => mockRepository.getAll()).thenAnswer((_) async => initialPreferences);
      when(
        () => mockRepository.setEnabled(
          category: NotificationCategory.sessionMessage,
          enabled: true,
        ),
      ).thenAnswer((_) async {});
    },
    build: () => NotificationPreferencesCubit(mockRepository),
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
      verify(() => mockRepository.getAll()).called(1);
      verify(
        () => mockRepository.setEnabled(
          category: NotificationCategory.sessionMessage,
          enabled: true,
        ),
      ).called(1);
    },
  );

  test("toggle while loading only persists preference", () async {
    when(
      () => mockRepository.getAll(),
    ).thenAnswer((_) => Future<Map<NotificationCategory, bool>>.value(initialPreferences));
    when(
      () => mockRepository.setEnabled(
        category: NotificationCategory.systemUpdate,
        enabled: false,
      ),
    ).thenAnswer((_) async {});

    final cubit = NotificationPreferencesCubit(mockRepository);
    await cubit.toggle(NotificationCategory.systemUpdate, enabled: false);

    verify(
      () => mockRepository.setEnabled(
        category: NotificationCategory.systemUpdate,
        enabled: false,
      ),
    ).called(1);
    await cubit.close();
  });
}
