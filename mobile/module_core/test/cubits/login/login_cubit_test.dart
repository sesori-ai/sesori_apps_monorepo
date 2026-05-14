import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart" show AuthSession, OAuthFlowProvider;
import "package:sesori_dart_core/src/cubits/login/login_cubit.dart";
import "package:sesori_dart_core/src/cubits/login/login_state.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockOAuthFlowProvider extends Mock implements OAuthFlowProvider {}

class MockUrlLauncher extends Mock implements UrlLauncher {}

class MockAuthSession extends Mock implements AuthSession {}

const testAuthInitResponse = AuthInitResponse(
  authUrl: "https://accounts.google.com/o/oauth2/auth",
  state: "oauth-state",
  userCode: "ABCD",
  expiresIn: 300,
);

const testAuthUser = AuthUser(
  id: "id",
  provider: "google",
  providerUserId: "user123",
  providerUsername: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProvider.google);
    registerFallbackValue(Uri.parse(redirectUri));
    registerFallbackValue(testAuthUser);
  });

  group("LoginCubit", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late MockUrlLauncher mockUrlLauncher;
    late MockAuthSession mockAuthSession;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      mockUrlLauncher = MockUrlLauncher();
      mockAuthSession = MockAuthSession();
      when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
      when(
        () => mockOAuthFlowProvider.startOAuthFlow(provider: any(named: "provider")),
      ).thenAnswer((_) async => testAuthInitResponse);
      when(() => mockOAuthFlowProvider.pollForResult()).thenAnswer((_) async => testAuthUser);
    });

    test("initial state is LoginState.idle", () {
      final cubit = LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession);
      expect(cubit.state, isA<LoginIdle>());
    });

    group("Google OAuth", () {
      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) starts OAuth flow with AuthProvider.google",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async => cubit.loginWithProvider(AuthProvider.google),
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingConfirmation>().having((state) => state.userCode, "userCode", "ABCD"),
          isA<LoginPolling>(),
          isA<LoginSuccess>(),
        ],
        verify: (_) {
          verify(
            () => mockOAuthFlowProvider.startOAuthFlow(provider: AuthProvider.google),
          ).called(1);
          verify(() => mockOAuthFlowProvider.pollForResult()).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits user code before polling then success",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async => cubit.loginWithProvider(AuthProvider.google),
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingConfirmation>().having((state) => state.userCode, "userCode", "ABCD"),
          isA<LoginPolling>(),
          isA<LoginSuccess>(),
        ],
        verify: (_) {
          verify(() => mockUrlLauncher.launch(Uri.parse(testAuthInitResponse.authUrl))).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits the polling OAuth sequence without legacy callback state",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async => cubit.loginWithProvider(AuthProvider.google),
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingConfirmation>(),
          isA<LoginPolling>(),
          isA<LoginSuccess>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits failed when startOAuthFlow throws",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.startOAuthFlow(provider: any(named: "provider")),
          ).thenThrow(Exception("network error"));
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginFailed>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits failed when browser launch returns false",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingConfirmation>(),
          isA<LoginFailed>(),
        ],
        verify: (_) {
          verifyNever(() => mockOAuthFlowProvider.pollForResult());
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits timeout when polling times out",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(() => mockOAuthFlowProvider.pollForResult()).thenThrow(TimeoutException("poll timeout"));
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingConfirmation>(),
          isA<LoginPolling>(),
          isA<LoginTimeout>(),
        ],
      );
    });

    group("Email Login", () {
      blocTest<LoginCubit, LoginState>(
        "loginWithEmail calls AuthSession.loginWithEmail with correct email/password",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(() => mockAuthSession.loginWithEmail(email: "test@example.com", password: "password123")).thenAnswer(
            (_) async => testAuthUser,
          );
          await cubit.loginWithEmail(
            email: "test@example.com",
            password: "password123",
          );
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginSuccess>(),
        ],
        verify: (_) {
          verify(() => mockAuthSession.loginWithEmail(email: "test@example.com", password: "password123")).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail emits loading then success state on successful login",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(() => mockAuthSession.loginWithEmail(email: any(named: "email"), password: any(named: "password"))).thenAnswer(
            (_) async => testAuthUser,
          );
          await cubit.loginWithEmail(
            email: "test@example.com",
            password: "password123",
          );
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginSuccess>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail emits failed state on 401 error",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockAuthSession.loginWithEmail(email: any(named: "email"), password: any(named: "password")),
          ).thenThrow(Exception("Invalid email or password"));
          await cubit.loginWithEmail(
            email: "test@example.com",
            password: "wrongpassword",
          );
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginFailed>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail shows validation error for empty email",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          await cubit.loginWithEmail(
            email: "",
            password: "password123",
          );
        },
        expect: () => [
          isA<LoginFailed>(),
        ],
        verify: (_) {
          verifyNever(() => mockAuthSession.loginWithEmail(email: any(named: "email"), password: any(named: "password")));
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail shows validation error for empty password",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          await cubit.loginWithEmail(
            email: "test@example.com",
            password: "",
          );
        },
        expect: () => [
          isA<LoginFailed>(),
        ],
        verify: (_) {
          verifyNever(() => mockAuthSession.loginWithEmail(email: any(named: "email"), password: any(named: "password")));
        },
      );
    });
  });
}
