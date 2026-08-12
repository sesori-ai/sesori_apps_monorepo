import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockNotificationPreferencesService extends Mock implements NotificationPreferencesService;

void main() {
  late MockNotificationPreferencesService mockService;
  late Completer<bool> aiResponse;
  late Completer<bool> sessionResponse;
  final initialPreferences = <NotificationCategory, bool>{
    NotificationCategory.aiInteraction: true,
    NotificationCategory.sessionMessage: false,
    NotificationCategory.connectionStatus: true,
    NotificationCategory.systemUpdate: true,
  };

  setUp(() {
    mockService = MockNotificationPreferencesService();
    when(
      () => mockService.accountStatusStream,
    ).thenAnswer((_) => Stream.value(NotificationPreferencesAccountStatus.available));
  });

  setUpAll(() {
    registerFallbackValue(NotificationCategory.aiInteraction);
  });

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "loads stored preferences on initialization",
    setUp: () {
      when(() => mockService.getAll()).thenAnswer((_) async => initialPreferences);
    },
    build: () => NotificationPreferencesCubit(service: mockService),
    expect: () => [
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {},
      ),
    ],
    verify: (_) {
      verify(() => mockService.getAll()).called(1);
    },
  );

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "shows a terminal state when no account is available",
    setUp: () {
      when(
        () => mockService.accountStatusStream,
      ).thenAnswer((_) => Stream.value(NotificationPreferencesAccountStatus.unavailable));
    },
    build: () => NotificationPreferencesCubit(service: mockService),
    expect: () => [
      const NotificationPreferencesState.accountUnavailable(),
    ],
    verify: (_) {
      verifyNever(() => mockService.getAll());
    },
  );

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "toggle persists and emits updated loaded state",
    setUp: () {
      when(() => mockService.getAll()).thenAnswer((_) async => initialPreferences);
      when(
        () => mockService.setEnabled(
          category: NotificationCategory.sessionMessage,
          enabled: true,
        ),
      ).thenAnswer((_) async => true);
    },
    build: () => NotificationPreferencesCubit(service: mockService),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      await cubit.toggle(
        NotificationCategory.sessionMessage,
        enabled: true,
      );
    },
    expect: () => [
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {},
      ),
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {NotificationCategory.sessionMessage},
      ),
      NotificationPreferencesState.loaded(
        preferences: {
          ...initialPreferences,
          NotificationCategory.sessionMessage: true,
        },
        updatingCategories: const {},
      ),
    ],
    verify: (_) {
      verify(() => mockService.getAll()).called(1);
      verify(
        () => mockService.setEnabled(
          category: NotificationCategory.sessionMessage,
          enabled: true,
        ),
      ).called(1);
    },
  );

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "toggle keeps the persisted value when the write fails",
    setUp: () {
      when(() => mockService.getAll()).thenAnswer((_) async => initialPreferences);
      when(
        () => mockService.setEnabled(
          category: NotificationCategory.sessionMessage,
          enabled: true,
        ),
      ).thenThrow(Exception("storage unavailable"));
    },
    build: () => NotificationPreferencesCubit(service: mockService),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      await cubit.toggle(
        NotificationCategory.sessionMessage,
        enabled: true,
      );
    },
    expect: () => [
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {},
      ),
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {NotificationCategory.sessionMessage},
      ),
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {},
      ),
    ],
  );

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "load failure is retryable",
    setUp: () {
      var attempt = 0;
      when(() => mockService.getAll()).thenAnswer((_) async {
        attempt++;
        if (attempt == 1) throw Exception("network unavailable");
        return initialPreferences;
      });
    },
    build: () => NotificationPreferencesCubit(service: mockService),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      await cubit.retry();
    },
    expect: () => [
      const NotificationPreferencesState.loadFailed(),
      const NotificationPreferencesState.loading(),
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {},
      ),
    ],
  );

  blocTest<NotificationPreferencesCubit, NotificationPreferencesState>(
    "different categories update independently and keep confirmed values while loading",
    setUp: () {
      aiResponse = Completer<bool>();
      sessionResponse = Completer<bool>();
      when(() => mockService.getAll()).thenAnswer((_) async => initialPreferences);
      when(
        () => mockService.setEnabled(
          category: any(named: "category"),
          enabled: any(named: "enabled"),
        ),
      ).thenAnswer((invocation) {
        final category = invocation.namedArguments[#category] as NotificationCategory;
        return switch (category) {
          NotificationCategory.aiInteraction => aiResponse.future,
          NotificationCategory.sessionMessage => sessionResponse.future,
          NotificationCategory.connectionStatus ||
          NotificationCategory.systemUpdate ||
          NotificationCategory.unknown => throw StateError("Unexpected category"),
        };
      });
    },
    build: () => NotificationPreferencesCubit(service: mockService),
    act: (cubit) async {
      await Future<void>.delayed(Duration.zero);
      final aiUpdate = cubit.toggle(NotificationCategory.aiInteraction, enabled: false);
      final sessionUpdate = cubit.toggle(NotificationCategory.sessionMessage, enabled: true);
      await Future<void>.delayed(Duration.zero);
      aiResponse.complete(false);
      await Future<void>.delayed(Duration.zero);
      sessionResponse.complete(true);
      await Future.wait([aiUpdate, sessionUpdate]);
    },
    expect: () => [
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {},
      ),
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {NotificationCategory.aiInteraction},
      ),
      NotificationPreferencesState.loaded(
        preferences: initialPreferences,
        updatingCategories: const {
          NotificationCategory.aiInteraction,
          NotificationCategory.sessionMessage,
        },
      ),
      NotificationPreferencesState.loaded(
        preferences: {
          ...initialPreferences,
          NotificationCategory.aiInteraction: false,
        },
        updatingCategories: const {NotificationCategory.sessionMessage},
      ),
      NotificationPreferencesState.loaded(
        preferences: {
          ...initialPreferences,
          NotificationCategory.aiInteraction: false,
          NotificationCategory.sessionMessage: true,
        },
        updatingCategories: const {},
      ),
    ],
  );

  test("account transition ignores the obsolete load result", () async {
    final accountStatuses = StreamController<NotificationPreferencesAccountStatus>.broadcast();
    final firstLoad = Completer<Map<NotificationCategory, bool>>();
    final secondLoad = Completer<Map<NotificationCategory, bool>>();
    var loadCount = 0;
    when(() => mockService.accountStatusStream).thenAnswer((_) => accountStatuses.stream);
    when(() => mockService.getAll()).thenAnswer((_) {
      loadCount++;
      return loadCount == 1 ? firstLoad.future : secondLoad.future;
    });
    final cubit = NotificationPreferencesCubit(service: mockService);

    accountStatuses.add(NotificationPreferencesAccountStatus.available);
    await Future<void>.delayed(Duration.zero);
    accountStatuses.add(NotificationPreferencesAccountStatus.unavailable);
    accountStatuses.add(NotificationPreferencesAccountStatus.available);
    await Future<void>.delayed(Duration.zero);
    secondLoad.complete({...initialPreferences, NotificationCategory.sessionMessage: true});
    await Future<void>.delayed(Duration.zero);
    firstLoad.complete(initialPreferences);
    await Future<void>.delayed(Duration.zero);

    expect(
      cubit.state,
      NotificationPreferencesState.loaded(
        preferences: {...initialPreferences, NotificationCategory.sessionMessage: true},
        updatingCategories: const {},
      ),
    );
    await cubit.close();
    await accountStatuses.close();
  });
}
