import 'dart:convert';
import 'dart:io';

import 'package:sesori_bridge/src/auth/profile.dart';
import 'package:test/test.dart';

void main() {
  group('fetchUsername', () {
    late HttpServer server;
    late String baseUrl;

    setUp(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      baseUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('returns providerUsername on 200', () async {
      server.listen((request) async {
        if (request.uri.path == '/auth/me') {
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode({
              'user': {
                'id': '1',
                'provider': 'github',
                'providerUserId': '1',
                'providerUsername': 'testuser',
              },
            }),
          );
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });

      final username = await fetchUsername(baseUrl, 'valid-token');
      expect(username, equals('testuser'));
    });

    test('returns unknown-user when providerUsername is null', () async {
      server.listen((request) async {
        if (request.uri.path == '/auth/me') {
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode({
              'user': {
                'id': '1',
                'provider': 'github',
                'providerUserId': '1',
                'providerUsername': null,
              },
            }),
          );
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });

      final username = await fetchUsername(baseUrl, 'valid-token');
      expect(username, equals('unknown-user'));
    });

    test('throws on 401', () async {
      server.listen((request) async {
        request.response.statusCode = 401;
        await request.response.close();
      });

      expect(
        () => fetchUsername(baseUrl, 'invalid-token'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on network error', () async {
      await server.close(force: true);

      expect(
        () => fetchUsername('http://127.0.0.1:1', 'token'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
