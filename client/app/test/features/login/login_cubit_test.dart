import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/cubits/login/login_cubit.dart";
import "package:sesori_dart_core/src/cubits/login/login_state.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/services/installation_analytics_service.dart";
import "package:sesori_shared/sesori_shared.dart" show AuthInitResponse, AuthProvider;

import "../../helpers/test_helpers.dart";

class MockUrlLauncher extends Mock implements UrlLauncher {}

class MockLifecycleSource extends Mock implements LifecycleSource {}

class MockInstallationAnalyticsService extends Mock implements InstallationAnalyticsService {}

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(AuthProvider.github);
    registerFallbackValue(LoginAttemptFailureCause.unknown);
  });

  group("LoginCubit", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late MockUrlLauncher mockUrlLauncher;
    late MockAuthSession mockAuthSession;
    late MockLifecycleSource mockLifecycleSource;
    late MockInstallationAnalyticsService mockInstallationAnalyticsService;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      mockUrlLauncher = MockUrlLauncher();
      mockAuthSession = MockAuthSession();
      mockLifecycleSource = MockLifecycleSource();
      mockInstallationAnalyticsService = MockInstallationAnalyticsService();

      // Default mock behaviors
      when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
      when(
        () => mockOAuthFlowProvider.startOAuthFlow(provider: any(named: "provider")),
      ).thenAnswer(
        (_) async => const AuthInitResponse(
          authUrl: "https://auth.example.com/login",
          state: "test-state",
          expiresIn: 300,
        ),
      );
      when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async => testAuthUser());
      when(
        () => mockInstallationAnalyticsService.loginAttemptStarted(provider: any(named: "provider")),
      ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
      when(
        () => mockInstallationAnalyticsService.loginAttemptCompleted(provider: any(named: "provider")),
      ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
      when(
        () => mockInstallationAnalyticsService.loginAttemptFailed(
          provider: any(named: "provider"),
          cause: any(named: "cause"),
        ),
      ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
      when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer(
        (_) => BehaviorSubject.seeded(LifecycleState.resumed),
      );
    });

    LoginCubit buildCubit() => LoginCubit(
      oAuthFlowProvider: mockOAuthFlowProvider,
      urlLauncher: mockUrlLauncher,
      authSession: mockAuthSession,
      lifecycleSource: mockLifecycleSource,
      installationAnalyticsService: mockInstallationAnalyticsService,
    );

    test("initial state is LoginState.idle()", () {
      final cubit = buildCubit();
      expect(cubit.state, isA<LoginIdle>());
    });

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits authenticating → polling → success",
      build: buildCubit,
      act: (cubit) async {
        await cubit.loginWithProvider(AuthProvider.github);
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginPolling>(),
        isA<LoginSuccess>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits authenticating then failed when startOAuthFlow throws",
      build: buildCubit,
      act: (cubit) async {
        when(
          () => mockOAuthFlowProvider.startOAuthFlow(provider: any(named: "provider")),
        ).thenThrow(Exception("Auth init failed"));

        await cubit.loginWithProvider(AuthProvider.google);
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginFailed>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "calls startOAuthFlow with correct provider",
      build: buildCubit,
      act: (cubit) async {
        await cubit.loginWithProvider(AuthProvider.github);
      },
      verify: (cubit) {
        verify(
          () => mockOAuthFlowProvider.startOAuthFlow(provider: AuthProvider.github),
        ).called(1);
      },
    );

    blocTest<LoginCubit, LoginState>(
      "calls startOAuthFlow for Google provider",
      build: buildCubit,
      act: (cubit) async {
        await cubit.loginWithProvider(AuthProvider.google);
      },
      verify: (cubit) {
        verify(
          () => mockOAuthFlowProvider.startOAuthFlow(provider: AuthProvider.google),
        ).called(1);
      },
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits failed when browser launch fails",
      build: buildCubit,
      act: (cubit) async {
        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);

        await cubit.loginWithProvider(AuthProvider.github);
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginPolling>(),
        isA<LoginFailed>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits timeout when pollForResult throws TimeoutException",
      build: buildCubit,
      act: (cubit) async {
        when(
          () => mockOAuthFlowProvider.pollForResult(),
        ).thenThrow(TimeoutException("Login timed out", const Duration(seconds: 300)));

        await cubit.loginWithProvider(AuthProvider.github);
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginPolling>(),
        isA<LoginTimeout>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "calls pollForResult after browser launch",
      build: buildCubit,
      act: (cubit) async {
        await cubit.loginWithProvider(AuthProvider.github);
      },
      verify: (cubit) {
        verify(() => mockOAuthFlowProvider.pollForResult()).called(1);
      },
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithApple emits authenticating then success on success",
      build: buildCubit,
      act: (cubit) async {
        when(
          () => mockAuthSession.loginWithApple(
            idToken: any(named: "idToken"),
            nonce: any(named: "nonce"),
          ),
        ).thenAnswer((_) async => testAuthUser());

        await cubit.loginWithApple(idToken: "apple-id-token", nonce: "nonce");
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginSuccess>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithApple emits authenticating then failed on error",
      build: buildCubit,
      act: (cubit) async {
        when(
          () => mockAuthSession.loginWithApple(
            idToken: any(named: "idToken"),
            nonce: any(named: "nonce"),
          ),
        ).thenThrow(Exception("Apple auth failed"));

        await cubit.loginWithApple(idToken: "apple-id-token", nonce: "nonce");
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginFailed>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithApple calls authSession with correct params",
      build: buildCubit,
      act: (cubit) async {
        when(
          () => mockAuthSession.loginWithApple(
            idToken: any(named: "idToken"),
            nonce: any(named: "nonce"),
          ),
        ).thenAnswer((_) async => testAuthUser());

        await cubit.loginWithApple(idToken: "apple-id-token", nonce: "raw-nonce");
      },
      verify: (cubit) {
        verify(
          () => mockAuthSession.loginWithApple(idToken: "apple-id-token", nonce: "raw-nonce"),
        ).called(1);
      },
    );
  });
}
