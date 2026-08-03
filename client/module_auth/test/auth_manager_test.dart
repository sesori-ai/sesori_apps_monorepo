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

const _sessionTokenHeaderForTest = "X-Sesori-Session-Token";

http.StreamedResponse _streamedResponse({required http.Response response}) {
  return http.StreamedResponse(
    Stream.value(response.bodyBytes),
    response.statusCode,
    contentLength: response.bodyBytes.length,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );
}

abstract interface class _MockHttpClientSend {
  Future<http.StreamedResponse> recordedSend(http.BaseRequest request);
}

class MockHttpClient extends Mock implements http.Client, _MockHttpClientSend {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is http.Request && request.method == "POST" && request.url.path.endsWith("/init")) {
      return post(request.url, headers: request.headers, body: request.body).then(
        (response) => _streamedResponse(response: response),
      );
    }

    return recordedSend(request);
  }
}

class MockTokenStorageService extends Mock implements TokenStorageService {}

class MockOAuthStorageService extends Mock implements OAuthStorageService {}

class _HangingStatusClient extends http.BaseClient {
  bool aborted = false;
  http.RequestAbortedException? abortError;
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    this.request = request;
    final response = Completer<http.StreamedResponse>();
    if (request case http.Abortable(:final abortTrigger?)) {
      unawaited(
        abortTrigger.then<void>((_) {
          aborted = true;
          abortError = http.RequestAbortedException(request.url);
          response.completeError(abortError!);
        }),
      );
    }
    return response.future;
  }
}

class _HangingInitClient extends http.BaseClient {
  bool aborted = false;
  http.RequestAbortedException? abortError;
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    this.request = request;
    final response = Completer<http.StreamedResponse>();
    if (request case http.Abortable(:final abortTrigger?)) {
      unawaited(
        abortTrigger.then<void>((_) {
          aborted = true;
          abortError = http.RequestAbortedException(request.url);
          response.completeError(abortError!);
        }),
      );
    }
    return response.future;
  }
}

/// Returns a fixed descriptor so the init body is deterministic in tests.
class FakeOAuthDeviceDescriptorProvider implements OAuthDeviceDescriptorProvider {
  @override
  Future<OAuthDeviceDescriptor> describe() async => const OAuthDeviceDescriptor(
    clientType: AuthClientType.appIos,
    device: DeviceInfo(name: "Test iPhone", osVersion: "iOS 17.5", appVersion: "1.2.0"),
  );
}

Future<OAuthSessionRestartRequiredException> _pollRestart({required AuthManager manager}) async {
  return _captureOAuthRestart(operation: manager.pollForResult());
}

