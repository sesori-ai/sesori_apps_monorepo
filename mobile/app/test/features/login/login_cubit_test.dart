import "package:bloc_test/bloc_test.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/cubits/login/login_cubit.dart";
import "package:sesori_dart_core/src/cubits/login/login_state.dart";
import "package:sesori_dart_core/src/platform/url_launcher.dart";

import "../../helpers/test_helpers.dart";

class MockUrlLauncher extends Mock implements UrlLauncher {}

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(OAuthProvider.github);
  });

  group("LoginCubit", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late MockUrlLauncher mockUrlLauncher;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      mockUrlLauncher = MockUrlLauncher();

      // Default mock behaviors
      when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => true);
    });

    test("initial state is LoginState.idle()", () {
      final cubit = LoginCubit(mockOAuthFlowProvider, mockUrlLauncher);
      expect(cubit.state, isA<LoginIdle>());
    });

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits authenticating then awaitingCallback on success",
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher),
      act: (cubit) async {
        when(
          () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
        ).thenAnswer((_) async => "https://github.com/login/oauth/authorize?client_id=abc");

        await cubit.loginWithProvider(OAuthProvider.github);
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginAwaitingCallback>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits authenticating then failed when getAuthorizationUrl throws",
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher),
      act: (cubit) async {
        when(
          () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
        ).thenThrow(Exception("Auth URL fetch failed"));

        await cubit.loginWithProvider(OAuthProvider.google);
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginFailed>(),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      "calls getAuthorizationUrl with correct provider and redirectUri",
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher),
      act: (cubit) async {
        when(
          () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
        ).thenAnswer((_) async => "https://auth.example.com/login");

        await cubit.loginWithProvider(OAuthProvider.github);
      },
      verify: (cubit) {
        verify(
          () => mockOAuthFlowProvider.getAuthorizationUrl(OAuthProvider.github, any()),
        ).called(1);
      },
    );

    blocTest<LoginCubit, LoginState>(
      "calls getAuthorizationUrl for Google provider",
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher),
      act: (cubit) async {
        when(
          () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
        ).thenAnswer((_) async => "https://auth.example.com/login");

        await cubit.loginWithProvider(OAuthProvider.google);
      },
      verify: (cubit) {
        verify(
          () => mockOAuthFlowProvider.getAuthorizationUrl(OAuthProvider.google, any()),
        ).called(1);
      },
    );

    blocTest<LoginCubit, LoginState>(
      "loginWithProvider emits failed when browser launch fails",
      build: () => LoginCubit(mockOAuthFlowProvider, mockUrlLauncher),
      act: (cubit) async {
        when(
          () => mockOAuthFlowProvider.getAuthorizationUrl(any(), any()),
        ).thenAnswer((_) async => "https://auth.example.com/login");
        when(() => mockUrlLauncher.launch(any())).thenAnswer((_) async => false);

        await cubit.loginWithProvider(OAuthProvider.github);
      },
      expect: () => [
        isA<LoginAuthenticating>(),
        isA<LoginFailed>(),
      ],
    );
  });
}
