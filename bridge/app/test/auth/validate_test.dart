import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/auth/auth_api.dart';
import 'package:sesori_bridge/src/foundation/abortable_request.dart';
import 'package:test/test.dart';

void main() {
  group('AuthApi credential endpoints', () {
    late HttpServer server;
    late http.Client client;
    late AuthApi api;

    setUp(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      client = http.Client();
      api = AuthApi(
        authBackendUrl: 'http://${server.address.host}:${server.port}',
        client: client,
        requestDeadline: AuthApi.defaultRequestDeadline,
        sendRequest: sendRequestWithDeadline,
      );
    });

    tearDown(() async {
      await server.close(force: true);
      client.close();
    });

    test('decodes /auth/me on 200', () async {
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

      final result = await api.getCurrentUser(accessToken: 'valid-token');

      expect(result.user.providerUsername, 'test');
    });

    test('preserves /auth/me rejection status', () async {
      _handleRequests(server, [
        _RequestResponse(
          path: '/auth/me',
          statusCode: 403,
          body: '',
        ),
      ]);

      await expectLater(
        api.getCurrentUser(accessToken: 'valid-token'),
        throwsA(isA<AuthApiException>().having((error) => error.statusCode, 'statusCode', 403)),
      );
    });

    test('decodes refreshed tokens on 200', () async {
      _handleRequests(server, [
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

      final result = await api.refreshToken(refreshToken: 'refresh-token');

      expect(result.accessToken, 'new-access-token');
      expect(result.refreshToken, 'new-refresh-token');
    });

    test('rejects a successful refresh response with empty tokens', () async {
      _handleRequests(server, [
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
        api.refreshToken(refreshToken: 'refresh-token'),
        throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('missing tokens'))),
      );
    });

    test('preserves refresh rejection status', () async {
      _handleRequests(server, [
        _RequestResponse(
          path: '/auth/refresh',
          statusCode: 401,
          body: '',
        ),
      ]);

      await expectLater(
        api.refreshToken(refreshToken: 'invalid-refresh'),
        throwsA(isA<AuthApiException>().having((error) => error.statusCode, 'statusCode', 401)),
      );
    });

    test('throws on network error', () async {
      await server.close(force: true);

      expect(
        () => api.getCurrentUser(accessToken: 'token'),
        throwsA(isA<Exception>()),
      );
    });

    test('actively aborts current-user and refresh requests at their deadline', () async {
      for (final operation in ['me', 'refresh']) {
        final abortAwareClient = _AbortAwareClient();
        final deadlineApi = AuthApi(
          authBackendUrl: 'https://auth.example.test',
          client: abortAwareClient,
          requestDeadline: Duration.zero,
          sendRequest: sendRequestWithDeadline,
        );

        final request = operation == 'me'
            ? deadlineApi.getCurrentUser(accessToken: 'token')
            : deadlineApi.refreshToken(refreshToken: 'refresh');
        await expectLater(request, throwsA(isA<http.RequestAbortedException>()));
        expect(abortAwareClient.abortObserved, isTrue);
      }
    });
  });
}

class _AbortAwareClient() extends http.BaseClient {
  bool abortObserved = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abortable = request as http.Abortable;
    await abortable.abortTrigger;
    abortObserved = true;
    throw http.RequestAbortedException(request.url);
  }
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
