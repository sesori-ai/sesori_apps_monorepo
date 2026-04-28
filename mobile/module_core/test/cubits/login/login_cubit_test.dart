import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/login/login_cubit.dart";
import "package:sesori_dart_core/src/cubits/login/login_state.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockOAuthFlowProvider extends Mock implements OAuthFlowProvider {}

class MockUrlLauncher extends Mock implements UrlLauncher {}

class MockAuthSession extends Mock implements AuthSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(AuthProvider.google);
    registerFallbackValue(Uri.parse(redirectUri));
    registerFallbackValue(const AuthUser(
      id: "id",
      provider: "google",
      providerUserId: "user123",
      providerUsername: null,
    ));
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
    });

    test("initial state is LoginState.idle", () {
      final cubit = LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession);
      expect(cubit.state, isA<LoginIdle>());
    });

    group("Google OAuth", () {
      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) calls getAuthorizationUrl with AuthProvider.google",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
          ).thenAnswer((_) async => "https://accounts.google.com/o/oauth2/auth");
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingCallback>(),
        ],
        verify: (_) {
          verify(
            () => mockOAuthFlowProvider.getAuthorizationUrl(AuthProvider.google, redirectUri),
          ).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits authenticating then awaitingCallback on success",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
          ).thenAnswer((_) async => "https://accounts.google.com/o/oauth2/auth");
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingCallback>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(AuthProvider.google) emits failed when getAuthorizationUrl throws",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
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
          when(
            () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
          ).thenAnswer((_) async => "https://accounts.google.com/o/oauth2/auth");
          when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
          await cubit.loginWithProvider(AuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginFailed>(),
        ],
      );
    });

    group("Email Login", () {
      blocTest<LoginCubit, LoginState>(
        "loginWithEmail calls AuthSession.loginWithEmail with correct email/password",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(() => mockAuthSession.loginWithEmail("test@example.com", "password123"))
              .thenAnswer((_) async => const AuthUser(
                    id: "id",
                    provider: "google",
                    providerUserId: "user123",
                    providerUsername: null,
                  ));
          await cubit.loginWithEmail("test@example.com", "password123");
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginSuccess>(),
        ],
        verify: (_) {
          verify(() => mockAuthSession.loginWithEmail("test@example.com", "password123"))
              .called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail emits loading then success state on successful login",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(() => mockAuthSession.loginWithEmail(any(), any()))
              .thenAnswer((_) async => const AuthUser(
                    id: "id",
                    provider: "google",
                    providerUserId: "user123",
                    providerUsername: null,
                  ));
          await cubit.loginWithEmail("test@example.com", "password123");
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
          when(() => mockAuthSession.loginWithEmail(any(), any()))
              .thenThrow(Exception("Invalid email or password"));
          await cubit.loginWithEmail("test@example.com", "wrongpassword");
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
          await cubit.loginWithEmail("", "password123");
        },
        expect: () => [
          isA<LoginFailed>(),
        ],
        verify: (_) {
          verifyNever(() => mockAuthSession.loginWithEmail(any(), any()));
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithEmail shows validation error for empty password",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          await cubit.loginWithEmail("test@example.com", "");
        },
        expect: () => [
          isA<LoginFailed>(),
        ],
        verify: (_) {
          verifyNever(() => mockAuthSession.loginWithEmail(any(), any()));
        },
      );
    });
  });
}