Future<OAuthSessionRestartRequiredException> _captureOAuthRestart({required Future<Object?> operation}) async {
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
    registerFallbackValue(http.Request("GET", Uri.parse("https://example.com")));
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

    test("startOAuthFlow aborts a hanging init request at the absolute deadline", () async {
      final hangingClient = _HangingInitClient();
      authManager = AuthManager(
        hangingClient,
        mockTokenStorage,
        mockOAuthStorage,
        FakeOAuthDeviceDescriptorProvider(),
      );
      final deadline = DateTime.now().add(const Duration(milliseconds: 40));
      final stopwatch = Stopwatch()..start();

      Object? initError;
      try {
        await authManager.startOAuthFlow(provider: AuthProvider.github, deadline: deadline);
      } catch (error) {
        initError = error;
      }
      stopwatch.stop();

      expect(initError, isA<OAuthRequestTimeoutException>());
      final timeoutError = initError! as OAuthRequestTimeoutException;
      expect(timeoutError, isA<TimeoutException>());
      expect(timeoutError.cause, same(hangingClient.abortError));
      expect(timeoutError.uri, Uri.parse("$authBaseUrl/auth/github/init"));
      expect((timeoutError.cause as http.RequestAbortedException).uri, timeoutError.uri);
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(hangingClient.aborted, isTrue);
      expect(hangingClient.request, isA<http.AbortableRequest>());
      final request = hangingClient.request! as http.Request;
      expect(request.method, "POST");
      expect(request.url, Uri.parse("$authBaseUrl/auth/github/init"));
      expect(request.headers["Accept"], "application/json");
      expect(request.headers["Content-Type"], "application/json");
      expect(request.headers[_sessionTokenHeaderForTest], matches(RegExp(r"^[0-9a-f]{64}$")));
      expect(jsonDecode(request.body), {
        "clientType": "app_ios",
        "device": {"name": "Test iPhone", "osVersion": "iOS 17.5", "appVersion": "1.2.0"},
      });
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
        operation: authManager.startOAuthFlow(provider: AuthProvider.github, deadline: deadline),
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
        () => mockHttpClient.send(any()),
      ).thenAnswer((_) async => _streamedResponse(response: await staleResponse.future));

      await authManager.startOAuthFlow(provider: AuthProvider.github, deadline: null);
      final stalePoll = authManager.pollForResult();
      await untilCalled(() => mockHttpClient.send(any()));
      await authManager.startOAuthFlow(provider: AuthProvider.google, deadline: null);
      final replacementToken = storedSession.sessionToken;
      final staleFailure = expectLater(stalePoll, throwsA(isA<Exception>()));
      staleResponse.complete(http.Response("not-json", 503, headers: {"retry-after": "0"}));
      await staleFailure;

      expect(replacementToken, isNotNull);
      expect(storedSession.sessionToken, replacementToken);
      verifyNever(mockOAuthStorage.clearOAuthSession);
    });

    test("a delayed stored-session read cannot adopt a replacement owner or deadline", () async {
      final oldDeadline = DateTime.now().add(const Duration(minutes: 1));
      final replacementDeadline = DateTime.now().add(const Duration(minutes: 4));
      final storedSessionRead = Completer<({String? sessionToken, DateTime? expiresAt})>();
      var storedSession = (sessionToken: "old-session-token" as String?, expiresAt: oldDeadline as DateTime?);
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer((_) => storedSessionRead.future);
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
          jsonEncode({"authUrl": "https://example.com/login", "state": "replacement", "expiresIn": 300}),
          200,
        ),
      );
      http.BaseRequest? statusRequest;
      when(
        () => mockHttpClient.send(any()),
      ).thenAnswer((invocation) async {
        statusRequest = invocation.positionalArguments.single as http.BaseRequest;
        return _streamedResponse(
          response: http.Response("not-json", 503, headers: {"retry-after": "0"}),
        );
      });

      final stalePoll = authManager.pollForResult();
      final staleFailure = expectLater(
        stalePoll,
        throwsA(allOf(isA<Exception>(), isNot(isA<OAuthSessionRestartRequiredException>()))),
      );
      await untilCalled(mockOAuthStorage.getOAuthSession);
      final replacement = authManager.startOAuthFlow(
        provider: AuthProvider.google,
        deadline: replacementDeadline,
      );
      await Future<void>.delayed(Duration.zero);
      storedSessionRead.complete((sessionToken: "old-session-token", expiresAt: oldDeadline));

      await replacement;
      await staleFailure;

      expect(statusRequest?.headers[_sessionTokenHeaderForTest], "old-session-token");
      expect(storedSession.expiresAt, replacementDeadline);
      expect(storedSession.sessionToken, isNot("old-session-token"));
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

    test("a cleanup timeout preserves the original init failure", () async {
      final cleanup = Completer<void>();
      when(
        () => mockHttpClient.post(
          Uri.parse("$authBaseUrl/auth/github/init"),
          headers: any(named: "headers"),
          body: any(named: "body"),
        ),
      ).thenAnswer((_) async => http.Response("upstream failed", 500));
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) => cleanup.future);

      Object? captured;
      try {
        await authManager.startOAuthFlow(
          provider: AuthProvider.github,
          deadline: DateTime.now().add(const Duration(milliseconds: 100)),
        );
      } catch (error) {
        captured = error;
      }

      expect(captured, isNot(isA<TimeoutException>()));
      expect(captured.toString(), contains("Failed to start GitHub auth flow"));
      cleanup.complete();
      await Future<void>.delayed(Duration.zero);
    });

    test("a failed poison cleanup is retried before OAuth mutations resume", () async {
      final firstSave = Completer<void>();
      var saveCount = 0;
      var clearCount = 0;
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
        clearCount += 1;
        if (clearCount == 1) {
          throw Exception("transient secure-storage failure");
        }
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

      final timedOutStart = authManager.startOAuthFlow(
        provider: AuthProvider.github,
        deadline: DateTime.now().add(const Duration(milliseconds: 30)),
      );
      await untilCalled(
        () => mockOAuthStorage.saveOAuthSession(
          sessionToken: any(named: "sessionToken"),
          expiresAt: any(named: "expiresAt"),
        ),
      );
      await expectLater(timedOutStart, throwsA(isA<TimeoutException>()));

      await expectLater(
        authManager.startOAuthFlow(
          provider: AuthProvider.google,
          deadline: DateTime.now().add(const Duration(minutes: 1)),
        ),
        throwsA(isA<Exception>()),
      );
      verifyNever(mockOAuthStorage.clearOAuthSession);

      firstSave.complete();
      await untilCalled(mockOAuthStorage.clearOAuthSession);
      await Future<void>.delayed(Duration.zero);

      await authManager.startOAuthFlow(
        provider: AuthProvider.google,
        deadline: DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(clearCount, 2);
      expect(storedSession.sessionToken, isNotNull);
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
        () => mockHttpClient.send(any()),
      ).thenAnswer(
        (_) async => _streamedResponse(
          response: http.Response(
            jsonEncode({
              "status": "complete",
              "accessToken": "access",
              "refreshToken": "refresh",
              "user": user.toJson(),
            }),
            200,
          ),
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
        () => mockHttpClient.send(any()),
      ).thenAnswer(
        (_) async => _streamedResponse(
          response: http.Response(
            jsonEncode({
              "status": "complete",
              "accessToken": "access",
              "refreshToken": "refresh",
              "user": user.toJson(),
            }),
            200,
          ),
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
        () => mockHttpClient.send(any()),
      ).thenAnswer(
        (_) async => _streamedResponse(
          response: http.Response(
            jsonEncode({
              "status": "complete",
              "accessToken": "access",
              "refreshToken": "refresh",
              "user": user.toJson(),
            }),
            200,
          ),
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
        () => mockHttpClient.send(any()),
      ).thenAnswer((_) async {
        final testCase = cases[responseIndex++];
        return _streamedResponse(
          response: http.Response(
            "not-json",
            testCase.status,
            headers: {"retry-after": ?testCase.header},
          ),
        );
      });
      for (final testCase in cases) {
        storedSession = (
          sessionToken: "stale-session-token",
          expiresAt: testCase.fallback ? null : deadline,
        );
        final expectedDeadline = testCase.fallback ? DateTime.now().add(const Duration(minutes: 5)) : deadline;
        final exception = await _pollRestart(manager: authManager);
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
        () => mockHttpClient.send(any()),
      ).thenAnswer((_) async {
        statusCalls += 1;
        if (statusCalls == 1) {
          return _streamedResponse(
            response: http.Response(jsonEncode({"status": "pending"}), 200),
          );
        }
        return _streamedResponse(
          response: http.Response(
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
        () => mockHttpClient.send(any()),
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
        () => mockHttpClient.send(any()),
      ).thenAnswer(
        (_) async => _streamedResponse(
          response: http.Response(
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
        () => mockHttpClient.send(any()),
      ).thenAnswer(
        (_) async => _streamedResponse(
          response: http.Response(
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
        () => mockHttpClient.send(any()),
      ).thenAnswer(
        (_) async => _streamedResponse(
          response: http.Response(
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
        () => mockHttpClient.send(any()),
      ).thenAnswer(
        (_) async => _streamedResponse(
          response: http.Response(jsonEncode({"status": "denied"}), 200),
        ),
      );

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
        () => mockHttpClient.send(captureAny()),
      );
      final initHeaders = initCall.captured.first as Map<String, String>;
      final pollHeaders = (pollCall.captured.first as http.BaseRequest).headers;
      expect(pollHeaders["X-Sesori-Session-Token"], initHeaders["X-Sesori-Session-Token"]);
      expect(pollHeaders["X-Sesori-Session-Token"], matches(RegExp(r"^[0-9a-f]{64}$")));
    });

    test("pollForResult surfaces status request timeout as recoverable client exception", () async {
      late http.RequestAbortedException abortError;
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
        () => mockHttpClient.send(any()),
      ).thenAnswer((invocation) {
        final request = invocation.positionalArguments.single as http.BaseRequest;
        abortError = http.RequestAbortedException(request.url);
        return Future<http.StreamedResponse>.error(abortError);
      });

      await authManager.startOAuthFlow(provider: AuthProvider.google, deadline: null);

      Object? pollError;
      try {
        await authManager.pollForResult();
      } catch (error) {
        pollError = error;
      }

      expect(
        pollError,
        isA<OAuthSessionStatusClientException>().having(
          (error) => error.uri,
          "uri",
          Uri.parse("$authBaseUrl/auth/session/status"),
        ),
      );
      final clientError = pollError! as OAuthSessionStatusClientException;
      expect(clientError, isA<http.ClientException>());
      expect(clientError.cause, same(abortError));
      expect((clientError.cause as http.RequestAbortedException).uri, abortError.uri);

      expect(await authManager.hasActiveOAuthSession(), isTrue);
      verifyNever(mockOAuthStorage.clearOAuthSession);
    });

    test("pollForResult preserves a direct timeout as the recoverable client exception cause", () async {
      final transportTimeout = TimeoutException("transport timed out", const Duration(seconds: 35));
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer(
        (_) async => (
          sessionToken: "stored-session-token",
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );
      when(
        () => mockHttpClient.send(any()),
      ).thenAnswer((_) => Future<http.StreamedResponse>.error(transportTimeout));

      Object? pollError;
      try {
        await authManager.pollForResult();
      } catch (error) {
        pollError = error;
      }

      expect(
        pollError,
        isA<OAuthSessionStatusClientException>().having(
          (error) => error.uri,
          "uri",
          Uri.parse("$authBaseUrl/auth/session/status"),
        ),
      );
      final clientError = pollError! as OAuthSessionStatusClientException;
      expect(clientError, isA<http.ClientException>());
      expect(clientError.cause, same(transportTimeout));
      expect(clientError.cause, isA<TimeoutException>());
      expect(await authManager.hasActiveOAuthSession(), isTrue);
      verifyNever(mockOAuthStorage.clearOAuthSession);
    });

    test("pollForResult treats final status request timeout as OAuth timeout", () async {
      final hangingClient = _HangingStatusClient();
      authManager = AuthManager(
        hangingClient,
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
      Object? pollError;
      try {
        await authManager.pollForResult();
      } catch (error) {
        pollError = error;
      }

      expect(
        pollError,
        isA<OAuthRequestTimeoutException>().having(
          (error) => error.message,
          "message",
          "OAuth authorization timed out",
        ),
      );
      final timeoutError = pollError! as OAuthRequestTimeoutException;
      expect(timeoutError, isA<TimeoutException>());
      expect(timeoutError.cause, same(hangingClient.abortError));
      expect(timeoutError.uri, Uri.parse("$authBaseUrl/auth/session/status"));
      expect((timeoutError.cause as http.RequestAbortedException).uri, timeoutError.uri);

      expect(hangingClient.aborted, isTrue);
      expect(hangingClient.request, isA<http.AbortableRequest>());
      verify(mockOAuthStorage.clearOAuthSession).called(1);
    });

    test("pollForResult preserves a direct timeout as the final OAuth timeout cause", () async {
      final transportTimeout = TimeoutException("transport timed out", const Duration(milliseconds: 30));
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer(
        (_) async => (
          sessionToken: "stored-session-token",
          expiresAt: DateTime.now().add(const Duration(milliseconds: 30)),
        ),
      );
      when(
        () => mockHttpClient.send(any()),
      ).thenAnswer((_) => Future<http.StreamedResponse>.error(transportTimeout));

      Object? pollError;
      try {
        await authManager.pollForResult();
      } catch (error) {
        pollError = error;
      }

      expect(
        pollError,
        isA<OAuthRequestTimeoutException>()
            .having(
              (error) => error.message,
              "message",
              "OAuth authorization timed out",
            )
            .having(
              (error) => error.uri,
              "uri",
              Uri.parse("$authBaseUrl/auth/session/status"),
            ),
      );
      final timeoutError = pollError! as OAuthRequestTimeoutException;
      expect(timeoutError, isA<TimeoutException>());
      expect(timeoutError.cause, same(transportTimeout));
      expect(timeoutError.cause, isA<TimeoutException>());
      verify(mockOAuthStorage.clearOAuthSession).called(1);
    });

    test("restart cleanup is bounded by the OAuth deadline and poisons a hung mutation", () async {
      final cleanup = Completer<void>();
      when(() => mockOAuthStorage.getOAuthSession()).thenAnswer(
        (_) async => (
          sessionToken: "stored-session-token",
          expiresAt: DateTime.now().add(const Duration(milliseconds: 40)),
        ),
      );
      when(
        () => mockHttpClient.send(any()),
      ).thenAnswer(
        (_) async => _streamedResponse(
          response: http.Response("not-json", 503, headers: {"retry-after": "0"}),
        ),
      );
      when(mockOAuthStorage.clearOAuthSession).thenAnswer((_) => cleanup.future);

      Object? pollError;
      var pollSettled = false;
      unawaited(
        authManager.pollForResult().then<void>(
          (_) => pollSettled = true,
          onError: (Object error, StackTrace _) {
            pollError = error;
            pollSettled = true;
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final pollSettledBeforeCleanup = pollSettled;
      final pollErrorBeforeCleanup = pollError;

      var retrySettled = false;
      unawaited(
        authManager
            .startOAuthFlow(
              provider: AuthProvider.google,
              deadline: DateTime.now().add(const Duration(minutes: 1)),
            )
            .then<void>(
              (_) => retrySettled = true,
              onError: (Object _, StackTrace _) => retrySettled = true,
            ),
      );
      await Future<void>.delayed(Duration.zero);
      final retrySettledBeforeCleanup = retrySettled;
      verify(mockOAuthStorage.clearOAuthSession).called(1);
      cleanup.complete();
      await Future<void>.delayed(Duration.zero);

      expect(pollSettledBeforeCleanup, isTrue);
      expect(
        pollErrorBeforeCleanup,
        isA<TimeoutException>().having(
          (error) => error.message,
          "message",
          "OAuth authorization timed out",
        ),
      );
      expect(retrySettledBeforeCleanup, isTrue);
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
          () => mockHttpClient.send(any()),
        ).thenAnswer((_) async => _streamedResponse(response: statusResponse));
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
