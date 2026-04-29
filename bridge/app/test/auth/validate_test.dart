import 'dart:convert';
import 'dart:io';

import 'package:sesori_bridge/src/auth/validate.dart';
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  group('validateToken', () {
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      baseUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('returns true when /auth/me returns 200', () async {
      _handleRequests(server, [
        _RequestResponse(
          path: '/auth/me',
          statusCode: 200,
          body: jsonEncode({
            'user': {
              'id': '1',
              'provider': 'github',
              'providerUserId': '1',
              'providerUsername': 'test',
            },
          }),
        ),
      ]);

      final (tokens, valid) = await validateToken(
        authBackendURL: baseUrl,
        accessToken: 'valid-token',
        refreshToken: 'refresh-token',
        lastProvider: AuthProvider.github,
      );

      expect(valid, isTrue);
      expect(tokens.accessToken, equals('valid-token'));
      expect(tokens.refreshToken, equals('refresh-token'));
      expect(tokens.lastProvider, equals(AuthProvider.github));
    });

    test('returns false when /auth/me returns 403', () async {
      _handleRequests(server, [
        _RequestResponse(
          path: '/auth/me',
          statusCode: 403,
          body: '',
        ),
      ]);

      final (tokens, valid) = await validateToken(
        authBackendURL: baseUrl,
        accessToken: 'valid-token',
        refreshToken: 'refresh-token',
        lastProvider: AuthProvider.github,
      );

      expect(valid, isFalse);
      expect(tokens.accessToken, equals('valid-token'));
    });

    test('refreshes token on 401 and returns new tokens', () async {
      _handleRequests(server, [
        _RequestResponse(
          path: '/auth/me',
          statusCode: 401,
          body: '',
        ),
        _RequestResponse(
          path: '/auth/refresh',
          statusCode: 200,
          body: jsonEncode({
            'accessToken': 'new-access-token',
            'refreshToken': 'new-refresh-token',
            'user': {
              'id': '1',
              'provider': 'github',
              'providerUserId': '1',
              'providerUsername': 'test',
            },
          }),
        ),
      ]);

      final (tokens, valid) = await validateToken(
        authBackendURL: baseUrl,
        accessToken: 'expired-token',
        refreshToken: 'refresh-token',
        lastProvider: AuthProvider.github,
      );

      expect(valid, isTrue);
      expect(tokens.accessToken, equals('new-access-token'));
      expect(tokens.refreshToken, equals('new-refresh-token'));
    });

    test('returns false when refresh fails', () async {
      _handleRequests(server, [
        _RequestResponse(
          path: '/auth/me',
          statusCode: 401,
          body: '',
        ),
        _RequestResponse(
          path: '/auth/refresh',
          statusCode: 401,
          body: '',
        ),
      ]);

      final (tokens, valid) = await validateToken(
        authBackendURL: baseUrl,
        accessToken: 'expired-token',
        refreshToken: 'invalid-refresh',
        lastProvider: AuthProvider.github,
      );

      expect(valid, isFalse);
      expect(tokens.accessToken, equals('expired-token'));
    });

    test('throws on network error', () async {
      await server.close(force: true);

      expect(
        () => validateToken(
          authBackendURL: 'http://127.0.0.1:1',
          accessToken: 'token',
          refreshToken: 'refresh',
          lastProvider: AuthProvider.github,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _RequestResponse {
  final String path;
  final int statusCode;
  final String body;

  _RequestResponse({required this.path, required this.statusCode, required this.body});
}

void _handleRequests(HttpServer server, List<_RequestResponse> responses) {
  var index = 0;
  server.listen((request) async {
    if (index < responses.length) {
      final response = responses[index++];
      if (request.uri.path == response.path) {
        request.response.statusCode = response.statusCode;
        if (response.body.isNotEmpty) {
          request.response.write(response.body);
        }
      } else {
        request.response.statusCode = 404;
      }
    } else {
      request.response.statusCode = 404;
    }
    await request.response.close();
  });
}
