import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/src/auth_config.dart";
import "package:sesori_auth/src/auth_manager.dart";
import "package:sesori_auth/src/models/auth_state.dart";
import "package:sesori_auth/src/platform/oauth_device_descriptor_provider.dart";
import "package:sesori_auth/src/storage/oauth_storage_service.dart";
import "package:sesori_auth/src/storage/token_storage_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockHttpClient extends Mock implements http.Client {}

class MockTokenStorageService extends Mock implements TokenStorageService {}

class MockOAuthStorageService extends Mock implements OAuthStorageService {}

/// Returns a fixed descriptor so the init body is deterministic in tests.
class FakeOAuthDeviceDescriptorProvider implements OAuthDeviceDescriptorProvider {
  @override
  Future<OAuthDeviceDescriptor> describe() async => const OAuthDeviceDescriptor(
    clientType: AuthClientType.appIos,
    device: DeviceInfo(name: "Test iPhone", osVersion: "iOS 17.5", appVersion: "1.2.0"),
  );
}

Future<OAuthSessionRestartRequiredException> _pollRestart(AuthManager manager) async {
  return _captureOAuthRestart(manager.pollForResult());
}

Future<OAuthSessionRestartRequiredException> _captureOAuthRestart(Future<Object?> operation) async {
  try {
    await operation;
  } on OAuthSessionRestartRequiredException catch (error) {
    return error;
  }
  fail("Expected OAuth restart");
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

  group("OAuth flow", () {
    test("startOAuthFlow creates header-only session token and sends the device descriptor", () async {
      const authUrl = "https://github.com/login/oauth/authorize?client_id=abc";
      final deadline = DateTime.now().add(const Duration(seconds: 20));
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

      final result = await authManager.startOAuthFlow(provider: AuthProvider.github, deadline: deadline);

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
      final savedExpiry = verify(
        () => mockOAuthStorage.saveOAuthSession(
          sessionToken: any(named: "sessionToken"),
          expiresAt: captureAny(named: "expiresAt"),
        ),
      ).captured.single;
      expect(savedExpiry, deadline);
      verifyNever(
        () => mockOAuthStorage.saveAuthProviderAndPkceVerifier(
          codeVerifier: any(named: "codeVerifier"),
          provider: any(named: "provider"),
        ),
      );
    });

    test("init 503 clears its session and exposes bounded restart timing before parsing JSON", () async {
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/github/init"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("not-json", 503, headers: {"retry-after": "2"}));

      final restart = await _captureOAuthRestart(
        authManager.startOAuthFlow(provider: AuthProvider.github, deadline: deadline),
      );

      expect(restart.restartAfter, const Duration(seconds: 2));
      expect(restart.deadline, deadline);
      verify(mockOAuthStorage.clearOAuthSession).called(1);
      verifyNever(
        () => mockOAuthStorage.saveOAuthSession(
          sessionToken: any(named: "sessionToken"),
          expiresAt: any(named: "expiresAt"),
        ),
      );
    });

    test("a stale status response cannot clear a replacement OAuth session", () async {
      final staleResponse = Completer<http.Response>();
      var storedSession = (sessionToken: null as String?, expiresAt: null as DateTime?);
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer((_) async => storedSession);
      when(
        () => mockOAuthStorage.saveOAuthSession(
          sessionToken: any(named: "sessionToken"),
          expiresAt: any(named: "expiresAt"),
        ),
      ).thenAnswer((invocation) async {
        storedSession = (
          sessionToken: invocation.namedArguments[#sessionToken] as String,
          expiresAt: invocation.namedArguments[#expiresAt] as DateTime,
        );
      });
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {
        storedSession = (sessionToken: null, expiresAt: null);
      });
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({"authUrl": "https://example.com/login", "state": "state", "expiresIn": 300}),
          200,
        ),
      );
      when(
        () => mockHttpClient.get(any(), headers: any(named: "headers")),
      ).thenAnswer((_) => staleResponse.future);

      await authManager.startOAuthFlow(provider: AuthProvider.github, deadline: null);
      final stalePoll = authManager.pollForResult();
      await untilCalled(() => mockHttpClient.get(any(), headers: any(named: "headers")));
      await authManager.startOAuthFlow(provider: AuthProvider.google, deadline: null);
      final replacementToken = storedSession.sessionToken;
      final staleFailure = expectLater(stalePoll, throwsA(isA<Exception>()));
      staleResponse.complete(http.Response("not-json", 503, headers: {"retry-after": "0"}));
      await staleFailure;

      expect(replacementToken, isNotNull);
      expect(storedSession.sessionToken, replacementToken);
      verifyNever(mockOAuthStorage.clearOAuthSession);
    });

    test("a timed-out session save poisons retries until one owned cleanup completes", () async {
      final firstSave = Completer<void>();
      var saveCount = 0;
      var storedSession = (sessionToken: null as String?, expiresAt: null as DateTime?);
      when(
        () => mockOAuthStorage.saveOAuthSession(
          sessionToken: any(named: "sessionToken"),
          expiresAt: any(named: "expiresAt"),
        ),
      ).thenAnswer((invocation) async {
        if (saveCount++ == 0) {
          await firstSave.future;
        }
        storedSession = (
          sessionToken: invocation.namedArguments[#sessionToken] as String,
          expiresAt: invocation.namedArguments[#expiresAt] as DateTime,
        );
      });
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {
        storedSession = (sessionToken: null, expiresAt: null);
      });
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({"authUrl": "https://example.com/login", "state": "state", "expiresIn": 300}),
          200,
        ),
      );

      final firstStart = authManager.startOAuthFlow(
        provider: AuthProvider.github,
        deadline: DateTime.now().add(const Duration(milliseconds: 30)),
      );
      await untilCalled(
        () => mockOAuthStorage.saveOAuthSession(
          sessionToken: any(named: "sessionToken"),
          expiresAt: any(named: "expiresAt"),
        ),
      );
      var replacementCompleted = false;
      final replacement = authManager
          .startOAuthFlow(
            provider: AuthProvider.google,
            deadline: DateTime.now().add(const Duration(minutes: 1)),
          )
          .whenComplete(() => replacementCompleted = true);

      await expectLater(firstStart, throwsA(isA<TimeoutException>()));
      expect(replacementCompleted, isFalse);
      expect(storedSession.sessionToken, isNull);
      verifyNever(mockOAuthStorage.clearOAuthSession);
      for (var attempt = 0; attempt < 3; attempt += 1) {
        await expectLater(
          authManager.startOAuthFlow(
            provider: AuthProvider.google,
            deadline: DateTime.now().add(const Duration(minutes: 1)),
          ),
          throwsA(isA<Exception>()),
        );
      }

      final replacementFailure = expectLater(replacement, throwsA(isA<Exception>()));
      firstSave.complete();
      await replacementFailure;
      await untilCalled(mockOAuthStorage.clearOAuthSession);

      await authManager.startOAuthFlow(
        provider: AuthProvider.google,
        deadline: DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(replacementCompleted, isTrue);
      expect(storedSession.sessionToken, isNotNull);
      verify(mockOAuthStorage.clearOAuthSession).called(1);
    });

    test("OAuth completion is atomic with respect to a replacement start", () async {
      final tokenSave = Completer<void>();
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({"authUrl": "https://example.com/login", "state": "state", "expiresIn": 300}),
          200,
        ),
      );
      when(
        () => mockHttpClient.get(any(), headers: any(named: "headers")),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "status": "complete",
            "accessToken": "access",
            "refreshToken": "refresh",
            "user": user.toJson(),
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(accessToken: "access", refreshToken: "refresh"),
      ).thenAnswer((_) => tokenSave.future);
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});

      await authManager.startOAuthFlow(provider: AuthProvider.github, deadline: null);
      final completion = authManager.pollForResult();
      await untilCalled(
        () => mockTokenStorage.saveTokens(accessToken: "access", refreshToken: "refresh"),
      );
      var replacementCompleted = false;
      final replacement = authManager
          .startOAuthFlow(provider: AuthProvider.google, deadline: null)
          .whenComplete(() => replacementCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(replacementCompleted, isFalse);

      tokenSave.complete();
      expect(await completion, user);
      await replacement;

      expect(authManager.currentState, const AuthState.authenticated(user: user));
      expect(replacementCompleted, isTrue);
    });

    test("completion that wins before the deadline cannot later become a timeout", () async {
      final tokenSave = Completer<void>();
      var storedSession = (sessionToken: null as String?, expiresAt: null as DateTime?);
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer((_) async => storedSession);
      when(
        () => mockOAuthStorage.saveOAuthSession(
          sessionToken: any(named: "sessionToken"),
          expiresAt: any(named: "expiresAt"),
        ),
      ).thenAnswer((invocation) async {
        storedSession = (
          sessionToken: invocation.namedArguments[#sessionToken] as String,
          expiresAt: invocation.namedArguments[#expiresAt] as DateTime,
        );
      });
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({"authUrl": "https://example.com/login", "state": "state", "expiresIn": 300}),
          200,
        ),
      );
      when(
        () => mockHttpClient.get(any(), headers: any(named: "headers")),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "status": "complete",
            "accessToken": "access",
            "refreshToken": "refresh",
            "user": user.toJson(),
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(accessToken: "access", refreshToken: "refresh"),
      ).thenAnswer((_) => tokenSave.future);
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});

      await authManager.startOAuthFlow(
        provider: AuthProvider.github,
        deadline: DateTime.now().add(const Duration(milliseconds: 80)),
      );
      var completed = false;
      final completion = authManager.pollForResult().whenComplete(() => completed = true);
      await untilCalled(
        () => mockTokenStorage.saveTokens(accessToken: "access", refreshToken: "refresh"),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(completed, isFalse);

      tokenSave.complete();

      expect(await completion, user);
      expect(authManager.currentState, const AuthState.authenticated(user: user));
    });

    test("a poisoned queued replacement cannot override committed completion", () async {
      final tokenSave = Completer<void>();
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({"authUrl": "https://example.com/login", "state": "state", "expiresIn": 300}),
          200,
        ),
      );
      when(
        () => mockHttpClient.get(any(), headers: any(named: "headers")),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            "status": "complete",
            "accessToken": "access",
            "refreshToken": "refresh",
            "user": user.toJson(),
          }),
          200,
        ),
      );
      when(
        () => mockTokenStorage.saveTokens(accessToken: "access", refreshToken: "refresh"),
      ).thenAnswer((_) => tokenSave.future);
      when(mockOAuthStorage.clearPkceVerifier).thenAnswer((_) async {});
      when(mockOAuthStorage.clearAuthProvider).thenAnswer((_) async {});
      final states = <AuthState>[];
      final subscription = authManager.authStateStream.listen(states.add);

      await authManager.startOAuthFlow(provider: AuthProvider.github, deadline: null);
      final completion = authManager.pollForResult();
      await untilCalled(
        () => mockTokenStorage.saveTokens(accessToken: "access", refreshToken: "refresh"),
      );
      final replacement = authManager.startOAuthFlow(
        provider: AuthProvider.google,
        deadline: DateTime.now().add(const Duration(milliseconds: 30)),
      );
      await expectLater(replacement, throwsA(isA<TimeoutException>()));

      tokenSave.complete();

      expect(await completion, user);
      await Future<void>.delayed(Duration.zero);
      expect(states.whereType<AuthAuthenticated>().toList(), [const AuthState.authenticated(user: user)]);
      await subscription.cancel();
    });

    test("503 and 404 clear storage and expose bounded restart timing before parsing JSON", () async {
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      final cases = <({int status, String? header, Duration delay, bool fallback})>[
        (status: 503, header: "0", delay: Duration.zero, fallback: true),
        (status: 503, header: "5", delay: const Duration(seconds: 5), fallback: false),
        (status: 503, header: null, delay: const Duration(seconds: 1), fallback: false),
        (status: 503, header: "-1", delay: const Duration(seconds: 1), fallback: false),
        (status: 503, header: "6", delay: const Duration(seconds: 1), fallback: false),
        (status: 404, header: "5", delay: Duration.zero, fallback: false),
      ];
      var responseIndex = 0;
      var storedSession = (sessionToken: null as String?, expiresAt: null as DateTime?);
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer((_) async => storedSession);
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {
        storedSession = (sessionToken: null, expiresAt: null);
      });
      when(
        () => mockHttpClient.get(any(), headers: any(named: "headers")),
      ).thenAnswer((_) async {
        final testCase = cases[responseIndex++];
        return http.Response(
          "not-json",
          testCase.status,
          headers: {"retry-after": ?testCase.header},
        );
      });
      for (final testCase in cases) {
        storedSession = (
          sessionToken: "stale-session-token",
          expiresAt: testCase.fallback ? null : deadline,
        );
        final expectedDeadline = testCase.fallback ? DateTime.now().add(const Duration(minutes: 5)) : deadline;
        final exception = await _pollRestart(authManager);
        expect(exception.restartAfter, testCase.delay);
        expect(
          exception.deadline.difference(expectedDeadline).abs(),
          lessThan(const Duration(milliseconds: 100)),
        );
        expect(storedSession.sessionToken, isNull);
      }
      await expectLater(authManager.pollForResult(), throwsA(isA<StateError>()));
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

      await authManager.startOAuthFlow(provider: AuthProvider.google, deadline: null);
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

      await authManager.startOAuthFlow(provider: AuthProvider.google, deadline: null);
      final exchangedUser = await authManager.pollForResult();

      expect(exchangedUser, user);
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

      await authManager.startOAuthFlow(provider: AuthProvider.google, deadline: null);

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

      await authManager.startOAuthFlow(provider: AuthProvider.google, deadline: null);
      final exchangedUser = await authManager.pollForResult();

      expect(exchangedUser, user);
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

      await authManager.startOAuthFlow(provider: AuthProvider.github, deadline: null);
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

      await authManager.startOAuthFlow(provider: AuthProvider.google, deadline: null);

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
        when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) async {});
        when(mockOAuthStorage.getOAuthSession).thenAnswer(
          (_) async => (sessionToken: null, expiresAt: null),
        );
        await authManager.startOAuthFlow(provider: AuthProvider.github, deadline: null);
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
        pollTimeout: const Duration(milliseconds: 20),
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

      expect(result, isA<AuthUser>());
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
