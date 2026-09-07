import "dart:async";

import "package:fake_async/fake_async.dart";
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sesori_bridge/src/auth/auth_api.dart';
import 'package:sesori_bridge/src/auth/auth_repository.dart';
import 'package:sesori_bridge/src/auth/login_email_api.dart';
import 'package:sesori_bridge/src/auth/login_email_repository.dart';
import 'package:sesori_bridge/src/auth/login_oauth_service.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/foundation/abortable_request.dart';
import 'package:sesori_bridge/src/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/runtime/bridge_runtime_auth.dart';
import "package:sesori_bridge/src/services/bridge_startup_retry_service.dart";
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeRuntimeAuthService', () {
    for (final refreshFails in [false, true]) {
      for (final serverUnavailable in [false, true]) {
        test(
          'stored token ${refreshFails ? "refresh" : "lookup"} recovers after ${serverUnavailable ? "503" : "DNS failure"}',
          () {
            fakeAsync((time) {
              final retry = BridgeStartupRetryService();
              var attempts = 0;
              var loads = 0;
              var clears = 0;
              TokenData? saved;
              TokenData? result;
              final client = MockClient((request) async {
                if (refreshFails && request.url.path == '/auth/me') return http.Response('', 401);
                attempts++;
                if (attempts == 1) {
                  if (serverUnavailable) return http.Response('', 503);
                  throw http.ClientException('Failed host lookup', request.url);
                }
                return http.Response(
                  refreshFails
                      ? '{"accessToken":"refreshed","refreshToken":"new-refresh","user":{"id":"1","provider":"github","providerUserId":"1"}}'
                      : '{"user":{"id":"1","provider":"github","providerUserId":"1"}}',
                  200,
                );
              });
              final service = BridgeRuntimeAuthService(
                startupRetryService: retry,
                loginEmailRepository: _FakeLoginEmailRepository(),
                loginOAuthService: _FakeLoginOAuthService(),
                authRepository: AuthRepository(
                  api: AuthApi(
                    authBackendUrl: 'https://auth.example.test',
                    client: client,
                    requestDeadline: AuthApi.defaultRequestDeadline,
                    sendRequest: sendRequestWithDeadline,
                  ),
                ),
                loadTokens: () async {
                  loads++;
                  return TokenData(accessToken: 'stored', refreshToken: 'refresh', lastProvider: AuthProvider.github);
                },
                saveTokens: (tokens) async {
                  saved = tokens;
                },
                clearTokens: () async {
                  clears++;
                },
              );
              service
                  .ensureAuthenticated(options: _options(authBackendUrl: 'https://auth.example.test'))
                  .then((tokens) => result = tokens);
              time.flushMicrotasks();
              expect(retry.states.value, ControlStartupState.waitingForServer);
              expect(saved, isNull);
              expect(clears, 0);
              time.elapse(const Duration(minutes: 1));
              expect(result?.accessToken, refreshFails ? 'refreshed' : 'stored');
              expect(saved, result);
              expect(loads, 1);
              expect(attempts, 2);
              client.close();
              unawaited(retry.dispose());
              time.flushMicrotasks();
            });
          },
        );
      }
    }

    test('interactive OAuth timeout is not retried', () async {
      final retry = BridgeStartupRetryService();
      addTearDown(retry.dispose);
      final timeout = TimeoutException('timed out waiting for authorization');
      final service = BridgeRuntimeAuthService(
        startupRetryService: retry,
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: _FakeLoginOAuthService(error: timeout),
        authRepository: _expiredTokensAuthRepository(),
        loadTokens: () async =>
            TokenData(accessToken: 'expired', refreshToken: 'expired', lastProvider: AuthProvider.github),
        saveTokens: (_) async {},
        clearTokens: () async {},
      );
      await expectLater(
        service.ensureAuthenticated(options: _options(authBackendUrl: 'https://auth.example.test')),
        throwsA(same(timeout)),
      );
      expect(retry.states.value, ControlStartupState.starting);
    });

    test('OAuth login ACK is sent only after tokens are persisted', () async {
      final storedTokens = TokenData(
        accessToken: 'expired-access-token',
        refreshToken: 'expired-refresh-token',
        lastProvider: AuthProvider.google,
      );
      final oauthTokens = TokenData(
        accessToken: 'oauth-access-token',
        refreshToken: 'oauth-refresh-token',
        lastProvider: AuthProvider.google,
      );
      TokenData? savedTokens;
      var loadCount = 0;
      final oauthService = _FakeLoginOAuthService(
        result: (tokens: oauthTokens, sessionToken: 'oauth-session-token'),
        onAck: (sessionToken) {
          expect(sessionToken, equals('oauth-session-token'));
          expect(savedTokens, isNotNull);
          expect(savedTokens!.accessToken, equals('oauth-access-token'));
        },
      );
      final service = BridgeRuntimeAuthService(
        startupRetryService: BridgeStartupRetryService(),
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: oauthService,
        authRepository: _expiredTokensAuthRepository(),
        loadTokens: () async {
          loadCount++;
          return storedTokens;
        },
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
        clearTokens: () async {},
      );

      final result = await service.ensureAuthenticated(options: _options(authBackendUrl: 'https://auth.example.test'));

      expect(result.accessToken, equals('oauth-access-token'));
      expect(loadCount, 1);
      expect(oauthService.ackCalls, equals(['oauth-session-token']));
    });

    test('refreshes a rejected stored access token and loads storage once', () async {
      final storedTokens = TokenData(
        accessToken: 'expired-access-token',
        refreshToken: 'stored-refresh-token',
        lastProvider: AuthProvider.github,
      );
      var loadCount = 0;
      TokenData? savedTokens;
      final repository = AuthRepository(
        api: AuthApi(
          authBackendUrl: 'https://auth.example.test',
          client: MockClient((request) async {
            return switch (request.url.path) {
              '/auth/me' => http.Response('', 401),
              '/auth/refresh' => http.Response(
                '{"accessToken":"new-access-token","refreshToken":"new-refresh-token","user":{"id":"1","provider":"github","providerUserId":"1"}}',
                200,
              ),
              _ => http.Response('', 404),
            };
          }),
          requestDeadline: AuthApi.defaultRequestDeadline,
          sendRequest: sendRequestWithDeadline,
        ),
      );
      final service = BridgeRuntimeAuthService(
        startupRetryService: BridgeStartupRetryService(),
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: _FakeLoginOAuthService(),
        authRepository: repository,
        loadTokens: () async {
          loadCount++;
          return storedTokens;
        },
        saveTokens: (tokens) async => savedTokens = tokens,
        clearTokens: () async {},
      );

      final result = await service.ensureAuthenticated(
        options: _options(authBackendUrl: 'https://auth.example.test'),
      );

      expect(result.accessToken, 'new-access-token');
      expect(result.refreshToken, 'new-refresh-token');
      expect(result.lastProvider, AuthProvider.github);
      expect(savedTokens, result);
      expect(loadCount, 1);
    });

    test('failed OAuth login does not ACK session completion', () async {
      final storedTokens = TokenData(
        accessToken: 'expired-access-token',
        refreshToken: 'expired-refresh-token',
        lastProvider: AuthProvider.github,
      );
      final oauthService = _FakeLoginOAuthService(error: Exception('authorization denied'));
      final service = BridgeRuntimeAuthService(
        startupRetryService: BridgeStartupRetryService(),
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: oauthService,
        authRepository: _expiredTokensAuthRepository(),
        loadTokens: () async => storedTokens,
        saveTokens: (_) async {},
        clearTokens: () async {},
      );

      await expectLater(
        service.ensureAuthenticated(options: _options(authBackendUrl: 'https://auth.example.test')),
        throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('authorization denied'))),
      );

      expect(oauthService.ackCalls, isEmpty);
    });

    test('OAuth ACK failure does not fail persisted login', () async {
      final storedTokens = TokenData(
        accessToken: 'expired-access-token',
        refreshToken: 'expired-refresh-token',
        lastProvider: AuthProvider.google,
      );
      final oauthTokens = TokenData(
        accessToken: 'oauth-access-token',
        refreshToken: 'oauth-refresh-token',
        lastProvider: AuthProvider.google,
      );
      TokenData? savedTokens;
      final oauthService = _FakeLoginOAuthService(
        result: (tokens: oauthTokens, sessionToken: 'oauth-session-token'),
        ackError: Exception('ack failed'),
      );
      final service = BridgeRuntimeAuthService(
        startupRetryService: BridgeStartupRetryService(),
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: oauthService,
        authRepository: _expiredTokensAuthRepository(),
        loadTokens: () async => storedTokens,
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
        clearTokens: () async {},
      );

      final result = await service.ensureAuthenticated(options: _options(authBackendUrl: 'https://auth.example.test'));

      expect(result.accessToken, equals('oauth-access-token'));
      expect(savedTokens, isNotNull);
      expect(oauthService.ackCalls, equals(['oauth-session-token']));
    });
  });
}

