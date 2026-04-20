import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("OAuthCallbackDispatcher.handleOAuthCallback", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late OAuthCallbackDispatcher dispatcher;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      dispatcher = OAuthCallbackDispatcher(mockOAuthFlowProvider);
    });

    test("returns /login when code is missing from URI", () async {
      final uri = Uri.parse("com.sesori.app://auth/callback?state=xyz");

      final result = await dispatcher.handleOAuthCallback(uri);

      expect(result, isA<AppRouteLogin>());
      verifyNever(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      );
    });

    test("returns /login when state is missing from URI", () async {
      final uri = Uri.parse("com.sesori.app://auth/callback?code=abc");

      final result = await dispatcher.handleOAuthCallback(uri);

      expect(result, isA<AppRouteLogin>());
      verifyNever(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      );
    });

    test("returns /login when exchangeCode throws", () async {
      when(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      ).thenThrow(StateError("exchange failed"));
      final uri = Uri.parse("com.sesori.app://auth/callback?code=abc&state=xyz");

      final result = await dispatcher.handleOAuthCallback(uri);

      expect(result, isA<AppRouteLogin>());
    });

    test("returns /projects after successful code exchange", () async {
      when(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      ).thenAnswer((_) async => testAuthUser());
      final uri = Uri.parse("com.sesori.app://auth/callback?code=abc&state=xyz");

      final result = await dispatcher.handleOAuthCallback(uri);

      expect(result, isA<AppRouteProjects>());
      verify(
        () => mockOAuthFlowProvider.exchangeCode(
          code: "abc",
          state: "xyz",
          redirectUri: redirectUri,
        ),
      ).called(1);
    });
  });
}
