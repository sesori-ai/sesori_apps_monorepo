import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sesori_bridge/src/auth/auth_api.dart';
import 'package:sesori_bridge/src/auth/auth_repository.dart';
import 'package:sesori_bridge/src/auth/login_email_api.dart';
import 'package:sesori_bridge/src/auth/login_email_repository.dart';
import 'package:sesori_bridge/src/auth/login_oauth_service.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/foundation/abortable_request_client.dart';
import 'package:sesori_bridge/src/foundation/legacy_post_update_relaunch.dart';
import 'package:sesori_bridge/src/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/runtime/bridge_runtime_auth.dart';
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeRuntimeAuthService', () {
    test('promptForProvider throws clear guidance when relaunched non-interactively by a legacy auto-update', () async {
      final service = BridgeRuntimeAuthService(
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: _FakeLoginOAuthService(),
        authRepository: _invalidAuthRepository(),
        environment: const <String, String>{sesoriPostUpdateRestartEnvVar: '1'},
        loadTokens: () async => throw const FileSystemException('missing', 'token.json', OSError('missing', 2)),
        saveTokens: (_) async {},
        clearTokens: () async {},
      );

      await expectLater(
        service.promptForProvider(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('relaunched non-interactively after an auto-update'),
          ),
        ),
      );
    });

    test('OAuth login ACK is sent only after tokens are persisted', () async {
      final authBackend = await _InvalidTokenAuthBackend.start();
      addTearDown(authBackend.close);
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
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: oauthService,
        authRepository: _invalidAuthRepository(),
        environment: const <String, String>{},
        loadTokens: () async {
          loadCount++;
          return storedTokens;
        },
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
        clearTokens: () async {},
      );

      final result = await service.ensureAuthenticated(options: _options(authBackendUrl: authBackend.baseUrl));

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
          requestClient: const AbortableRequestClient(),
          requestDeadline: AuthApi.defaultRequestDeadline,
        ),
      );
      final service = BridgeRuntimeAuthService(
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: _FakeLoginOAuthService(),
        authRepository: repository,
        environment: const <String, String>{},
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
      final authBackend = await _InvalidTokenAuthBackend.start();
      addTearDown(authBackend.close);
      final storedTokens = TokenData(
        accessToken: 'expired-access-token',
        refreshToken: 'expired-refresh-token',
        lastProvider: AuthProvider.github,
      );
      final oauthService = _FakeLoginOAuthService(error: Exception('authorization denied'));
      final service = BridgeRuntimeAuthService(
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: oauthService,
        authRepository: _invalidAuthRepository(),
        environment: const <String, String>{},
        loadTokens: () async => storedTokens,
        saveTokens: (_) async {},
        clearTokens: () async {},
      );

      await expectLater(
        service.ensureAuthenticated(options: _options(authBackendUrl: authBackend.baseUrl)),
        throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('authorization denied'))),
      );

      expect(oauthService.ackCalls, isEmpty);
    });

    test('OAuth ACK failure does not fail persisted login', () async {
      final authBackend = await _InvalidTokenAuthBackend.start();
      addTearDown(authBackend.close);
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
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: oauthService,
        authRepository: _invalidAuthRepository(),
        environment: const <String, String>{},
        loadTokens: () async => storedTokens,
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
        clearTokens: () async {},
      );

      final result = await service.ensureAuthenticated(options: _options(authBackendUrl: authBackend.baseUrl));

      expect(result.accessToken, equals('oauth-access-token'));
      expect(savedTokens, isNotNull);
      expect(oauthService.ackCalls, equals(['oauth-session-token']));
    });
  });
}

AuthRepository _invalidAuthRepository() {
  return AuthRepository(
    api: AuthApi(
      authBackendUrl: 'https://auth.example.test',
      client: MockClient((_) async => http.Response('', 403)),
      requestClient: const AbortableRequestClient(),
      requestDeadline: AuthApi.defaultRequestDeadline,
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
    importPluginIds: const [],
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

class _InvalidTokenAuthBackend._(final HttpServer _server) {
  this {
    _listen();
  }

  static Future<_InvalidTokenAuthBackend> start() async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    return _InvalidTokenAuthBackend._(server);
  }

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  void _listen() {
    _server.listen((request) async {
      if (request.uri.path == '/auth/me' || request.uri.path == '/auth/refresh') {
        request.response.statusCode = 401;
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
  }

  Future<void> close() async {
    await _server.close(force: true);
  }
}
