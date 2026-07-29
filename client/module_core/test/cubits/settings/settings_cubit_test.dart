import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/settings/settings_cubit.dart";
import "package:sesori_dart_core/src/cubits/settings/settings_state.dart";
import "package:sesori_dart_core/src/services/notification_registration_service.dart";
import "package:sesori_dart_core/src/services/product_analytics_service.dart";
import "package:test/test.dart";

class _MockAuthSession extends Mock implements AuthSession {}

class _MockNotificationRegistrationService extends Mock implements NotificationRegistrationService {}

class _MockProductAnalyticsService extends Mock implements ProductAnalyticsService {}

void main() {
  group("SettingsCubit", () {
    late _MockAuthSession authSession;
    late _MockNotificationRegistrationService notificationRegistrationService;
    late _MockProductAnalyticsService productAnalyticsService;
    late BehaviorSubject<AuthState> authStates;

    const user = AuthUser(
      id: "u1",
      provider: AuthProvider.github,
      providerUserId: "gh1",
      providerUsername: "octocat",
    );

    setUp(() {
      authSession = _MockAuthSession();
      notificationRegistrationService = _MockNotificationRegistrationService();
      productAnalyticsService = _MockProductAnalyticsService();
      authStates = BehaviorSubject<AuthState>.seeded(const AuthState.unauthenticated());
      when(() => authSession.currentState).thenAnswer((_) => authStates.value);
      when(() => authSession.authStateStream).thenAnswer((_) => authStates);
      when(() => notificationRegistrationService.unregisterCurrentDevice()).thenAnswer((_) async {});
      when(
        () => notificationRegistrationService.resumeRegistrationAfterFailedLogout(),
      ).thenAnswer((_) async {});
      when(() => productAnalyticsService.prepareForLogout()).thenAnswer((_) async {});
    });

    tearDown(() => authStates.close());

    test("initial state is idle with the account from the current auth state", () {
      authStates.add(const AuthState.authenticated(user: user));

      final cubit = SettingsCubit(
        authSession: authSession,
        notificationRegistrationService: notificationRegistrationService,
        productAnalyticsService: productAnalyticsService,
      );
      addTearDown(cubit.close);

      expect(cubit.state.logoutStatus, SettingsLogoutStatus.idle);
      expect(cubit.state.account, user);
    });

    test("updates the account when the auth state stream emits", () async {
      final cubit = SettingsCubit(
        authSession: authSession,
        notificationRegistrationService: notificationRegistrationService,
        productAnalyticsService: productAnalyticsService,
      );
      addTearDown(cubit.close);

      expect(cubit.state.account, isNull);

      final next = cubit.stream.firstWhere((s) => s.account != null);
      authStates.add(const AuthState.authenticated(user: user));

      expect((await next).account, user);
    });

    test("emits inProgress then success after logout succeeds", () async {
      when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});

      final cubit = SettingsCubit(
        authSession: authSession,
        notificationRegistrationService: notificationRegistrationService,
        productAnalyticsService: productAnalyticsService,
      );
      addTearDown(cubit.close);

      final futureStatuses = cubit.stream.map((s) => s.logoutStatus).take(2).toList();
      await cubit.logout();

      expect(await futureStatuses, [SettingsLogoutStatus.inProgress, SettingsLogoutStatus.success]);
      verifyInOrder([
        () => productAnalyticsService.prepareForLogout(),
        () => notificationRegistrationService.unregisterCurrentDevice(),
        () => authSession.logoutCurrentDevice(),
      ]);
    });

    test("still logs out when push notification cleanup fails", () async {
      when(
        () => notificationRegistrationService.unregisterCurrentDevice(),
      ).thenThrow(StateError("cleanup failed"));
      when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});

      final cubit = SettingsCubit(
        authSession: authSession,
        notificationRegistrationService: notificationRegistrationService,
        productAnalyticsService: productAnalyticsService,
      );
      addTearDown(cubit.close);

      final futureStatuses = cubit.stream.map((s) => s.logoutStatus).take(2).toList();
      await cubit.logout();

      expect(await futureStatuses, [SettingsLogoutStatus.inProgress, SettingsLogoutStatus.success]);
      verify(() => notificationRegistrationService.unregisterCurrentDevice()).called(1);
      verify(() => authSession.logoutCurrentDevice()).called(1);
    });

    test("still unregisters notifications and logs out when analytics preparation fails", () async {
      when(() => productAnalyticsService.prepareForLogout()).thenThrow(StateError("analytics unavailable"));
      when(() => authSession.logoutCurrentDevice()).thenAnswer((_) async {});

      final cubit = SettingsCubit(
        authSession: authSession,
        notificationRegistrationService: notificationRegistrationService,
        productAnalyticsService: productAnalyticsService,
      );
      addTearDown(cubit.close);

      await cubit.logout();

      verifyInOrder([
        () => productAnalyticsService.prepareForLogout(),
        () => notificationRegistrationService.unregisterCurrentDevice(),
        () => authSession.logoutCurrentDevice(),
      ]);
      expect(cubit.state.logoutStatus, SettingsLogoutStatus.success);
    });

    test("emits inProgress then failure when logout throws", () async {
      when(() => authSession.logoutCurrentDevice()).thenThrow(StateError("boom"));

      final cubit = SettingsCubit(
        authSession: authSession,
        notificationRegistrationService: notificationRegistrationService,
        productAnalyticsService: productAnalyticsService,
      );
      addTearDown(cubit.close);

      final futureStatuses = cubit.stream.map((s) => s.logoutStatus).take(2).toList();
      await cubit.logout();

      expect(await futureStatuses, [SettingsLogoutStatus.inProgress, SettingsLogoutStatus.failure]);
      verifyInOrder([
        () => productAnalyticsService.prepareForLogout(),
        () => notificationRegistrationService.unregisterCurrentDevice(),
        () => authSession.logoutCurrentDevice(),
        () => notificationRegistrationService.resumeRegistrationAfterFailedLogout(),
      ]);
    });

    test("ignores duplicate logout calls while already in progress", () async {
      final completer = Completer<void>();
      when(() => authSession.logoutCurrentDevice()).thenAnswer((_) => completer.future);

      final cubit = SettingsCubit(
        authSession: authSession,
        notificationRegistrationService: notificationRegistrationService,
        productAnalyticsService: productAnalyticsService,
      );
      addTearDown(cubit.close);

      final firstLogout = cubit.logout();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.logoutStatus, SettingsLogoutStatus.inProgress);

      await cubit.logout();

      completer.complete();
      await firstLogout;

      expect(cubit.state.logoutStatus, SettingsLogoutStatus.success);
      verify(() => notificationRegistrationService.unregisterCurrentDevice()).called(1);
      verify(() => authSession.logoutCurrentDevice()).called(1);
    });
  });
}
