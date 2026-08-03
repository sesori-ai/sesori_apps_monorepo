import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockAuthSession extends Mock implements AuthSession {}

class MockNotificationPreferencesRepository extends Mock implements NotificationPreferencesRepository {}

const _userA = AuthUser(
  id: "user-a",
  provider: AuthProvider.github,
  providerUserId: "github-a",
  providerUsername: "alpha",
);
const _userB = AuthUser(
  id: "user-b",
  provider: AuthProvider.google,
  providerUserId: "google-b",
  providerUsername: "beta",
);
const _preferences = <NotificationCategory, bool>{
  NotificationCategory.aiInteraction: true,
  NotificationCategory.sessionMessage: false,
  NotificationCategory.connectionStatus: true,
  NotificationCategory.systemUpdate: true,
};

void main() {
  late MockAuthSession authSession;
  late MockNotificationPreferencesRepository repository;
  late BehaviorSubject<AuthState> authStates;
  late NotificationPreferencesService service;

  setUp(() {
    authSession = MockAuthSession();
    repository = MockNotificationPreferencesRepository();
    authStates = BehaviorSubject.seeded(const AuthState.authenticated(user: _userA));
    when(() => authSession.currentState).thenAnswer((_) => authStates.value);
    when(() => authSession.authStateStream).thenAnswer((_) => authStates.stream);
    service = NotificationPreferencesService(authSession: authSession, repository: repository);
  });

  tearDown(() async {
    await service.dispose();
    await authStates.close();
  });

  test("rejects obsolete results and reloads through the replacement account", () async {
    final userAResponse = Completer<Map<NotificationCategory, bool>>();
    when(() => repository.getAll(userId: _userA.id)).thenAnswer((_) => userAResponse.future);
    when(
      () => repository.getAll(userId: _userB.id),
    ).thenAnswer((_) async => {..._preferences, NotificationCategory.sessionMessage: true});

    final obsolete = service.getAll();
    authStates.add(const AuthState.authenticated(user: _userB));
    await Future<void>.delayed(Duration.zero);
    userAResponse.complete(_preferences);

    await expectLater(obsolete, throwsA(isA<NotAuthenticatedError>()));
    expect(
      await service.getAll(),
      {..._preferences, NotificationCategory.sessionMessage: true},
    );
    verify(() => repository.clearCache(userId: _userA.id)).called(1);
    verify(() => repository.getAll(userId: _userB.id)).called(1);
  });

  test("publishes account availability and blocks requests after logout", () async {
    final statuses = <NotificationPreferencesAccountStatus>[];
    final subscription = service.accountStatusStream.listen(statuses.add);
    await Future<void>.delayed(Duration.zero);

    authStates.add(const AuthState.unauthenticated());
    await Future<void>.delayed(Duration.zero);

    expect(statuses, [
      NotificationPreferencesAccountStatus.available,
      NotificationPreferencesAccountStatus.unavailable,
    ]);
    await expectLater(service.getAll(), throwsA(isA<NotAuthenticatedError>()));
    await subscription.cancel();
  });

  test("foreground lookup defaults to enabled when account-bound loading fails", () async {
    when(
      () => repository.isEnabled(
        userId: _userA.id,
        category: NotificationCategory.aiInteraction,
      ),
    ).thenThrow(ApiError.generic());

    expect(
      await service.isEnabled(category: NotificationCategory.aiInteraction),
      isTrue,
    );
  });

  test("foreground lookup is disabled when no account is available", () async {
    authStates.add(const AuthState.unauthenticated());
    await Future<void>.delayed(Duration.zero);

    expect(
      await service.isEnabled(category: NotificationCategory.aiInteraction),
      isFalse,
    );
    verifyNever(
      () => repository.isEnabled(
        userId: _userA.id,
        category: NotificationCategory.aiInteraction,
      ),
    );
  });

  test("unknown foreground category is disabled when no account is available", () async {
    authStates.add(const AuthState.unauthenticated());
    await Future<void>.delayed(Duration.zero);

    expect(
      await service.isEnabled(category: NotificationCategory.unknown),
      isFalse,
    );
  });

  test("foreground lookup is disabled when its account becomes obsolete", () async {
    final response = Completer<bool>();
    when(
      () => repository.isEnabled(
        userId: _userA.id,
        category: NotificationCategory.aiInteraction,
      ),
    ).thenAnswer((_) => response.future);

    final enabled = service.isEnabled(category: NotificationCategory.aiInteraction);
    authStates.add(const AuthState.authenticated(user: _userB));
    await Future<void>.delayed(Duration.zero);
    response.complete(true);

    expect(await enabled, isFalse);
  });

  test("foreground lookup defaults to enabled after the repository deadline", () async {
    when(
      () => repository.isEnabled(
        userId: _userA.id,
        category: NotificationCategory.aiInteraction,
      ),
    ).thenThrow(TimeoutException("Notification preference read timed out"));

    expect(
      await service.isEnabled(category: NotificationCategory.aiInteraction),
      isTrue,
    );
  });
}
