import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/auth/auth_api.dart';
import 'package:sesori_bridge/src/foundation/abortable_request_client.dart';
import 'package:test/test.dart';

void main() {
  group('validateToken', () {
    late HttpServer server;
    late http.Client client;
    late AuthApi api;

    setUp(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      client = http.Client();
      api = AuthApi(
        authBackendUrl: 'http://${server.address.host}:${server.port}',
        client: client,
        requestClient: const AbortableRequestClient(),
      );
    });

    tearDown(() async {
      await server.close(force: true);
      client.close();
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

      final result = await api.validateToken(
        accessToken: 'valid-token',
        refreshToken: 'refresh-token',
      );

      expect(
        result,
        isA<TokenValidationValid>()
            .having((value) => value.accessToken, 'accessToken', 'valid-token')
            .having((value) => value.refreshToken, 'refreshToken', 'refresh-token'),
      );
    });

    test('returns false when /auth/me returns 403', () async {
      _handleRequests(server, [
        _RequestResponse(
          path: '/auth/me',
          statusCode: 403,
          body: '',
        ),
      ]);

      final result = await api.validateToken(
        accessToken: 'valid-token',
        refreshToken: 'refresh-token',
      );

      expect(result, isA<TokenValidationInvalid>());
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

      final result = await api.validateToken(
        accessToken: 'expired-token',
        refreshToken: 'refresh-token',
      );

      expect(
        result,
        isA<TokenValidationValid>()
            .having((value) => value.accessToken, 'accessToken', 'new-access-token')
            .having((value) => value.refreshToken, 'refreshToken', 'new-refresh-token'),
      );
    });

    test('rejects a successful refresh response with empty tokens', () async {
      _handleRequests(server, [
        _RequestResponse(path: '/auth/me', statusCode: 401, body: ''),
        _RequestResponse(
          path: '/auth/refresh',
          statusCode: 200,
          body: jsonEncode({
            'accessToken': '',
            'refreshToken': '',
            'user': {
              'id': '1',
              'provider': 'github',
              'providerUserId': '1',
              'providerUsername': 'test',
            },
          }),
        ),
      ]);

      await expectLater(
        api.validateToken(accessToken: 'expired-token', refreshToken: 'refresh-token'),
        throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('missing tokens'))),
      );
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

      final result = await api.validateToken(
        accessToken: 'expired-token',
        refreshToken: 'invalid-refresh',
      );

      expect(result, isA<TokenValidationInvalid>());
    });

    test('throws on network error', () async {
      await server.close(force: true);

      expect(
        () => api.validateToken(
          accessToken: 'token',
          refreshToken: 'refresh',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _RequestResponse({required final String path, required final int statusCode, required final String body});

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
