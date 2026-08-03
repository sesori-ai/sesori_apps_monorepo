// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/auth/login_email_api.dart';
import 'package:sesori_bridge/src/auth/login_email_repository.dart';
import 'package:sesori_bridge/src/auth/login_oauth_api.dart';
import 'package:sesori_bridge/src/auth/login_oauth_service.dart';
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  group('LoginOAuthApi', () {
    test('503 and 404 map to bounded restart requirements before JSON parsing', () async {
      final cases = <({int statusCode, String? retryAfter, Duration expectedDelay})>[
        (statusCode: 503, retryAfter: '0', expectedDelay: Duration.zero),
        (statusCode: 503, retryAfter: '5', expectedDelay: Duration(seconds: 5)),
        (statusCode: 503, retryAfter: null, expectedDelay: Duration(seconds: 1)),
        (statusCode: 503, retryAfter: '-1', expectedDelay: Duration(seconds: 1)),
        (statusCode: 503, retryAfter: '6', expectedDelay: Duration(seconds: 1)),
        (statusCode: 404, retryAfter: '5', expectedDelay: Duration.zero),
      ];
      final authServer = await _OAuthLongPollTestServer.start(
        statusResponses: [
          for (final testCase in cases) (statusCode: testCase.statusCode, retryAfter: testCase.retryAfter),
        ],
      );
      addTearDown(authServer.close);
      final api = LoginOAuthApi(
        authBackendUrl: authServer.baseUrl,
        client: authServer.client,
        clientType: AuthClientType.bridgeMacos,
        device: DeviceInfo(name: 'Test Mac', osVersion: null, appVersion: null),
      );
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      for (final testCase in cases) {
        final restartRequired = predicate<OAuthSessionRestartRequiredException>(
          (error) => error.restartAfter == testCase.expectedDelay && error.deadline == deadline,
        );
        await expectLater(
          api.getOAuthSessionStatus(
            sessionToken: 'stale-token',
            deadline: deadline,
            requestTimeout: const Duration(seconds: 1),
          ),
          throwsA(restartRequired),
        );
      }
    });

    test('init 503 maps to the same bounded restart requirement before JSON parsing', () async {
      final authServer = await _OAuthLongPollTestServer.start(
        initResponses: [(statusCode: 503, retryAfter: '3')],
        statusResponses: [],
      );
      addTearDown(authServer.close);
      final api = LoginOAuthApi(
        authBackendUrl: authServer.baseUrl,
        client: authServer.client,
        clientType: AuthClientType.bridgeMacos,
        device: DeviceInfo(name: 'Test Mac', osVersion: null, appVersion: null),
      );
      final deadline = DateTime.now().add(const Duration(minutes: 5));

      await expectLater(
        api.initOAuthSession(
          provider: AuthProvider.github,
          sessionToken: 'new-token',
          deadline: deadline,
          requestTimeout: const Duration(seconds: 1),
        ),
        throwsA(
          predicate<OAuthSessionRestartRequiredException>(
            (error) => error.restartAfter == const Duration(seconds: 3) && error.deadline == deadline,
          ),
        ),
      );
    });

    group('GitHub OAuth', () {
      test('performOAuthLogin initializes, opens browser, polls, and returns tokens', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [
            const AuthSessionStatusResponse.pending(),
            AuthSessionStatusResponse.complete(
              accessToken: 'github-access-token',
              refreshToken: 'github-refresh-token',
              user: AuthUser(
                id: 'user-1',
                provider: AuthProvider.github,
                providerUserId: 'gh-1',
                providerUsername: 'octocat',
              ),
            ),
          ],
        );
        addTearDown(authServer.close);
        final launchedUrls = <String>[];

        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (url) async => launchedUrls.add(url),
        );

        final result = await service.performOAuthLogin(AuthProvider.github);
        final tokens = result.tokens;

        expect(tokens.accessToken, equals('github-access-token'));
        expect(tokens.refreshToken, equals('github-refresh-token'));
        expect(tokens.lastProvider, equals(AuthProvider.github));
        expect(launchedUrls, equals(['https://example.com/github-login']));
        expect(authServer.initRequests, hasLength(1));
        expect(authServer.statusRequests, hasLength(2));
        expect(authServer.ackRequests, isEmpty);

        final initRequest = authServer.initRequests.single;
        expect(initRequest.method, equals('POST'));
        expect(initRequest.path, equals('/auth/github/init'));
        expect(initRequest.queryParameters, isEmpty);
        expect(
          initRequest.body,
          equals({
            'clientType': 'bridge_macos',
            'device': {'name': 'Test Mac', 'osVersion': 'macOS 14.5', 'appVersion': '1.2.0'},
          }),
        );
        expect(initRequest.contentType, startsWith('application/json'));
        expect(initRequest.sessionToken, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(initRequest.body!.values, isNot(contains(initRequest.sessionToken)));
        expect(authServer.authUrl, isNot(contains(initRequest.sessionToken)));

        for (final statusRequest in authServer.statusRequests) {
          expect(statusRequest.method, equals('GET'));
          expect(statusRequest.path, equals('/auth/session/status'));
          expect(statusRequest.queryParameters, isEmpty);
          expect(statusRequest.sessionToken, equals(initRequest.sessionToken));
        }
        expect(authServer.unexpectedPaths, isNot(contains('/callback')));
      });

      test('restarts once, rejects a second restart, and keeps one absolute budget', () async {
        const firstUrl = 'https://example.com/github-login-1';
        const user = AuthUser(id: 'u', provider: AuthProvider.github, providerUserId: 'g', providerUsername: null);
        final authServer = await _OAuthLongPollTestServer.start(
          authUrl: firstUrl,
          statusResponses: [
            (statusCode: 503, retryAfter: '0'),
            AuthSessionStatusResponse.complete(
              accessToken: 'access',
              refreshToken: 'refresh',
              user: user,
            ),
            (statusCode: 503, retryAfter: '0'),
            (statusCode: 404, retryAfter: null),
            (statusCode: 503, retryAfter: '1'),
            const AuthSessionStatusResponse.pending(),
          ],
        );
        addTearDown(authServer.close);
        final launchedUrls = <String>[];
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (url) async => launchedUrls.add(url),
          pollInterval: const Duration(seconds: 5),
        );
        final result = await service.performOAuthLogin(AuthProvider.github);
        final sessionTokens = authServer.initRequests.map((request) => request.sessionToken).toList();
        expect(launchedUrls, [firstUrl, '$firstUrl-restart']);
        expect((sessionTokens.length, sessionTokens.toSet().length), (2, 2));
        expect(result.sessionToken, sessionTokens.last);
        expect(authServer.statusRequests.map((request) => request.sessionToken).toList(), sessionTokens);
        await expectLater(
          service.performOAuthLogin(AuthProvider.github),
          throwsA(predicate<Exception>((error) => error.toString().contains('lost again after restart'))),
        );
        expect((authServer.initRequests.length, authServer.statusRequests.length), (4, 4));
        final stopwatch = Stopwatch()..start();
        await expectLater(service.performOAuthLogin(AuthProvider.github), throwsA(isA<TimeoutException>()));
        stopwatch.stop();
        expect((authServer.initRequests.length, authServer.statusRequests.length), (6, 6));
        expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 2600)));
      });

      test('an init 503 consumes the one full restart and then completes', () async {
        const user = AuthUser(id: 'u', provider: AuthProvider.github, providerUserId: 'g', providerUsername: null);
        final authServer = await _OAuthLongPollTestServer.start(
          initResponses: [(statusCode: 503, retryAfter: '0')],
          statusResponses: [
            AuthSessionStatusResponse.complete(
              accessToken: 'access',
              refreshToken: 'refresh',
              user: user,
            ),
          ],
        );
        addTearDown(authServer.close);
        final launchedUrls = <String>[];
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (url) async => launchedUrls.add(url),
        );

        final result = await service.performOAuthLogin(AuthProvider.github);

        expect(result.tokens.accessToken, 'access');
        expect(authServer.initRequests, hasLength(2));
        expect(authServer.statusRequests, hasLength(1));
        expect(launchedUrls, ['https://example.com/github-login-restart']);
      });

      test('a hung status request is aborted at its local timeout without accumulating another request', () async {
        final client = _HangingOAuthStatusClient();
        final api = LoginOAuthApi(
          authBackendUrl: 'https://auth.example.test',
          client: client,
          clientType: AuthClientType.bridgeMacos,
          device: DeviceInfo(name: 'Test Mac', osVersion: null, appVersion: null),
        );
        final service = LoginOAuthService(
          api: api,
          browserLauncher: (_) async {},
          browserOpenability: _alwaysOpenableBrowser,
          pollTimeout: const Duration(seconds: 1),
          perRequestTimeout: const Duration(milliseconds: 10),
          pollInterval: Duration.zero,
        );

        await expectLater(
          service.performOAuthLogin(AuthProvider.github),
          throwsA(isA<TimeoutException>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(client.statusRequestCount, 1);
        expect(client.maximumActiveStatusRequests, 1);
        expect(client.activeStatusRequests, 0);
        expect(client.statusAbortCount, 1);
      });

      for (final hangingOperation in ['init', 'browser']) {
        test('a hanging restart $hangingOperation stops at the original deadline', () async {
          final authServer = await _OAuthLongPollTestServer.start(
            initResponses: hangingOperation == 'init'
                ? [
                    (statusCode: 200, retryAfter: null),
                    (statusCode: 0, retryAfter: null),
                  ]
                : const [],
            statusResponses: [(statusCode: 503, retryAfter: '0')],
          );
          addTearDown(authServer.close);
          var launches = 0;
          final service = _createOAuthService(
            authServer: authServer,
            browserLauncher: (_) {
              launches += 1;
              return hangingOperation == 'browser' && launches == 2 ? Completer<void>().future : Future<void>.value();
            },
            pollTimeout: const Duration(milliseconds: 100),
          );
          final stopwatch = Stopwatch()..start();

          await expectLater(
            service.performOAuthLogin(AuthProvider.github),
            throwsA(isA<TimeoutException>()),
          );
          stopwatch.stop();

          expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
          expect(authServer.initRequests, hasLength(2));
          expect(launches, hangingOperation == 'browser' ? 2 : 1);
        });
      }

      test('denied status throws', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [const AuthSessionStatusResponse.denied()],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
        );

        expect(
          service.performOAuthLogin(AuthProvider.github),
          throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('denied'))),
        );
      });

      test('prints the auth URL verbatim and still completes login when the browser launcher fails', () async {
        const authUrl =
            'https://github.com/login/oauth/authorize?client_id=abc&redirect_uri=https%3A%2F%2Fapi.sesori.com%2Fauth%2Fgithub%2Fcallback&scope=read%3Auser&state=xyz';
        final authServer = await _OAuthLongPollTestServer.start(
          authUrl: authUrl,
          statusResponses: [
            AuthSessionStatusResponse.complete(
              accessToken: 'github-access-token',
              refreshToken: 'github-refresh-token',
              user: AuthUser(
                id: 'user-1',
                provider: AuthProvider.github,
                providerUserId: 'gh-1',
                providerUsername: 'octocat',
              ),
            ),
          ],
        );
        addTearDown(authServer.close);

        final stdoutLines = <String>[];
        String? accessToken;
        await IOOverrides.runZoned(
          () async {
            final service = _createOAuthService(
              authServer: authServer,
              browserLauncher: (_) async => throw Exception('no browser available'),
            );
            final result = await service.performOAuthLogin(AuthProvider.github);
            accessToken = result.tokens.accessToken;
          },
          stdout: () => _CapturingStdout(stdoutLines),
          stderr: () => _CapturingStdout(<String>[]),
        );

        expect(accessToken, equals('github-access-token'));
        expect(
          stdoutLines,
          contains(authUrl),
          reason:
              'the full auth URL (with & query separators) must be printed so headless/SSH users can open it manually',
        );
      });

      test('skips the browser launch but still prints the URL when no browser is available', () async {
        const authUrl = 'https://github.com/login/oauth/authorize?client_id=abc&scope=read%3Auser&state=xyz';
        final authServer = await _OAuthLongPollTestServer.start(
          authUrl: authUrl,
          statusResponses: [
            AuthSessionStatusResponse.complete(
              accessToken: 'github-access-token',
              refreshToken: 'github-refresh-token',
              user: AuthUser(
                id: 'user-1',
                provider: AuthProvider.github,
                providerUserId: 'gh-1',
                providerUsername: 'octocat',
              ),
            ),
          ],
        );
        addTearDown(authServer.close);

        final launchedUrls = <String>[];
        final stdoutLines = <String>[];
        String? accessToken;
        await IOOverrides.runZoned(
          () async {
            final service = _createOAuthService(
              authServer: authServer,
              browserLauncher: (url) async => launchedUrls.add(url),
              browserOpenability: () => BrowserOpenability.no,
            );
            final result = await service.performOAuthLogin(AuthProvider.github);
            accessToken = result.tokens.accessToken;
          },
          stdout: () => _CapturingStdout(stdoutLines),
          stderr: () => _CapturingStdout(<String>[]),
        );

        expect(accessToken, equals('github-access-token'));
        expect(
          launchedUrls,
          isEmpty,
          reason: 'must not attempt to launch a browser when canLaunchBrowser() is false',
        );
        expect(
          stdoutLines,
          contains(authUrl),
          reason: 'the URL must still be printed so the user can complete login manually',
        );
      });

      test('uses tentative "Attempting to open" wording but still launches when openability is unknown', () async {
        const authUrl = 'https://github.com/login/oauth/authorize?client_id=abc&scope=read%3Auser&state=xyz';
        final authServer = await _OAuthLongPollTestServer.start(
          authUrl: authUrl,
          statusResponses: [
            AuthSessionStatusResponse.complete(
              accessToken: 'github-access-token',
              refreshToken: 'github-refresh-token',
              user: AuthUser(
                id: 'user-1',
                provider: AuthProvider.github,
                providerUserId: 'gh-1',
                providerUsername: 'octocat',
              ),
            ),
          ],
        );
        addTearDown(authServer.close);

        final launchedUrls = <String>[];
        final stdoutLines = <String>[];
        await IOOverrides.runZoned(
          () async {
            final service = _createOAuthService(
              authServer: authServer,
              browserLauncher: (url) async => launchedUrls.add(url),
              browserOpenability: () => BrowserOpenability.unknown,
            );
            await service.performOAuthLogin(AuthProvider.github);
          },
          stdout: () => _CapturingStdout(stdoutLines),
          stderr: () => _CapturingStdout(<String>[]),
        );

        expect(launchedUrls, equals([authUrl]), reason: 'unknown still attempts a best-effort launch');
        expect(stdoutLines, contains(authUrl));
        expect(
          stdoutLines.any((line) => line.contains('Attempting to open')),
          isTrue,
          reason: 'unknown openability must use tentative wording',
        );
        expect(
          stdoutLines.any((line) => line.startsWith('Opening your browser')),
          isFalse,
          reason: 'must not claim the browser is definitely opening when uncertain',
        );
      });
    });

    group('Google OAuth', () {
      test('performOAuthLogin requests Google init path', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          authUrl: 'https://example.com/google-login',
          statusResponses: [
            AuthSessionStatusResponse.complete(
              accessToken: 'google-access-token',
              refreshToken: 'google-refresh-token',
              user: AuthUser(
                id: 'user-1',
                provider: AuthProvider.google,
                providerUserId: 'google-1',
                providerUsername: null,
              ),
            ),
          ],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
        );

        final result = await service.performOAuthLogin(AuthProvider.google);
        final tokens = result.tokens;

        expect(tokens.accessToken, equals('google-access-token'));
        expect(tokens.refreshToken, equals('google-refresh-token'));
        expect(tokens.lastProvider, equals(AuthProvider.google));
        expect(authServer.initRequests.single.path, equals('/auth/google/init'));
        expect(authServer.initRequests.single.queryParameters, isEmpty);
        expect(authServer.ackRequests, isEmpty);
        expect(authServer.unexpectedPaths, isNot(contains('/callback')));
      });

      test('ackOAuthSessionCompletion POSTs the session ACK with the session token header', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          authUrl: 'https://example.com/google-login',
          statusResponses: const [AuthSessionStatusResponse.pending()],
        );
        addTearDown(authServer.close);
        final api = LoginOAuthApi(
          authBackendUrl: authServer.baseUrl,
          client: authServer.client,
          clientType: AuthClientType.bridgeMacos,
          device: DeviceInfo(name: 'Test Mac', osVersion: null, appVersion: null),
        );

        await api.ackOAuthSessionCompletion(sessionToken: 'session-token-123');

        expect(authServer.ackRequests, hasLength(1));
        final ackRequest = authServer.ackRequests.single;
        expect(ackRequest.method, equals('POST'));
        expect(ackRequest.path, equals('/auth/session/status/ack'));
        expect(ackRequest.queryParameters, isEmpty);
        expect(ackRequest.sessionToken, equals('session-token-123'));
        expect(ackRequest.body, isNull);
      });

      test('expired status throws', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [const AuthSessionStatusResponse.expired()],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
        );

        expect(
          service.performOAuthLogin(AuthProvider.google),
          throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('expired'))),
        );
      });

      test('error status throws', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [const AuthSessionStatusResponse.error(message: 'provider failed')],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
        );

        expect(
          service.performOAuthLogin(AuthProvider.google),
          throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('provider failed'))),
        );
      });

      test('pending status times out', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [const AuthSessionStatusResponse.pending()],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
          pollTimeout: const Duration(milliseconds: 5),
          pollInterval: const Duration(milliseconds: 1),
        );

        expect(
          service.performOAuthLogin(AuthProvider.google),
          throwsA(isA<TimeoutException>()),
        );
      });
    });
  });

  group('resolveBrowserOpenability', () {
    BrowserOpenability resolve({
      bool isLinux = false,
      bool isMacOS = false,
      bool isWindows = false,
      bool hasDisplay = false,
      bool isWsl = false,
      bool isSsh = false,
    }) {
      return resolveBrowserOpenability(
        isLinux: isLinux,
        isMacOS: isMacOS,
        isWindows: isWindows,
        hasDisplay: hasDisplay,
        isWsl: isWsl,
        isSsh: isSsh,
      );
    }

    test('Linux with a display server is yes (incl. SSH X11 forwarding)', () {
      expect(resolve(isLinux: true, hasDisplay: true), BrowserOpenability.yes);
      expect(resolve(isLinux: true, hasDisplay: true, isSsh: true), BrowserOpenability.yes);
    });

    test('headless Linux without a display is no', () {
      expect(resolve(isLinux: true), BrowserOpenability.no);
      expect(resolve(isLinux: true, isSsh: true), BrowserOpenability.no);
    });

    test('WSL without a display is unknown (may reach the Windows browser via wslview)', () {
      expect(resolve(isLinux: true, isWsl: true), BrowserOpenability.unknown);
    });

    test('macOS is yes locally and unknown over SSH', () {
      expect(resolve(isMacOS: true), BrowserOpenability.yes);
      expect(resolve(isMacOS: true, isSsh: true), BrowserOpenability.unknown);
    });

    test('Windows is unknown locally and no over SSH', () {
      expect(resolve(isWindows: true), BrowserOpenability.unknown);
      expect(resolve(isWindows: true, isSsh: true), BrowserOpenability.no);
    });

    test('an unrecognized platform is no', () {
      expect(resolve(), BrowserOpenability.no);
    });
  });

  group('LoginEmailApi', () {
    test('loginWithEmail POSTs to /auth/email and returns tokens', () async {
      final authServer = await _PasswordLoginTestServer.start();
      authServer.onLoginRequest = (email, password) async {
        if (email == 'test@example.com' && password == 'correct-password') {
          return _PasswordLoginResult.success(
            accessToken: 'test-access-token',
            refreshToken: 'test-refresh-token',
            username: 'testuser',
          );
        }
        return _PasswordLoginResult.failure(401);
      };
      addTearDown(authServer.close);

      final api = LoginEmailApi(authBackendUrl: authServer.baseUrl);
      final authResponse = await api.loginWithEmail(
        email: 'test@example.com',
        password: 'correct-password',
      );

      expect(authServer.lastLoginRequest, isNotNull);
      expect(authServer.lastLoginRequest!['email'], equals('test@example.com'));
      expect(authServer.lastLoginRequest!['password'], equals('correct-password'));
      expect(authResponse.accessToken, equals('test-access-token'));
      expect(authResponse.refreshToken, equals('test-refresh-token'));
      expect(authResponse.user.providerUsername, equals('testuser'));
    });

    test('loginWithEmail throws EmailAuthApiException on 401', () async {
      final authServer = await _PasswordLoginTestServer.start();
      authServer.onLoginRequest = (email, password) async {
        return _PasswordLoginResult.failure(401);
      };
      addTearDown(authServer.close);

      final api = LoginEmailApi(authBackendUrl: authServer.baseUrl);
      expect(
        () => api.loginWithEmail(
          email: 'bad@example.com',
          password: 'wrong-password',
        ),
        throwsA(isA<EmailAuthApiException>()),
      );
    });

    test('loginWithEmail throws EmailAuthApiException on 429', () async {
      final authServer = await _PasswordLoginTestServer.start();
      authServer.onLoginRequest = (email, password) async {
        return _PasswordLoginResult.failure(429);
      };
      addTearDown(authServer.close);

      final api = LoginEmailApi(authBackendUrl: authServer.baseUrl);
      expect(
        () => api.loginWithEmail(
          email: 'test@example.com',
          password: 'password',
        ),
        throwsA(isA<EmailAuthApiException>()),
      );
    });
  });

  group('LoginEmailRepository', () {
    ({String email, String password}) mockPrompt() {
      return (email: 'test@example.com', password: 'password123');
    }

    test('successful login returns TokenData with email provider', () async {
      final mockApi = _MockLoginEmailApi();
      final repository = LoginEmailRepository(
        emailAuthApi: mockApi,
        promptForCredentials: mockPrompt,
      );

      final tokens = await repository.performEmailLogin();

      expect(tokens.accessToken, equals('test-access-token'));
      expect(tokens.refreshToken, equals('test-refresh-token'));
      expect(tokens.lastProvider, equals(AuthProvider.email));
    });

    test('401 from API throws EmailLoginExceptionImpl', () async {
      final mockApi = _MockLoginEmailApi.unauthorized();
      final repository = LoginEmailRepository(
        emailAuthApi: mockApi,
        promptForCredentials: mockPrompt,
      );

      expect(
        repository.performEmailLogin,
        throwsA(isA<EmailLoginExceptionImpl>()),
      );
    });

    test('429 from API throws RateLimitException', () async {
      final mockApi = _MockLoginEmailApi.rateLimited();
      final repository = LoginEmailRepository(
        emailAuthApi: mockApi,
        promptForCredentials: mockPrompt,
      );

      expect(
        repository.performEmailLogin,
        throwsA(isA<RateLimitException>()),
      );
    });

    test('missing tokens throws EmailLoginExceptionImpl', () async {
      final mockApi = _MockLoginEmailApi.emptyTokens();
      final repository = LoginEmailRepository(
        emailAuthApi: mockApi,
        promptForCredentials: mockPrompt,
      );

      expect(
        repository.performEmailLogin,
        throwsA(isA<EmailLoginExceptionImpl>()),
      );
    });
  });
}

