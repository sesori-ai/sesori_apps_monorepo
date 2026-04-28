import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/login/login_cubit.dart";
import "package:sesori_dart_core/src/cubits/login/login_state.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:test/test.dart";

class MockOAuthFlowProvider extends Mock implements OAuthFlowProvider {}

class MockUrlLauncher extends Mock implements UrlLauncher {}

class MockAuthSession extends Mock implements AuthSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(OAuthProvider.google);
    registerFallbackValue(Uri.parse(redirectUri));
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
        "loginWithProvider(OAuthProvider.google) calls getAuthorizationUrl with OAuthProvider.google",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
          ).thenAnswer((_) async => "https://accounts.google.com/o/oauth2/auth");
          await cubit.loginWithProvider(OAuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingCallback>(),
        ],
        verify: (_) {
          verify(
            () => mockOAuthFlowProvider.getAuthorizationUrl(OAuthProvider.google, redirectUri),
          ).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(OAuthProvider.google) emits authenticating then awaitingCallback on success",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
          ).thenAnswer((_) async => "https://accounts.google.com/o/oauth2/auth");
          await cubit.loginWithProvider(OAuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginAwaitingCallback>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(OAuthProvider.google) emits failed when getAuthorizationUrl throws",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
          ).thenThrow(Exception("network error"));
          await cubit.loginWithProvider(OAuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginFailed>(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        "loginWithProvider(OAuthProvider.google) emits failed when browser launch returns false",
        build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher, mockAuthSession),
        act: (cubit) async {
          when(
            () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
          ).thenAnswer((_) async => "https://accounts.google.com/o/oauth2/auth");
          when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);
          await cubit.loginWithProvider(OAuthProvider.google);
        },
        expect: () => [
          isA<LoginAuthenticating>(),
          isA<LoginFailed>(),
        ],
      );
    });
  });
}
