import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/src/auth_config.dart";
import "package:sesori_auth/src/auth_manager.dart";
import "package:sesori_auth/src/models/auth_state.dart";
import "package:sesori_auth/src/storage/oauth_storage_service.dart";
import "package:sesori_auth/src/storage/token_storage_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockHttpClient extends Mock implements http.Client {}

class MockTokenStorageService extends Mock implements TokenStorageService {}

class MockOAuthStorageService extends Mock implements OAuthStorageService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse("https://example.com"));
    registerFallbackValue(AuthProvider.github);
  });

  late MockHttpClient mockHttpClient;
  late MockTokenStorageService mockTokenStorage;
  late MockOAuthStorageService mockOAuthStorage;
  late AuthManager authManager;

  const user = AuthUser(
    id: "user-1",
    provider: "github",
    providerUserId: "12345678",
    providerUsername: "testuser",
  );

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockTokenStorage = MockTokenStorageService();
    mockOAuthStorage = MockOAuthStorageService();
    authManager = AuthManager(mockHttpClient, mockTokenStorage, mockOAuthStorage);
  });

  group("getFreshAccessToken", () {
    test("returns cached token when validity is safely above 90 seconds", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "cached-access-token", validityLeft: const Duration(minutes: 5)),
      );

      final token = await authManager.getFreshAccessToken();

      expect(token, "cached-access-token");
      verify(() => mockTokenStorage.getAccessToken()).called(1);
      verifyNever(() => mockTokenStorage.getRefreshToken());
      verifyNever(
        () => mockHttpClient.post(
          any(),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      );
    });

    test("refreshes synchronously when access token is missing/expired", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "refresh-123");

      final responseBody = jsonEncode({
        "accessToken": "new-access-token",
        "refreshToken": "new-refresh-token",
        "user": {
          "id": user.id,
          "provider": user.provider,
          "providerUserId": user.providerUserId,
          "providerUsername": user.providerUsername,
        },
      });
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response(responseBody, 200));
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "new-access-token",
          refreshToken: "new-refresh-token",
        ),
      ).thenAnswer((_) async {});

      final token = await authManager.getFreshAccessToken();

      expect(token, "new-access-token");
      verify(() => mockTokenStorage.getRefreshToken()).called(1);
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "new-access-token",
          refreshToken: "new-refresh-token",
        ),
      ).called(1);
    });

    test("triggers background refresh when token validity is under 90 seconds", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "current-token", validityLeft: const Duration(seconds: 60)),
      );
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "refresh-bg");

      final refreshBody = jsonEncode({
        "accessToken": "bg-access-token",
        "refreshToken": "bg-refresh-token",
        "user": {
          "id": user.id,
          "provider": user.provider,
          "providerUserId": user.providerUserId,
          "providerUsername": user.providerUsername,
        },
      });
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response(refreshBody, 200));
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "bg-access-token",
          refreshToken: "bg-refresh-token",
        ),
      ).thenAnswer((_) async {});

      final token = await authManager.getFreshAccessToken();

      expect(token, "current-token");
      await Future<void>.delayed(Duration.zero);
      verify(() => mockTokenStorage.getRefreshToken()).called(1);
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "bg-access-token",
          refreshToken: "bg-refresh-token",
        ),
      ).called(1);
    });

    test("forceRefresh: bypasses cache and triggers refresh even when token is valid", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-token", validityLeft: const Duration(minutes: 10)),
      );
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "refresh-force");

      final refreshBody = jsonEncode({
        "accessToken": "force-refreshed-token",
        "refreshToken": "new-refresh-token",
        "user": {
          "id": user.id,
          "provider": user.provider,
          "providerUserId": user.providerUserId,
          "providerUsername": user.providerUsername,
        },
      });
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response(refreshBody, 200));
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "force-refreshed-token",
          refreshToken: "new-refresh-token",
        ),
      ).thenAnswer((_) async {});

      final token = await authManager.getFreshAccessToken(forceRefresh: true);

      expect(token, "force-refreshed-token");
      verifyNever(() => mockTokenStorage.getAccessToken());
      verify(() => mockTokenStorage.getRefreshToken()).called(1);
      verify(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).called(1);
    });

    test("uses singleflight refresh for concurrent refresh requests", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "refresh-singleflight");

      final refreshResponseCompleter = Completer<http.Response>();
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) => refreshResponseCompleter.future);
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "singleflight-access",
          refreshToken: "singleflight-refresh",
        ),
      ).thenAnswer((_) async {});

      final first = authManager.getFreshAccessToken();
      final second = authManager.getFreshAccessToken();

      refreshResponseCompleter.complete(
        http.Response(
          jsonEncode({
            "accessToken": "singleflight-access",
            "refreshToken": "singleflight-refresh",
            "user": {
              "id": user.id,
              "provider": user.provider,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );

      final tokens = await Future.wait([first, second]);

      expect(tokens, ["singleflight-access", "singleflight-access"]);
      verify(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).called(1);
      verify(() => mockTokenStorage.getRefreshToken()).called(1);
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "singleflight-access",
          refreshToken: "singleflight-refresh",
        ),
      ).called(1);
    });
  });

  group("OAuth flow", () {
    test("startOAuthFlow creates header-only session token and returns user code details", () async {
      const authUrl = "https://github.com/login/oauth/authorize?client_id=abc";
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/github/init"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({"authUrl": authUrl, "state": "state-1", "userCode": "A1B2", "expiresIn": 300}),
          200,
        ),
      );

      final result = await authManager.startOAuthFlow(provider: AuthProvider.github);

      expect(result.authUrl, authUrl);
      expect(result.state, "state-1");
      expect(result.userCode, "A1B2");
      expect(result.expiresIn, 300);

      final capturedPostCall = verify(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/github/init"),
          headers: captureAny(named: "headers"),
          body: captureAny(named: "body"),
        ),
      );
      final headers = capturedPostCall.captured[0] as Map<String, String>;
      final body = jsonDecode(capturedPostCall.captured[1] as String) as Map<String, dynamic>;
      final sessionToken = headers["X-Sesori-Session-Token"];
      expect(sessionToken, matches(RegExp(r"^[0-9a-f]{64}$")));
      expect(headers["Content-Type"], "application/json");
      expect(body, {"clientType": "app"});
      expect(body.values, isNot(contains(sessionToken)));
      verifyNever(
        () => mockOAuthStorage.saveAuthProviderAndPkceVerifier(
          codeVerifier: any(named: "codeVerifier"),
          provider: any(named: "provider"),
        ),
      );
    });

    test("pollForResult retries pending then stores complete tokens and emits authenticated", () async {
      authManager = AuthManager(
        mockHttpClient,
        mockTokenStorage,
        mockOAuthStorage,
        pollInterval: Duration.zero,
        delay: (_) async {},
      );

      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/google/init"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "authUrl": "https://accounts.google.com/o/oauth2/v2/auth",
            "state": "state-2",
            "userCode": "Z9Y8",
            "expiresIn": 300,
          }),
          200,
        ),
      );
      var statusCalls = 0;
      when(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/session/status"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer((_) async {
        statusCalls += 1;
        if (statusCalls == 1) {
          return http.Response(jsonEncode({"status": "pending"}), 200);
        }
        return http.Response(
          jsonEncode({
            "status": "complete",
            "accessToken": "oauth-access-token",
            "refreshToken": "oauth-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        );
      });
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "oauth-access-token",
          refreshToken: "oauth-refresh-token",
        ),
      ).thenAnswer((_) async {});
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});

      final states = <AuthState>[];
      final sub = authManager.authStateStream.listen(states.add);

      await authManager.startOAuthFlow(provider: AuthProvider.google);
      final exchangedUser = await authManager.pollForResult();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(exchangedUser, user);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
      expect(states.last, const AuthState.authenticated(user: user));
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "oauth-access-token",
          refreshToken: "oauth-refresh-token",
        ),
      ).called(1);
      verify(mockOAuthStorage.clearPkceVerifier).called(1);
      verify(mockOAuthStorage.clearAuthProvider).called(1);
      verify(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/session/status"),
          headers: any(named: "headers"),
        ),
      ).called(2);
      await expectLater(authManager.pollForResult(), throwsA(isA<StateError>()));
    });

    test("pollForResult sends the same session token only in status headers", () async {
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/github/init"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "authUrl": "https://github.com/login/oauth/authorize",
            "state": "state-3",
            "userCode": "C3D4",
            "expiresIn": 300,
          }),
          200,
        ),
      );
      when(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/session/status"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode({"status": "denied"}), 200));

      await authManager.startOAuthFlow(provider: AuthProvider.github);
      await expectLater(authManager.pollForResult(), throwsA(isA<StateError>()));

      final initCall = verify(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/github/init"),
          headers: captureAny(named: "headers"),
          body: any(named: "body"),
        ),
      );
      final pollCall = verify(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/session/status"),
          headers: captureAny(named: "headers"),
        ),
      );
      final initHeaders = initCall.captured.first as Map<String, String>;
      final pollHeaders = pollCall.captured.first as Map<String, String>;
      expect(pollHeaders["X-Sesori-Session-Token"], initHeaders["X-Sesori-Session-Token"]);
      expect(pollHeaders["X-Sesori-Session-Token"], matches(RegExp(r"^[0-9a-f]{64}$")));
    });

    test("pollForResult clears active session on denied, expired, error, and timeout", () async {
      Future<void> arrangeStartedFlow({required http.Response statusResponse}) async {
        when(
          () => mockHttpClient.post(
            Uri.parse("$authBaseUrl/auth/github/init"),
            headers: any(named: "headers"),
            body: any(named: "body"),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              "authUrl": "https://github.com/login/oauth/authorize",
              "state": "state-4",
              "userCode": "E5F6",
              "expiresIn": 300,
            }),
            200,
          ),
        );
        when(
          () => mockHttpClient.get(
            Uri.parse("$authBaseUrl/auth/session/status"),
            headers: any(named: "headers"),
          ),
        ).thenAnswer((_) async => statusResponse);
        await authManager.startOAuthFlow(provider: AuthProvider.github);
      }

      for (final statusResponse in [
        http.Response(jsonEncode({"status": "denied"}), 200),
        http.Response(jsonEncode({"status": "expired"}), 410),
        http.Response(jsonEncode({"status": "error", "message": "provider failed"}), 200),
      ]) {
        mockHttpClient = MockHttpClient();
        mockTokenStorage = MockTokenStorageService();
        mockOAuthStorage = MockOAuthStorageService();
        authManager = AuthManager(mockHttpClient, mockTokenStorage, mockOAuthStorage);
        await arrangeStartedFlow(statusResponse: statusResponse);

        await expectLater(authManager.pollForResult(), throwsA(isA<StateError>()));
        await expectLater(authManager.pollForResult(), throwsA(isA<StateError>()));
      }

      mockHttpClient = MockHttpClient();
      mockTokenStorage = MockTokenStorageService();
      mockOAuthStorage = MockOAuthStorageService();
      authManager = AuthManager(
        mockHttpClient,
        mockTokenStorage,
        mockOAuthStorage,
        pollInterval: Duration.zero,
        pollTimeout: Duration.zero,
        delay: (_) async {},
      );
      await arrangeStartedFlow(statusResponse: http.Response(jsonEncode({"status": "pending"}), 200));

      await expectLater(authManager.pollForResult(), throwsA(isA<TimeoutException>()));
      await expectLater(authManager.pollForResult(), throwsA(isA<StateError>()));
    });
  });

  group("AuthSession", () {
    test("hasLocallyValidSession delegates to token storage without HTTP", () async {
      when(mockTokenStorage.hasLocallyValidSession).thenAnswer((_) async => true);

      final result = await authManager.hasLocallyValidSession();

      expect(result, isTrue);
      verify(mockTokenStorage.hasLocallyValidSession).called(1);
      verifyNever(
        () => mockHttpClient.get(
          any(),
          headers: any(named: "headers"),
        ),
      );
      verifyNever(
        () => mockHttpClient.post(
          any(),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      );
    });

    test("getCurrentUser returns user when authenticated", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-access-token", validityLeft: const Duration(minutes: 3)),
      );
      when(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/me"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "user": {
              "id": user.id,
              "provider": user.provider,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );

      final result = await authManager.getCurrentUser();

      expect(result, user);
      final captured = verify(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/me"),
          headers: captureAny(named: "headers"),
        ),
      );
      final headers = captured.captured.first as Map<String, String>;
      expect(headers["Authorization"], "Bearer valid-access-token");
    });

    test("getCurrentUser returns null on request error", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-access-token", validityLeft: const Duration(minutes: 3)),
      );
      when(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/me"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer((_) async => http.Response("{}", 500));

      final result = await authManager.getCurrentUser();

      expect(result, isNull);
    });

    test("invalidateAllSessions clears auth data on server success", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-access-token", validityLeft: const Duration(minutes: 3)),
      );
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/logout"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("{}", 200));
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});

      final states = <AuthState>[];
      final sub = authManager.authStateStream.listen(states.add);

      await authManager.invalidateAllSessions();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      verify(mockTokenStorage.clearTokens).called(1);
      verify(mockOAuthStorage.clearPkceVerifier).called(1);
      verify(mockOAuthStorage.clearAuthProvider).called(1);
      verifyNoMoreInteractions(mockOAuthStorage);
      expect(authManager.currentState, const AuthState.unauthenticated());
      expect(states.last, const AuthState.unauthenticated());
    });

    test("invalidateAllSessions does not clear local tokens when API logout fails", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-access-token", validityLeft: const Duration(minutes: 3)),
      );
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/logout"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("{}", 500));

      await expectLater(authManager.invalidateAllSessions(), throwsA(isA<StateError>()));

      verifyNever(mockTokenStorage.clearTokens);
      verifyNever(mockOAuthStorage.clearPkceVerifier);
      verifyNever(mockOAuthStorage.clearAuthProvider);
    });

    test("logoutCurrentDevice clears local auth data without calling API", () async {
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});

      final states = <AuthState>[];
      final sub = authManager.authStateStream.listen(states.add);

      await authManager.logoutCurrentDevice();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      verify(mockTokenStorage.clearTokens).called(1);
      verify(mockOAuthStorage.clearPkceVerifier).called(1);
      verify(mockOAuthStorage.clearAuthProvider).called(1);
      verifyNever(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/logout"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      );
      expect(authManager.currentState, const AuthState.unauthenticated());
      expect(states.last, const AuthState.unauthenticated());
    });
  });

  group("loginWithApple", () {
    test("posts to /auth/apple/native and stores tokens on success", () async {
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/apple/native"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "accessToken": "apple-access-token",
            "refreshToken": "apple-refresh-token",
            "user": {
              "id": user.id,
              "provider": "apple",
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "apple-access-token",
          refreshToken: "apple-refresh-token",
        ),
      ).thenAnswer((_) async {});
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});

      final states = <AuthState>[];
      final sub = authManager.authStateStream.listen(states.add);

      final result = await authManager.loginWithApple(
        idToken: "apple-id-token",
        nonce: "raw-nonce",
      );

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result, isA<AuthUser>());
      expect(authManager.currentState, isA<AuthAuthenticated>());
      expect(states.last, isA<AuthAuthenticated>());

      final captured = verify(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/apple/native"),
          headers: any(named: "headers"),
          body: captureAny(named: "body"),
        ),
      );
      final body = jsonDecode(captured.captured.first as String) as Map<String, dynamic>;
      expect(body["idToken"], "apple-id-token");
      expect(body["nonce"], "raw-nonce");

      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "apple-access-token",
          refreshToken: "apple-refresh-token",
        ),
      ).called(1);
    });

    test("throws when server returns non-2xx", () async {
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/apple/native"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("{}", 401));

      await expectLater(
        () => authManager.loginWithApple(idToken: "token", nonce: "nonce"),
        throwsA(isA<StateError>()),
      );
    });
  });
}