LoginOAuthService _createOAuthService({
  required _OAuthLongPollTestServer authServer,
  required Future<void> Function(String url) browserLauncher,
  BrowserOpenability Function() browserOpenability = _alwaysOpenableBrowser,
  Duration pollTimeout = const Duration(seconds: 2),
  Duration pollInterval = Duration.zero,
  Future<void> Function(Duration duration)? delay,
}) {
  return LoginOAuthService(
    api: LoginOAuthApi(
      authBackendUrl: authServer.baseUrl,
      client: authServer.client,
      clientType: AuthClientType.bridgeMacos,
      device: DeviceInfo(name: 'Test Mac', osVersion: 'macOS 14.5', appVersion: '1.2.0'),
    ),
    browserLauncher: browserLauncher,
    browserOpenability: browserOpenability,
    pollTimeout: pollTimeout,
    pollInterval: pollInterval,
    delay: delay,
  );
}

BrowserOpenability _alwaysOpenableBrowser() => BrowserOpenability.yes;

class _HangingOAuthStatusClient extends http.BaseClient {
  int statusRequestCount = 0;
  int activeStatusRequests = 0;
  int maximumActiveStatusRequests = 0;
  int statusAbortCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/init')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'authUrl': 'https://example.com/github-login',
              'state': 'oauth-state',
              'userCode': 'ABCD',
              'expiresIn': 120,
            }),
          ),
        ),
        200,
      );
    }
    if (request.method == 'GET' && request.url.path == '/auth/session/status') {
      statusRequestCount += 1;
      activeStatusRequests += 1;
      if (activeStatusRequests > maximumActiveStatusRequests) {
        maximumActiveStatusRequests = activeStatusRequests;
      }
      try {
        final abortTrigger = (request as http.Abortable).abortTrigger;
        if (abortTrigger == null) {
          throw StateError('status request is not abortable');
        }
        await abortTrigger;
        statusAbortCount += 1;
        throw http.RequestAbortedException(request.url);
      } finally {
        activeStatusRequests -= 1;
      }
    }
    throw StateError('unexpected OAuth request: ${request.method} ${request.url}');
  }
}

