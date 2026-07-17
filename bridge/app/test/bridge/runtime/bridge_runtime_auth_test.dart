import 'dart:io';

import 'package:sesori_bridge/src/auth/login_email_api.dart';
import 'package:sesori_bridge/src/auth/login_email_repository.dart';
import 'package:sesori_bridge/src/auth/login_oauth_service.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/bridge/foundation/legacy_post_update_relaunch.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_options.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_runtime_auth.dart';
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeRuntimeAuthService', () {
    test('promptForProvider throws clear guidance when relaunched non-interactively by a legacy auto-update', () async {
      final service = BridgeRuntimeAuthService(
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: _FakeLoginOAuthService(),
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
        environment: const <String, String>{},
        loadTokens: () async => storedTokens,
        saveTokens: (tokens) async {
          savedTokens = tokens;
        },
        clearTokens: () async {},
      );

      final result = await service.ensureAuthenticated(options: _options(authBackendUrl: authBackend.baseUrl));

      expect(result.accessToken, equals('oauth-access-token'));
      expect(oauthService.ackCalls, equals(['oauth-session-token']));
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

BridgeCliOptions _options({required String authBackendUrl}) {
  return BridgeCliOptions(
    cliArgs: const [],
    relayUrl: 'wss://relay.example.com',
    authBackendUrl: authBackendUrl,
    debugPort: null,
    logLevelName: 'info',
    importPluginIds: const [],
    controlUrl: null,
  );
}

class _FakeLoginEmailRepository implements LoginEmailRepository {
  @override
  LoginEmailApi get emailAuthApi => throw UnimplementedError();

  @override
  ({String email, String password}) Function() get promptForCredentials => throw UnimplementedError();

  @override
  Future<TokenData> performEmailLogin() {
    throw UnimplementedError();
  }
}

class _FakeLoginOAuthService implements LoginOAuthService {
  final ({TokenData tokens, String sessionToken})? _result;
  final Object? _error;
  final Object? _ackError;
  final void Function(String sessionToken)? _onAck;
  final List<String> ackCalls = [];

  _FakeLoginOAuthService({
    ({TokenData tokens, String sessionToken})? result,
    Object? error,
    Object? ackError,
    void Function(String sessionToken)? onAck,
  }) : _result = result,
       _error = error,
       _ackError = ackError,
       _onAck = onAck;

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

class _InvalidTokenAuthBackend {
  final HttpServer _server;

  _InvalidTokenAuthBackend._(this._server) {
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
