import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/auth/auth_api.dart';
import 'package:sesori_bridge/src/auth/auth_repository.dart';
import 'package:test/test.dart';

void main() {
  group('fetchUsername', () {
    late HttpServer server;
    late http.Client client;
    late AuthRepository repository;

    setUp(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      client = http.Client();
      repository = AuthRepository(
        api: AuthApi(
          authBackendUrl: 'http://${server.address.host}:${server.port}',
          client: client,
          requestDeadline: AuthApi.defaultRequestDeadline,
        ),
      );
    });

    tearDown(() async {
      await server.close(force: true);
      client.close();
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
              'bridges': <Object>[],
            }),
          );
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });

      final username = await repository.fetchUsername(accessToken: 'valid-token');
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
              'bridges': <Object>[],
            }),
          );
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });

      final username = await repository.fetchUsername(accessToken: 'valid-token');
      expect(username, equals('unknown-user'));
    });

    test('throws on 401', () async {
      server.listen((request) async {
        request.response.statusCode = 401;
        await request.response.close();
      });

      expect(
        () => repository.fetchUsername(accessToken: 'invalid-token'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on network error', () async {
      await server.close(force: true);

      expect(
        () => repository.fetchUsername(accessToken: 'token'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