class _MockLoginEmailApi implements LoginEmailApi {
  @override
  final String authBackendUrl = 'http://test';
  final AuthResponse _response;
  final int? _errorStatus;

  factory _MockLoginEmailApi() {
    return _MockLoginEmailApi._(
      AuthResponse(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        user: AuthUser(
          id: 'user-1',
          provider: AuthProvider.email,
          providerUserId: 'user-1',
          providerUsername: 'testuser',
        ),
      ),
      null,
    );
  }

  _MockLoginEmailApi._(this._response, this._errorStatus);

  factory _MockLoginEmailApi.unauthorized() => _MockLoginEmailApi._(
    AuthResponse(
      accessToken: '',
      refreshToken: '',
      user: AuthUser(id: '', provider: AuthProvider.email, providerUserId: '', providerUsername: null),
    ),
    401,
  );

  factory _MockLoginEmailApi.rateLimited() => _MockLoginEmailApi._(
    AuthResponse(
      accessToken: '',
      refreshToken: '',
      user: AuthUser(id: '', provider: AuthProvider.email, providerUserId: '', providerUsername: null),
    ),
    429,
  );

  factory _MockLoginEmailApi.emptyTokens() => _MockLoginEmailApi._(
    AuthResponse(
      accessToken: '',
      refreshToken: '',
      user: AuthUser(
        id: 'user-1',
        provider: AuthProvider.email,
        providerUserId: 'user-1',
        providerUsername: 'testuser',
      ),
    ),
    null,
  );

