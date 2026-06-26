import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/cubits/login/login_cubit.dart";
import "package:sesori_dart_core/src/cubits/login/login_state.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_shared/sesori_shared.dart" show AuthInitResponse, AuthProvider;

import "../../helpers/test_helpers.dart";

class MockUrlLauncher extends Mock implements UrlLauncher {}

class MockLifecycleSource extends Mock implements LifecycleSource {}

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(AuthProvider.github);
  });

  group("LoginCubit", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late MockUrlLauncher mockUrlLauncher;
    late MockAuthSession mockAuthSession;
    late MockLifecycleSource mockLifecycleSource;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      mockUrlLauncher = MockUrlLauncher();
      mockAuthSession = MockAuthSession();
      mockLifecycleSource = MockLifecycleSource();

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
      when(() => mockLifecycleSource.lifecycleStateStream).thenAnswer(
        (_) => BehaviorSubject.seeded(LifecycleState.resumed),
      );
    });

    test("initial state is LoginState.idle()", () {
      final cubit = LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource);
      expect(cubit.state, isA<LoginIdle>());
    });

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits authenticating → polling → success",
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
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
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
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
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
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
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
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
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
      act: (cubit) async {
        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);

        await cubit.loginWithProvider(AuthProvider.github);
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginFailed>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits timeout when pollForResult throws TimeoutException",
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
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
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
      act: (cubit) async {
        await cubit.loginWithProvider(AuthProvider.github);
      },
      verify: (cubit) {
        verify(() => mockOAuthFlowProvider.pollForResult()).called(1);
      },
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithApple emits authenticating then success on success",
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
      act: (cubit) async {
        when(
          () => mockAuthSession.loginWithApple(idToken: any(named: "idToken"), nonce: any(named: "nonce")),
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
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
      act: (cubit) async {
        when(
          () => mockAuthSession.loginWithApple(idToken: any(named: "idToken"), nonce: any(named: "nonce")),
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
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession, mockLifecycleSource),
      act: (cubit) async {
        when(
          () => mockAuthSession.loginWithApple(idToken: any(named: "idToken"), nonce: any(named: "nonce")),
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
