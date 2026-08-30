import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/src/auth_config.dart";
import "package:sesori_auth/src/auth_manager.dart";
import "package:sesori_auth/src/models/auth_login_result.dart";
import "package:sesori_auth/src/models/auth_state.dart";
import "package:sesori_auth/src/platform/oauth_device_descriptor_provider.dart";
import "package:sesori_auth/src/platform/secure_storage.dart";
import "package:sesori_auth/src/storage/oauth_storage_service.dart";
import "package:sesori_auth/src/storage/token_storage_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockHttpClient() extends Mock implements http.Client;

class MockTokenStorageService() extends Mock implements TokenStorageService;

class MockOAuthStorageService() extends Mock implements OAuthStorageService;

/// Returns a fixed descriptor so the init body is deterministic in tests.
class FakeOAuthDeviceDescriptorProvider() implements OAuthDeviceDescriptorProvider {
  @override
  Future<OAuthDeviceDescriptor> describe() async => const OAuthDeviceDescriptor(
    clientType: AuthClientType.appIos,
    device: DeviceInfo(name: "Test iPhone", osVersion: "iOS 17.5", appVersion: "1.2.0"),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse("https://example.com"));
    registerFallbackValue(AuthProvider.github);
    registerFallbackValue(
      const AuthUser(id: "", provider: AuthProvider.github, providerUserId: "", providerUsername: null),
    );
  });

  late MockHttpClient mockHttpClient;
  late MockTokenStorageService mockTokenStorage;
  late MockOAuthStorageService mockOAuthStorage;
  late AuthManager authManager;

  const user = AuthUser(
    id: "user-1",
    provider: AuthProvider.github,
    providerUserId: "12345678",
    providerUsername: "testuser",
  );

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockTokenStorage = MockTokenStorageService();
    mockOAuthStorage = MockOAuthStorageService();
    authManager = AuthManager(mockHttpClient, mockTokenStorage, mockOAuthStorage, FakeOAuthDeviceDescriptorProvider());
    when(
      () => mockOAuthStorage.saveOAuthSession(
        sessionToken: any(named: "sessionToken"),
        expiresAt: any(named: "expiresAt"),
      ),
    ).thenAnswer((_) async {});
    when(() => mockOAuthStorage.getOAuthSession()).thenAnswer(
      (_) async => (sessionToken: null, expiresAt: null),
    );
    when(() => mockOAuthStorage.clearPkceVerifier()).thenAnswer((_) async {});
    when(() => mockOAuthStorage.clearAuthProvider()).thenAnswer((_) async {});
    when(() => mockOAuthStorage.clearOAuthSession()).thenAnswer((_) async {});
    when(() => mockTokenStorage.saveUser(any())).thenAnswer((_) async {});
    when(
      () => mockHttpClient.post(
        Uri.parse("$authBaseUrl/auth/session/status/ack"),
        headers: any(named: "headers"),
        body: null,
      ),
    ).thenAnswer((_) async => http.Response(jsonEncode({"success": true}), 200));
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
          "provider": user.provider.key,
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
          "provider": user.provider.key,
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
          "provider": user.provider.key,
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
              "provider": user.provider.key,
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

  group("refresh fencing", () {
    test("clears local credentials before emitting unauthenticated on refresh rejection", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "revoked-refresh-token");
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("{}", 401));

      final Completer<void> clearTokens = Completer<void>();
      when(mockTokenStorage.clearTokens).thenAnswer((_) => clearTokens.future);
      final List<AuthState> states = <AuthState>[];
      final StreamSubscription<AuthState> subscription = authManager.authStateStream.listen(states.add);

      final Future<String?> refreshed = authManager.getFreshAccessToken();
      await pumpEventQueue();

      expect(states.whereType<AuthUnauthenticated>(), isEmpty);
      verify(mockTokenStorage.clearTokens).called(1);
      clearTokens.complete();

      expect(await refreshed, isNull);
      await pumpEventQueue();
      await subscription.cancel();
      expect(authManager.currentState, const AuthState.unauthenticated());
      expect(states.last, const AuthState.unauthenticated());
    });

    test("keeps credentials for a non-definitive refresh 4xx response", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "still-valid-refresh-token");
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("{}", 429));

      expect(await authManager.getFreshAccessToken(), isNull);
      verifyNever(mockTokenStorage.clearTokens);
      expect(authManager.currentState, isA<AuthInitial>());
    });

    test("a rejected refresh cannot be restored by a new manager", () async {
      final _MemorySecureStorage storage = _MemorySecureStorage();
      final TokenStorageService tokenStorage = TokenStorageService(storage);
      final OAuthStorageService oauthStorage = OAuthStorageService(storage);
      await tokenStorage.saveTokens(
        accessToken: "old-access-token",
        refreshToken: "revoked-refresh-token",
      );
      await tokenStorage.saveUser(user);

      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("{}", 401));

      final AuthManager firstManager = AuthManager(
        mockHttpClient,
        tokenStorage,
        oauthStorage,
        FakeOAuthDeviceDescriptorProvider(),
      );
      expect(await firstManager.getFreshAccessToken(forceRefresh: true), isNull);
      expect(await storage.read(key: "access_token"), isNull);
      expect(await storage.read(key: "refresh_token"), isNull);
      expect(await storage.read(key: "auth_user"), isNull);

      final AuthManager relaunchedManager = AuthManager(
        MockHttpClient(),
        TokenStorageService(storage),
        OAuthStorageService(storage),
        FakeOAuthDeviceDescriptorProvider(),
      );
      expect(await relaunchedManager.hasLocallyValidSession(), isFalse);
      expect(await relaunchedManager.restoreLocalSession(), isFalse);
    });

    test("keeps local credentials on a refresh transport failure", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "offline-refresh-token");
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) => Future<http.Response>.error(http.ClientException("offline")));

      expect(await authManager.getFreshAccessToken(), isNull);
      verifyNever(mockTokenStorage.clearTokens);
      expect(authManager.currentState, isA<AuthInitial>());
    });

    test("a stale refresh rejection cannot clear a newer completed login", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "old-refresh-token");
      final Completer<http.Response> refreshResponse = Completer<http.Response>();
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) => refreshResponse.future);
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/email"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "accessToken": "new-login-access-token",
            "refreshToken": "new-login-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
            "accountStatus": "existing",
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "new-login-access-token",
          refreshToken: "new-login-refresh-token",
        ),
      ).thenAnswer((_) async {});
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<String?> refresh = authManager.getFreshAccessToken();
      await pumpEventQueue();
      final AuthLoginResult login = await authManager.loginWithEmail(
        email: "test@example.com",
        password: "correct-password",
      );
      expect(login.user, user);

      refreshResponse.complete(http.Response("{}", 401));
      expect(await refresh, isNull);
      await pumpEventQueue();

      verifyNever(mockTokenStorage.clearTokens);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
    });

    test("a refresh rejection cannot invalidate a login that is still completing", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "old-refresh-token");
      final Completer<http.Response> refreshResponse = Completer<http.Response>();
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) => refreshResponse.future);
      final Completer<http.Response> loginResponse = Completer<http.Response>();
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/email"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) => loginResponse.future);
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "new-login-access-token",
          refreshToken: "new-login-refresh-token",
        ),
      ).thenAnswer((_) async {});
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<String?> refresh = authManager.getFreshAccessToken();
      await pumpEventQueue();
      final Future<AuthLoginResult> login = authManager.loginWithEmail(
        email: "test@example.com",
        password: "correct-password",
      );

      refreshResponse.complete(http.Response("{}", 401));
      expect(await refresh, isNull);
      verifyNever(mockTokenStorage.clearTokens);

      loginResponse.complete(
        http.Response(
          jsonEncode({
            "accessToken": "new-login-access-token",
            "refreshToken": "new-login-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
            "accountStatus": "existing",
          }),
          200,
        ),
      );

      expect((await login).user, user);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
    });

    test("does not retain a refreshed token when logout races its awaited write", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "race-refresh-token");
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "accessToken": "race-access-token",
            "refreshToken": "race-new-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );
      final Completer<void> saveTokens = Completer<void>();
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "race-access-token",
          refreshToken: "race-new-refresh-token",
        ),
      ).thenAnswer((_) => saveTokens.future);
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<String?> refreshed = authManager.getFreshAccessToken();
      await pumpEventQueue();
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "race-access-token",
          refreshToken: "race-new-refresh-token",
        ),
      ).called(1);

      final Future<void> logout = authManager.logoutCurrentDevice();
      saveTokens.complete();

      expect(await refreshed, isNull);
      await logout;
      expect(authManager.currentState, const AuthState.unauthenticated());
      verify(mockTokenStorage.clearTokens).called(2);
    });

    test("does not write a refresh result that arrives after logout", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => "late-refresh-token");
      final Completer<http.Response> response = Completer<http.Response>();
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/refresh"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) => response.future);
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<String?> refreshed = authManager.getFreshAccessToken();
      await pumpEventQueue();
      final Future<void> logout = authManager.logoutCurrentDevice();
      await logout;
      response.complete(
        http.Response(
          jsonEncode({
            "accessToken": "late-access-token",
            "refreshToken": "late-new-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );

      expect(await refreshed, isNull);
      verifyNever(
        () => mockTokenStorage.saveTokens(
          accessToken: "late-access-token",
          refreshToken: "late-new-refresh-token",
        ),
      );
    });
  });

  group("OAuth flow", () {
    test("does not emit OAuth completion when logout races token persistence", () async {
      authManager = AuthManager(
        mockHttpClient,
        mockTokenStorage,
        mockOAuthStorage,
        FakeOAuthDeviceDescriptorProvider(),
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
            "state": "state-race",
            "userCode": "RACE",
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
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "status": "complete",
            "accessToken": "oauth-race-access-token",
            "refreshToken": "oauth-race-refresh-token",
            "accountStatus": "created",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );
      final Completer<void> saveTokens = Completer<void>();
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "oauth-race-access-token",
          refreshToken: "oauth-race-refresh-token",
        ),
      ).thenAnswer((_) => saveTokens.future);
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      await authManager.startOAuthFlow(provider: AuthProvider.google);
      final Future<AuthLoginResult> poll = authManager.pollForResult();
      await pumpEventQueue();
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "oauth-race-access-token",
          refreshToken: "oauth-race-refresh-token",
        ),
      ).called(1);

      final Future<void> logout = authManager.logoutCurrentDevice();
      saveTokens.complete();

      await expectLater(poll, throwsA(isA<Exception>()));
      await logout;
      expect(authManager.currentState, const AuthState.unauthenticated());
      verifyNever(() => mockTokenStorage.saveUser(any()));
    });

    test("startOAuthFlow creates header-only session token and sends the device descriptor", () async {
      const authUrl = "https://github.com/login/oauth/authorize?client_id=abc";
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/github/init"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({"authUrl": authUrl, "state": "state-1", "expiresIn": 300}),
          200,
        ),
      );

      final result = await authManager.startOAuthFlow(provider: AuthProvider.github);

      expect(result.authUrl, authUrl);
      expect(result.state, "state-1");
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
      expect(body, {
        "clientType": "app_ios",
        "device": {"name": "Test iPhone", "osVersion": "iOS 17.5", "appVersion": "1.2.0"},
      });
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
        FakeOAuthDeviceDescriptorProvider(),
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
            "accountStatus": "created",
            "refreshToken": "oauth-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
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
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});

      final states = <AuthState>[];
      final sub = authManager.authStateStream.listen(states.add);

      await authManager.startOAuthFlow(provider: AuthProvider.google);
      final exchangedUser = await authManager.pollForResult();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(exchangedUser.user, user);
      expect(exchangedUser.accountStatus, AccountStatus.created);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
      expect(states.last, const AuthState.authenticated(user: user));
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "oauth-access-token",
          refreshToken: "oauth-refresh-token",
        ),
      ).called(1);
      verify(() => mockTokenStorage.saveUser(user)).called(1);
      verify(mockOAuthStorage.clearPkceVerifier).called(1);
      verify(mockOAuthStorage.clearAuthProvider).called(1);
      verify(mockOAuthStorage.clearOAuthSession).called(1);
      final ackCall = verify(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/session/status/ack"),
          headers: captureAny(named: "headers"),
          body: null,
        ),
      );
      final ackHeaders = ackCall.captured.single as Map<String, String>;
      expect(ackHeaders["X-Sesori-Session-Token"], matches(RegExp(r"^[0-9a-f]{64}$")));
      verify(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/session/status"),
          headers: any(named: "headers"),
        ),
      ).called(2);
      await expectLater(authManager.pollForResult(), throwsA(isA<StateError>()));
    });

    test("pollForResult completes login (clears state, emits authenticated) when saving the user fails", () async {
      authManager = AuthManager(
        mockHttpClient,
        mockTokenStorage,
        mockOAuthStorage,
        FakeOAuthDeviceDescriptorProvider(),
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
            "state": "state-savefail",
            "userCode": "AA11",
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
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "status": "complete",
            "accessToken": "oauth-access-token",
            "accountStatus": "created",
            "refreshToken": "oauth-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "oauth-access-token",
          refreshToken: "oauth-refresh-token",
        ),
      ).thenAnswer((_) async {});
      // Tokens are already persisted above, so a user-cache write failure must
      // not abort the login: the OAuth temp state is still cleared and the
      // session still goes authenticated.
      when(() => mockTokenStorage.saveUser(any())).thenThrow(Exception("disk full"));
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});

      await authManager.startOAuthFlow(provider: AuthProvider.google);
      final exchangedUser = await authManager.pollForResult();

      expect(exchangedUser.user, user);
      expect(exchangedUser.accountStatus, AccountStatus.created);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
      verify(mockOAuthStorage.clearOAuthSession).called(1);
    });

    test("pollForResult does not ACK completion when token persistence fails", () async {
      authManager = AuthManager(
        mockHttpClient,
        mockTokenStorage,
        mockOAuthStorage,
        FakeOAuthDeviceDescriptorProvider(),
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
            "state": "state-save-token-fail",
            "userCode": "STF1",
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
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "status": "complete",
            "accessToken": "oauth-access-token",
            "accountStatus": "created",
            "refreshToken": "oauth-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "oauth-access-token",
          refreshToken: "oauth-refresh-token",
        ),
      ).thenThrow(Exception("secure storage failed"));

      await authManager.startOAuthFlow(provider: AuthProvider.google);

      await expectLater(authManager.pollForResult(), throwsA(isA<Exception>()));
      verifyNever(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/session/status/ack"),
          headers: any(named: "headers"),
          body: null,
        ),
      );
    });

    test("pollForResult ignores ACK failure after local completion", () async {
      authManager = AuthManager(
        mockHttpClient,
        mockTokenStorage,
        mockOAuthStorage,
        FakeOAuthDeviceDescriptorProvider(),
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
            "state": "state-ack-fail",
            "userCode": "ACK1",
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
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "status": "complete",
            "accessToken": "oauth-access-token",
            "accountStatus": "created",
            "refreshToken": "oauth-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "oauth-access-token",
          refreshToken: "oauth-refresh-token",
        ),
      ).thenAnswer((_) async {});
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/session/status/ack"),
          headers: any(named: "headers"),
          body: null,
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode({"error": "not_found"}), 404));

      await authManager.startOAuthFlow(provider: AuthProvider.google);
      final exchangedUser = await authManager.pollForResult();

      expect(exchangedUser.user, user);
      expect(exchangedUser.accountStatus, AccountStatus.created);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
      verify(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/session/status/ack"),
          headers: any(named: "headers"),
          body: null,
        ),
      ).called(1);
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

    test("pollForResult surfaces status request timeout as recoverable client exception", () async {
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
            "state": "state-request-timeout",
            "userCode": "RT42",
            "expiresIn": 300,
          }),
          200,
        ),
      );
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer(
        (_) async => (
          sessionToken: "stored-session-token",
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );
      when(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/session/status"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer((_) => Future<http.Response>.error(TimeoutException("status request timed out")));

      await authManager.startOAuthFlow(provider: AuthProvider.google);

      await expectLater(
        authManager.pollForResult(),
        throwsA(
          isA<http.ClientException>().having(
            (error) => error.uri,
            "uri",
            Uri.parse("$authBaseUrl/auth/session/status"),
          ),
        ),
      );

      expect(await authManager.hasActiveOAuthSession(), isTrue);
      verifyNever(mockOAuthStorage.clearOAuthSession);
    });

    test("pollForResult treats final status request timeout as OAuth timeout", () async {
      authManager = AuthManager(
        mockHttpClient,
        mockTokenStorage,
        mockOAuthStorage,
        FakeOAuthDeviceDescriptorProvider(),
        pollInterval: Duration.zero,
        delay: (_) async {},
      );
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer(
        (_) async => (
          sessionToken: "stored-session-token",
          expiresAt: DateTime.now().add(const Duration(milliseconds: 30)),
        ),
      );
      when(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/session/status"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer((_) => Completer<http.Response>().future);

      await expectLater(
        authManager.pollForResult(),
        throwsA(
          isA<TimeoutException>().having(
            (error) => error.message,
            "message",
            "OAuth authorization timed out",
          ),
        ),
      );

      verify(mockOAuthStorage.clearOAuthSession).called(1);
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
        when(
          () => mockOAuthStorage.saveOAuthSession(
            sessionToken: any(named: "sessionToken"),
            expiresAt: any(named: "expiresAt"),
          ),
        ).thenAnswer((_) async {});
        when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
        when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});
        when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});
        when(mockOAuthStorage.getOAuthSession).thenAnswer(
          (_) async => (sessionToken: null, expiresAt: null),
        );
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
        authManager = AuthManager(
          mockHttpClient,
          mockTokenStorage,
          mockOAuthStorage,
          FakeOAuthDeviceDescriptorProvider(),
        );
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
        FakeOAuthDeviceDescriptorProvider(),
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
              "provider": user.provider.key,
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
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});

      final states = <AuthState>[];
      final sub = authManager.authStateStream.listen(states.add);

      await authManager.invalidateAllSessions();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      verify(mockTokenStorage.clearTokens).called(1);
      verify(mockOAuthStorage.clearPkceVerifier).called(1);
      verify(mockOAuthStorage.clearAuthProvider).called(1);
      verify(mockOAuthStorage.clearOAuthSession).called(1);
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
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});

      final states = <AuthState>[];
      final sub = authManager.authStateStream.listen(states.add);

      await authManager.logoutCurrentDevice();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      verify(mockTokenStorage.clearTokens).called(1);
      verify(mockOAuthStorage.clearPkceVerifier).called(1);
      verify(mockOAuthStorage.clearAuthProvider).called(1);
      verify(mockOAuthStorage.clearOAuthSession).called(1);
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
            "accountStatus": "created",
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
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});

      final states = <AuthState>[];
      final sub = authManager.authStateStream.listen(states.add);

      final result = await authManager.loginWithApple(
        idToken: "apple-id-token",
        nonce: "raw-nonce",
      );

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result, isA<AuthLoginResult>());
      expect(result.accountStatus, AccountStatus.created);
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
      final savedAppleUser = verify(() => mockTokenStorage.saveUser(captureAny())).captured.single as AuthUser;
      expect(savedAppleUser.providerUsername, "testuser");
      verify(mockOAuthStorage.clearOAuthSession).called(1);
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

  group("loginWithEmail", () {
    test("does not authenticate an email result when logout races token persistence", () async {
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/email"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "accessToken": "email-race-access-token",
            "refreshToken": "email-race-refresh-token",
            "user": {
              "id": user.id,
              "provider": "email",
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
            "accountStatus": "existing",
          }),
          200,
        ),
      );
      final Completer<void> saveTokens = Completer<void>();
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "email-race-access-token",
          refreshToken: "email-race-refresh-token",
        ),
      ).thenAnswer((_) => saveTokens.future);
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<AuthLoginResult> login = authManager.loginWithEmail(
        email: "test@example.com",
        password: "correct-password",
      );
      await pumpEventQueue();
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "email-race-access-token",
          refreshToken: "email-race-refresh-token",
        ),
      ).called(1);

      final Future<void> logout = authManager.logoutCurrentDevice();
      saveTokens.complete();

      await expectLater(login, throwsA(isA<Exception>()));
      await logout;
      verifyNever(() => mockTokenStorage.saveUser(any()));
      expect(authManager.currentState, const AuthState.unauthenticated());
    });

    test("posts to /auth/email and stores tokens and username on success", () async {
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/email"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "accessToken": "email-access-token",
            "refreshToken": "email-refresh-token",
            "user": {
              "id": user.id,
              "provider": "email",
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
            "accountStatus": "existing",
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "email-access-token",
          refreshToken: "email-refresh-token",
        ),
      ).thenAnswer((_) async {});
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});

      final result = await authManager.loginWithEmail(
        email: "test@example.com",
        password: "correct-password",
      );

      expect(result, isA<AuthLoginResult>());
      expect(result.accountStatus, AccountStatus.existing);
      expect(authManager.currentState, isA<AuthAuthenticated>());
      verify(
        () => mockTokenStorage.saveTokens(
          accessToken: "email-access-token",
          refreshToken: "email-refresh-token",
        ),
      ).called(1);
      final savedEmailUser = verify(() => mockTokenStorage.saveUser(captureAny())).captured.single as AuthUser;
      expect(savedEmailUser.providerUsername, "testuser");
    });

    test("throws on 401 invalid credentials", () async {
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/email"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("{}", 401));

      await expectLater(
        () => authManager.loginWithEmail(email: "bad@example.com", password: "wrong"),
        throwsA(isA<Exception>()),
      );
    });
  });

  group("restoreSession", () {
    test("does not overwrite a newer login when /auth/me completes later", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "restore-access-token", validityLeft: const Duration(minutes: 5)),
      );
      final Completer<http.Response> restoreResponse = Completer<http.Response>();
      when(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/me"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer((_) => restoreResponse.future);
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/email"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "accessToken": "login-access-token",
            "refreshToken": "login-refresh-token",
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
            "accountStatus": "existing",
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(
          accessToken: "login-access-token",
          refreshToken: "login-refresh-token",
        ),
      ).thenAnswer((_) async {});

      final Future<bool> restored = authManager.restoreSession();
      await pumpEventQueue();
      final AuthLoginResult login = await authManager.loginWithEmail(
        email: "test@example.com",
        password: "correct-password",
      );
      expect(login.user, user);

      restoreResponse.complete(
        http.Response(
          jsonEncode({
            "user": {
              "id": "restored-user",
              "provider": user.provider.key,
              "providerUserId": "restored-provider-id",
              "providerUsername": "restored-user",
            },
          }),
          200,
        ),
      );

      expect(await restored, isFalse);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
      verify(() => mockTokenStorage.saveUser(user)).called(1);
    });

    test("does not emit or save a user when logout supersedes /auth/me", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-access-token", validityLeft: const Duration(minutes: 5)),
      );
      final Completer<http.Response> response = Completer<http.Response>();
      when(
        () => mockHttpClient.get(
          Uri.parse("$authBaseUrl/auth/me"),
          headers: any(named: "headers"),
        ),
      ).thenAnswer((_) => response.future);
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<bool> restored = authManager.restoreSession();
      await pumpEventQueue();
      final Future<void> logout = authManager.logoutCurrentDevice();
      await logout;
      response.complete(
        http.Response(
          jsonEncode({
            "user": {
              "id": user.id,
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );

      expect(await restored, isFalse);
      verifyNever(() => mockTokenStorage.saveUser(any()));
      expect(authManager.currentState, const AuthState.unauthenticated());
    });

    test("does not emit a restored user when logout races its user-cache write", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-access-token", validityLeft: const Duration(minutes: 5)),
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
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );
      final Completer<void> saveUser = Completer<void>();
      when(() => mockTokenStorage.saveUser(user)).thenAnswer((_) => saveUser.future);
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<bool> restored = authManager.restoreSession();
      await pumpEventQueue();
      verify(() => mockTokenStorage.saveUser(user)).called(1);

      final Future<void> logout = authManager.logoutCurrentDevice();
      saveUser.complete();

      expect(await restored, isFalse);
      await logout;
      expect(authManager.currentState, const AuthState.unauthenticated());
    });

    test("does not restore a local session when logout races the token read", () async {
      final Completer<bool> hasSession = Completer<bool>();
      when(() => mockTokenStorage.hasLocallyValidSession()).thenAnswer((_) => hasSession.future);
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<bool> restored = authManager.restoreLocalSession();
      await pumpEventQueue();
      final Future<void> logout = authManager.logoutCurrentDevice();
      hasSession.complete(true);

      expect(await restored, isFalse);
      await logout;
      verifyNever(() => mockTokenStorage.getUser());
      expect(authManager.currentState, const AuthState.unauthenticated());
    });

    test("does not emit a local user when logout races the final restore read", () async {
      when(() => mockTokenStorage.hasLocallyValidSession()).thenAnswer((_) async => true);
      final Completer<AuthUser?> userRead = Completer<AuthUser?>();
      when(() => mockTokenStorage.getUser()).thenAnswer((_) => userRead.future);
      when(mockTokenStorage.clearTokens).thenAnswer((_) async {});

      final Future<bool> restored = authManager.restoreLocalSession();
      await pumpEventQueue();
      verify(() => mockTokenStorage.getUser()).called(1);
      final Future<void> logout = authManager.logoutCurrentDevice();
      userRead.complete(user);

      expect(await restored, isFalse);
      await logout;
      expect(authManager.currentState, const AuthState.unauthenticated());
    });

    test("persists the username after restoring from /auth/me", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-access-token", validityLeft: const Duration(minutes: 5)),
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
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );

      final result = await authManager.restoreSession();

      expect(result, isTrue);
      expect(authManager.currentState, isA<AuthAuthenticated>());
      verify(() => mockTokenStorage.saveUser(user)).called(1);
    });

    test("still authenticates when persisting the restored user fails", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer(
        (_) async => (token: "valid-access-token", validityLeft: const Duration(minutes: 5)),
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
              "provider": user.provider.key,
              "providerUserId": user.providerUserId,
              "providerUsername": user.providerUsername,
            },
          }),
          200,
        ),
      );
      // A transient secure-storage write failure must not block restoring a
      // session that /auth/me just confirmed.
      when(() => mockTokenStorage.saveUser(any())).thenThrow(Exception("disk full"));

      final result = await authManager.restoreSession();

      expect(result, isTrue);
      expect(authManager.currentState, isA<AuthAuthenticated>());
    });

    test("returns false and does not persist username when no valid session", () async {
      when(() => mockTokenStorage.getAccessToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => null);

      final result = await authManager.restoreSession();

      expect(result, isFalse);
      verifyNever(() => mockTokenStorage.saveUser(any()));
    });
  });

  group("restoreLocalSession", () {
    test("emits authenticated from the stored user without any network call", () async {
      when(() => mockTokenStorage.hasLocallyValidSession()).thenAnswer((_) async => true);
      when(() => mockTokenStorage.getUser()).thenAnswer((_) async => user);

      final restored = await authManager.restoreLocalSession();

      expect(restored, isTrue);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
      verifyNever(
        () => mockHttpClient.get(any(), headers: any(named: "headers")),
      );
    });

    test("returns false and leaves state untouched when no local session", () async {
      when(() => mockTokenStorage.hasLocallyValidSession()).thenAnswer((_) async => false);

      final restored = await authManager.restoreLocalSession();

      expect(restored, isFalse);
      expect(authManager.currentState, isA<AuthInitial>());
      verifyNever(() => mockTokenStorage.getUser());
    });

    test("returns false when a session is valid but no user is stored", () async {
      when(() => mockTokenStorage.hasLocallyValidSession()).thenAnswer((_) async => true);
      when(() => mockTokenStorage.getUser()).thenAnswer((_) async => null);

      final restored = await authManager.restoreLocalSession();

      expect(restored, isFalse);
      expect(authManager.currentState, isA<AuthInitial>());
    });
  });
}

class _MemorySecureStorage() implements SecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}