  @override
  Future<AuthResponse> loginWithEmail({required String email, required String password}) async {
    if (_errorStatus == 401) {
      throw EmailAuthApiException(statusCode: 401, body: 'Unauthorized');
    }
    if (_errorStatus == 429) {
      throw EmailAuthApiException(statusCode: 429, body: 'Rate limited');
    }
    return _response;
  }
}

class _OAuthRequestRecord {
  final String method;
  final String path;
  final Map<String, String> queryParameters;
  final String? sessionToken;
  final String? contentType;
  final Map<String, dynamic>? body;

  _OAuthRequestRecord({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.sessionToken,
    required this.contentType,
    required this.body,
  });
}

class _OAuthLongPollTestServer {
  final HttpServer _server;
  final String authUrl;
  final List<({int statusCode, String? retryAfter})> _initResponses;
  final List<Object> _statusResponses;
  final http.Client client = http.Client();
  final List<_OAuthRequestRecord> initRequests = [];
  final List<_OAuthRequestRecord> statusRequests = [];
  final List<_OAuthRequestRecord> ackRequests = [];
  final List<String> unexpectedPaths = [];

  _OAuthLongPollTestServer._({
    required HttpServer server,
    required this.authUrl,
    required List<({int statusCode, String? retryAfter})> initResponses,
    required List<Object> statusResponses,
  }) : _server = server,
       _initResponses = List.of(initResponses),
       _statusResponses = List.of(statusResponses) {
    _listen();
  }