/// Rejects the stored access token (401) and its refresh token (401), so
/// [BridgeRuntimeAuthService.ensureAuthenticated] must fall through to login.
AuthRepository _expiredTokensAuthRepository() {
  return AuthRepository(
    api: AuthApi(
      authBackendUrl: 'https://auth.example.test',
      client: MockClient((_) async => http.Response('', 401)),
      requestDeadline: AuthApi.defaultRequestDeadline,
      sendRequest: sendRequestWithDeadline,
    ),
  );
}

BridgeCliOptions _options({required String authBackendUrl}) {
  return BridgeCliOptions(
    cliArgs: const [],
    relayUrl: 'wss://relay.example.com',
    authBackendUrl: authBackendUrl,
    dataDirectory: '/tmp/sesori-test-data',
    debugPort: null,
    logLevelName: 'info',
    controlUrl: null,
  );
}

class _FakeLoginEmailRepository() implements LoginEmailRepository {
  @override
  LoginEmailApi get emailAuthApi => throw UnimplementedError();

  @override
  ({String email, String password}) Function() get promptForCredentials => throw UnimplementedError();

  @override
  Future<TokenData> performEmailLogin() {
    throw UnimplementedError();
  }
}

class _FakeLoginOAuthService({
  final ({TokenData tokens, String sessionToken})? _result,
  final Object? _error,
  final Object? _ackError,
  final void Function(String sessionToken)? _onAck,
}) implements LoginOAuthService {
  final List<String> ackCalls = [];

  @override
  Future<({TokenData tokens, String sessionToken})> performOAuthLogin(OAuthProvider provider) async {
    final error = _error;
    if (error != null) {
      throw error;
    }
    final result = _result;
    if (result == null) {
      throw UnimplementedError();
    }
    return result;
  }

  @override
  Future<void> ackOAuthSessionCompletion({required String sessionToken}) async {
    ackCalls.add(sessionToken);
    _onAck?.call(sessionToken);
    final ackError = _ackError;
    if (ackError != null) {
      throw ackError;
    }
  }
}
