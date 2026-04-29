import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sesori_bridge/src/auth/login_email_api.dart';
import 'package:sesori_bridge/src/auth/login_oauth_api.dart';
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  group('GitHub OAuth', () {
    test('generatePKCE produces valid base64url strings', () {
      final (verifier, challenge) = generatePKCE();

      expect(verifier.contains('='), isFalse, reason: 'verifier should have no padding');
      expect(challenge.contains('='), isFalse, reason: 'challenge should have no padding');

      expect(verifier.length, greaterThanOrEqualTo(43), reason: 'verifier length check');
      expect(challenge.length, greaterThanOrEqualTo(43), reason: 'challenge length check');
    });

    test('performLogin requests correct GitHub auth URL', () async {
      final authServer = await _AuthTestServer.start();
      addTearDown(authServer.close);

      final authCompleter = Completer<void>();
      authServer.onAuthRequest = () {
        if (!authCompleter.isCompleted) authCompleter.complete();
      };

      final loginFuture = performOAuthLogin(
        authServer.baseUrl,
        provider: AuthProvider.github,
        browserLauncher: (_) async {},
      );

      await authCompleter.future.timeout(const Duration(seconds: 5));

      expect(authServer.requestedPath, contains('/auth/github'));
      expect(authServer.hasQueryParam('redirect_uri'), isTrue);
      expect(authServer.hasQueryParam('code_challenge'), isTrue);

      authServer.respondToAuthRequest('/callback?code=test&state=${authServer.lastState}');

      // Full flow can't complete without browser; verify it fails cleanly
      await expectLater(
        loginFuture.timeout(const Duration(seconds: 3)),
        throwsA(isA<Exception>()),
      );
    });

    test('state mismatch throws exception', () async {
      final authServer = await _AuthTestServer.start();
      addTearDown(authServer.close);

      final authCompleter = Completer<void>();
      authServer.onAuthRequest = () {
        if (!authCompleter.isCompleted) authCompleter.complete();
      };

      final loginFuture = performOAuthLogin(
        authServer.baseUrl,
        provider: AuthProvider.github,
        browserLauncher: (_) async {},
      );

      await authCompleter.future.timeout(const Duration(seconds: 5));

      authServer.respondToAuthRequest('/callback?code=test&state=wrong-state');

      expect(
        loginFuture.timeout(const Duration(seconds: 5)),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Google OAuth', () {
    test('performLogin requests correct Google auth URL', () async {
      final authServer = await _AuthTestServer.start();
      addTearDown(authServer.close);

      final authCompleter = Completer<void>();
      authServer.onAuthRequest = () {
        if (!authCompleter.isCompleted) authCompleter.complete();
      };

      final loginFuture = performOAuthLogin(
        authServer.baseUrl,
        provider: AuthProvider.google,
        browserLauncher: (_) async {},
      );

      await authCompleter.future.timeout(const Duration(seconds: 5));

      expect(authServer.requestedPath, contains('/auth/google'));
      expect(authServer.hasQueryParam('redirect_uri'), isTrue);
      expect(authServer.hasQueryParam('code_challenge'), isTrue);

      authServer.respondToAuthRequest('/callback?code=test&state=${authServer.lastState}');

      // Full flow can't complete without browser; verify it fails cleanly
      await expectLater(
        loginFuture.timeout(const Duration(seconds: 3)),
        throwsA(isA<Exception>()),
      );
    });

    test('state mismatch throws exception', () async {
      final authServer = await _AuthTestServer.start();
      addTearDown(authServer.close);

      final authCompleter = Completer<void>();
      authServer.onAuthRequest = () {
        if (!authCompleter.isCompleted) authCompleter.complete();
      };

      final loginFuture = performOAuthLogin(
        authServer.baseUrl,
        provider: AuthProvider.google,
        browserLauncher: (_) async {},
      );

      await authCompleter.future.timeout(const Duration(seconds: 5));

      authServer.respondToAuthRequest('/callback?code=test&state=wrong-state');

      expect(
        loginFuture.timeout(const Duration(seconds: 5)),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Email Password Login', () {
    test('performEmailLogin POSTs to /auth/email and returns tokens', () async {
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

      final (tokens, username) = await performEmailLogin(
        authServer.baseUrl,
        'test@example.com',
        'correct-password',
      );

      expect(authServer.lastLoginRequest, isNotNull);
      expect(authServer.lastLoginRequest!['email'], equals('test@example.com'));
      expect(authServer.lastLoginRequest!['password'], equals('correct-password'));
      expect(tokens.accessToken, equals('test-access-token'));
      expect(tokens.refreshToken, equals('test-refresh-token'));
      expect(username, equals('testuser'));
    });

    test('performEmailLogin throws EmailLoginException on 401', () async {
      final authServer = await _PasswordLoginTestServer.start();
      authServer.onLoginRequest = (email, password) async {
        return _PasswordLoginResult.failure(401);
      };
      addTearDown(authServer.close);

      expect(
        () => performEmailLogin(
          authServer.baseUrl,
          'bad@example.com',
          'wrong-password',
        ),
        throwsA(isA<EmailLoginExceptionImpl>()),
      );
    });

    test('performEmailLogin throws RateLimitException on 429', () async {
      final authServer = await _PasswordLoginTestServer.start();
      authServer.onLoginRequest = (email, password) async {
        return _PasswordLoginResult.failure(429);
      };
      addTearDown(authServer.close);

      expect(
        () => performEmailLogin(
          authServer.baseUrl,
          'test@example.com',
          'password',
        ),
        throwsA(isA<RateLimitException>()),
      );
    });
  });
}

class _AuthTestServer {
  final HttpServer _server;
  final List<HttpRequest> _requests = [];
  String _lastState = 'test-state-${DateTime.now().millisecondsSinceEpoch}';
  void Function()? onAuthRequest;
  final _responseCompleter = Completer<String>();

  _AuthTestServer._(this._server) {
    _listen();
  }

  static Future<_AuthTestServer> start() async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    return _AuthTestServer._(server);
  }

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  List<HttpRequest> get requests => _requests;

  String get requestedPath {
    if (_requests.isEmpty) return '';
    return _requests.first.uri.path;
  }

  String get lastState => _lastState;

  bool hasQueryParam(String key) {
    if (_requests.isEmpty) return false;
    return _requests.first.uri.queryParameters.containsKey(key);
  }

  void respondToAuthRequest(String redirectPath) {
    _responseCompleter.complete(redirectPath);
  }

  void _listen() {
    _server.listen((request) async {
      _requests.add(request);

      if (request.uri.path.startsWith('/auth/github') || request.uri.path.startsWith('/auth/google')) {
        final redirectUri = request.uri.queryParameters['redirect_uri'] ?? '';
        _lastState = request.uri.queryParameters['state'] ?? _lastState;

        onAuthRequest?.call();

        final redirectPath = await _responseCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => '?code=test&state=$_lastState',
        );

        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'authUrl': '$redirectUri$redirectPath',
            'state': _lastState,
          }),
        );
        await request.response.close();
      } else if (request.uri.path == '/callback') {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html></html>');
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
