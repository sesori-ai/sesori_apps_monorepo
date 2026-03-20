import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  // ---------------------------------------------------------------------------
  // handleOAuthCallback
  // ---------------------------------------------------------------------------

  group("AuthRedirectService.handleOAuthCallback", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late MockAuthSession mockAuthSession;
    late MockAuthTokenProvider mockAuthTokenProvider;
    late MockConnectionService mockConnectionService;
    late AuthRedirectService service;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      mockAuthSession = MockAuthSession();
      mockAuthTokenProvider = MockAuthTokenProvider();
      mockConnectionService = MockConnectionService();
      service = AuthRedirectService(
        mockOAuthFlowProvider,
        mockAuthSession,
        mockAuthTokenProvider,
        mockConnectionService,
      );
    });

    test("returns /login when code is missing from URI", () async {
      // given
      final uri = Uri.parse("com.sesori.app://auth/callback?state=xyz");

      // when
      final result = await service.handleOAuthCallback(uri);

      // then
      expect(result, equals(AppRoute.login));
      verifyNever(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      );
      verifyNever(() => mockConnectionService.connect(any()));
    });

    test("returns /login when state is missing from URI", () async {
      // given
      final uri = Uri.parse("com.sesori.app://auth/callback?code=abc");

      // when
      final result = await service.handleOAuthCallback(uri);

      // then
      expect(result, equals(AppRoute.login));
      verifyNever(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      );
      verifyNever(() => mockConnectionService.connect(any()));
    });

    test("returns /login when exchangeCode throws", () async {
      // given
      when(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      ).thenThrow(StateError("exchange failed"));
      final uri = Uri.parse("com.sesori.app://auth/callback?code=abc&state=xyz");

      // when
      final result = await service.handleOAuthCallback(uri);

      // then
      expect(result, equals(AppRoute.login));
      verifyNever(() => mockConnectionService.connect(any()));
    });

    test("success: exchanges code, auto-connects to relay, returns /projects", () async {
      // given
      const accessToken = "access-token-abc";
      when(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      ).thenAnswer((_) async => testAuthUser());
      when(
        () => mockAuthTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenAnswer((_) async => accessToken);
      when(() => mockConnectionService.connect(any())).thenAnswer(
        (_) async => ApiResponse.success(testHealthResponse()),
      );
      final uri = Uri.parse("com.sesori.app://auth/callback?code=abc&state=xyz");

      // when
      final result = await service.handleOAuthCallback(uri);

      // then
      expect(result, equals(AppRoute.projects));
      final captured = verify(() => mockConnectionService.connect(captureAny())).captured;
      expect(captured.length, equals(1));
      final config = captured.single as ServerConnectionConfig;
      expect(config.relayHost, equals(relayHost));
      expect(config.authToken, equals(accessToken));
    });

    test("returns /projects when auto-connect returns null token after successful exchange", () async {
      // given
      when(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      ).thenAnswer((_) async => testAuthUser());
      when(
        () => mockAuthTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenAnswer((_) async => null);
      final uri = Uri.parse("com.sesori.app://auth/callback?code=abc&state=xyz");

      // when
      final result = await service.handleOAuthCallback(uri);

      // then
      expect(result, equals(AppRoute.projects));
      verifyNever(() => mockConnectionService.connect(any()));
    });

    test("returns /projects when auto-connect throws after successful exchange", () async {
      // given
      when(
        () => mockOAuthFlowProvider.exchangeCode(
          code: any(named: "code"),
          state: any(named: "state"),
          redirectUri: any(named: "redirectUri"),
        ),
      ).thenAnswer((_) async => testAuthUser());
      when(
        () => mockAuthTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenThrow(Exception("relay unavailable"));
      final uri = Uri.parse("com.sesori.app://auth/callback?code=abc&state=xyz");

      // when
      final result = await service.handleOAuthCallback(uri);

      // then
      expect(result, equals(AppRoute.projects));
    });
  });

  // ---------------------------------------------------------------------------
  // tryRestoreSession
  // ---------------------------------------------------------------------------

  group("AuthRedirectService.tryRestoreSession", () {
    late MockOAuthFlowProvider mockOAuthFlowProvider;
    late MockAuthSession mockAuthSession;
    late MockAuthTokenProvider mockAuthTokenProvider;
    late MockConnectionService mockConnectionService;
    late AuthRedirectService service;

    setUp(() {
      mockOAuthFlowProvider = MockOAuthFlowProvider();
      mockAuthSession = MockAuthSession();
      mockAuthTokenProvider = MockAuthTokenProvider();
      mockConnectionService = MockConnectionService();
      service = AuthRedirectService(
        mockOAuthFlowProvider,
        mockAuthSession,
        mockAuthTokenProvider,
        mockConnectionService,
      );
    });

    test("returns null when getCurrentUser returns null", () async {
      // given
      when(mockAuthSession.getCurrentUser).thenAnswer((_) async => null);

      // when
      final result = await service.tryRestoreSession();

      // then
      expect(result, isNull);
      verifyNever(() => mockConnectionService.connect(any()));
    });

    test("returns /projects and auto-connects when getCurrentUser succeeds", () async {
      // given
      const accessToken = "restored-access-token";
      final user = testAuthUser();
      when(mockAuthSession.getCurrentUser).thenAnswer((_) async => user);
      when(
        () => mockAuthTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenAnswer((_) async => accessToken);
      when(() => mockConnectionService.connect(any())).thenAnswer(
        (_) async => ApiResponse.success(testHealthResponse()),
      );

      // when
      final result = await service.tryRestoreSession();

      // then
      expect(result, equals(AppRoute.projects));
      final captured = verify(() => mockConnectionService.connect(captureAny())).captured;
      expect(captured.length, equals(1));
      final config = captured.single as ServerConnectionConfig;
      expect(config.relayHost, equals(relayHost));
      expect(config.authToken, equals(accessToken));
    });

    test("returns /projects when auto-connect fails after successful user restore", () async {
      // given
      final user = testAuthUser();
      when(mockAuthSession.getCurrentUser).thenAnswer((_) async => user);
      when(
        () => mockAuthTokenProvider.getFreshAccessToken(minTtl: any(named: "minTtl")),
      ).thenThrow(Exception("relay down"));

      // when
      final result = await service.tryRestoreSession();

      // then
      expect(result, equals(AppRoute.projects));
    });
  });
}