  static Future<_OAuthLongPollTestServer> start({
    String authUrl = 'https://example.com/github-login',
    List<({int statusCode, String? retryAfter})> initResponses = const [],
    required List<Object> statusResponses,
  }) async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    return _OAuthLongPollTestServer._(
      server: server,
      authUrl: authUrl,
      initResponses: initResponses,
      statusResponses: statusResponses,
    );
  }

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  void _listen() {
    _server.listen((request) async {
      if ((request.uri.path == '/auth/github/init' || request.uri.path == '/auth/google/init') &&
          request.method == 'POST') {
        initRequests.add(await _recordRequest(request));
        final configuredResponse = _initResponses.isEmpty
            ? (statusCode: 200, retryAfter: null)
            : _initResponses.removeAt(0);
        if (configuredResponse.statusCode == 0) {
          await Completer<void>().future;
          return;
        }
        if (configuredResponse.statusCode != 200) {
          request.response.statusCode = configuredResponse.statusCode;
          if (configuredResponse.retryAfter != null) {
            request.response.headers.set('Retry-After', configuredResponse.retryAfter!);
          }
          request.response.write('not-json');
          await request.response.close();
          return;
        }
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'authUrl': initRequests.length == 1 ? authUrl : '$authUrl-restart',
            'state': 'oauth-state',
            'userCode': 'ABCD',
            'expiresIn': 120,
          }),
        );
        await request.response.close();
      } else if (request.uri.path == '/auth/session/status' && request.method == 'GET') {
        statusRequests.add(await _recordRequest(request));
        final status = _statusResponses.isEmpty
            ? const AuthSessionStatusResponse.pending()
            : _statusResponses.removeAt(0);
        if (status is! AuthSessionStatusResponse) {
          final restartResponse = status as ({int statusCode, String? retryAfter});
          request.response.statusCode = restartResponse.statusCode;
          if (restartResponse.retryAfter != null) {
            request.response.headers.set('Retry-After', restartResponse.retryAfter!);
          }
          request.response.write('not-json');
          await request.response.close();
          return;
        }
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(status.toJson()));
        await request.response.close();
      } else if (request.uri.path == '/auth/session/status/ack' && request.method == 'POST') {
        ackRequests.add(await _recordRequest(request));
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'success': true}));
        await request.response.close();
      } else {
        unexpectedPaths.add(request.uri.path);
        request.response.statusCode = 404;
        await request.response.close();
      }
    });
  }

  Future<_OAuthRequestRecord> _recordRequest(HttpRequest request) async {
    Map<String, dynamic>? body;
    if (request.method == 'POST') {
      final content = await request.fold<List<int>>(
        [],
        (prev, element) => prev..addAll(element as List<int>),
      );
      final text = utf8.decode(Uint8List.fromList(content));
      body = text.isEmpty ? null : jsonDecodeMap(text);
    }

    return _OAuthRequestRecord(
      method: request.method,
      path: request.uri.path,
      queryParameters: Map.of(request.uri.queryParameters),
      sessionToken: request.headers.value(oauthSessionTokenHeader),
      contentType: request.headers.contentType?.mimeType,
      body: body,
    );
  }

  Future<void> close() async {
    client.close();
    await _server.close(force: true);
  }
}

