import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sesori_bridge/src/auth/auth_provider.dart';
import 'package:sesori_bridge/src/auth/login.dart';
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

      final loginFuture = performLogin(
        authServer.baseUrl,
        provider: AuthProvider.github,
      );

      await authCompleter.future.timeout(const Duration(seconds: 5));

      expect(authServer.requestedPath, contains('/auth/github'));
      expect(authServer.hasQueryParam('redirect_uri'), isTrue);
      expect(authServer.hasQueryParam('code_challenge'), isTrue);

      authServer.respondToAuthRequest('/callback?code=test&state=${authServer.lastState}');

      try {
        await loginFuture.timeout(const Duration(seconds: 5));
      } catch (_) {}
    });

    test('state mismatch throws exception', () async {
      final authServer = await _AuthTestServer.start();
      addTearDown(authServer.close);

      final authCompleter = Completer<void>();
      authServer.onAuthRequest = () {
        if (!authCompleter.isCompleted) authCompleter.complete();
      };

      final loginFuture = performLogin(
        authServer.baseUrl,
        provider: AuthProvider.github,
      );

      await authCompleter.future.timeout(const Duration(seconds: 5));

      authServer.respondToAuthRequest('/callback?code=test&state=wrong-state');

      expect(
        loginFuture.timeout(const Duration(seconds: 5)),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _AuthTestServer {
  final HttpServer _server;
  final List<HttpRequest> _requests = [];
  String _lastState = '';
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

      if (request.uri.path.startsWith('/auth/github')) {
        final redirectUri = request.uri.queryParameters['redirect_uri'] ?? '';
        _lastState = request.uri.queryParameters['state'] ?? '';

        onAuthRequest?.call();

        final redirectPath = await _responseCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => '/callback?code=test&state=$_lastState',
        );

        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'authUrl': '$redirectUri$redirectPath',
          'state': _lastState,
        }));
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