enum _PasswordLoginResultType { success, failure }

class _PasswordLoginResult {
  final _PasswordLoginResultType type;
  final String? accessToken;
  final String? refreshToken;
  final String? username;
  final int? statusCode;

  _PasswordLoginResult._({
    required this.type,
    this.accessToken,
    this.refreshToken,
    this.username,
    this.statusCode,
  });

  factory _PasswordLoginResult.success({
    required String accessToken,
    required String refreshToken,
    required String username,
  }) {
    return _PasswordLoginResult._(
      type: _PasswordLoginResultType.success,
      accessToken: accessToken,
      refreshToken: refreshToken,
      username: username,
    );
  }

  factory _PasswordLoginResult.failure(int statusCode) {
    return _PasswordLoginResult._(
      type: _PasswordLoginResultType.failure,
      statusCode: statusCode,
    );
  }
}

class _PasswordLoginTestServer {
  final HttpServer _server;
  Map<String, dynamic>? _lastLoginRequest;
  Future<_PasswordLoginResult> Function(String email, String password)? onLoginRequest;

  _PasswordLoginTestServer._(this._server) {
    _listen();
  }

  static Future<_PasswordLoginTestServer> start() async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    return _PasswordLoginTestServer._(server);
  }

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  Map<String, dynamic>? get lastLoginRequest => _lastLoginRequest;

  void _listen() {
    _server.listen((request) async {
      if (request.uri.path == '/auth/email' && request.method == 'POST') {
        try {
          final content = await request.fold<List<int>>(
            [],
            (prev, element) => prev..addAll(element as List<int>),
          );
          final body = utf8.decode(Uint8List.fromList(content));
          _lastLoginRequest = jsonDecodeMap(body);

          final result =
              await (onLoginRequest?.call(
                    _lastLoginRequest!['email'] as String,
                    _lastLoginRequest!['password'] as String,
                  ) ??
                  Future.value(_PasswordLoginResult.failure(500)));

          if (result.type == _PasswordLoginResultType.success) {
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'accessToken': result.accessToken,
                'refreshToken': result.refreshToken,
                'user': {
                  'id': 'user-1',
                  'provider': 'email',
                  'providerUserId': 'user-1',
                  'providerUsername': result.username,
                },
              }),
            );
          } else {
            request.response.statusCode = result.statusCode ?? 500;
          }
        } catch (e) {
          request.response.statusCode = 500;
        }
        await request.response.close();
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    });
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}

/// Captures [writeln] calls; [IOOverrides] swaps it in for stdout/stderr.
class _CapturingStdout implements Stdout {
  _CapturingStdout(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = '']) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
