// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/auth/login_email_api.dart';
import 'package:sesori_bridge/src/auth/login_email_repository.dart';
import 'package:sesori_bridge/src/auth/login_oauth_api.dart';
import 'package:sesori_bridge/src/auth/login_oauth_service.dart';
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  group('LoginOAuthApi', () {
    group('GitHub OAuth', () {
      test('performOAuthLogin initializes, opens browser, polls, and returns tokens', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [
            const AuthSessionStatusResponse.pending(),
            AuthSessionStatusResponse.complete(
              accessToken: 'github-access-token',
              refreshToken: 'github-refresh-token',
              user: AuthUser(
                id: 'user-1',
                provider: 'github',
                providerUserId: 'gh-1',
                providerUsername: 'octocat',
              ),
            ),
          ],
        );
        addTearDown(authServer.close);
        final launchedUrls = <String>[];

        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (url) async => launchedUrls.add(url),
        );

        final tokens = await service.performOAuthLogin(AuthProvider.github);

        expect(tokens.accessToken, equals('github-access-token'));
        expect(tokens.refreshToken, equals('github-refresh-token'));
        expect(tokens.lastProvider, equals(AuthProvider.github));
        expect(launchedUrls, equals(['https://example.com/github-login']));
        expect(authServer.initRequests, hasLength(1));
        expect(authServer.statusRequests, hasLength(2));

        final initRequest = authServer.initRequests.single;
        expect(initRequest.method, equals('POST'));
        expect(initRequest.path, equals('/auth/github/init'));
        expect(initRequest.queryParameters, isEmpty);
        expect(initRequest.body, equals({'clientType': 'bridge'}));
        expect(initRequest.contentType, startsWith('application/json'));
        expect(initRequest.sessionToken, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(initRequest.body!.values, isNot(contains(initRequest.sessionToken)));
        expect(authServer.authUrl, isNot(contains(initRequest.sessionToken)));

        for (final statusRequest in authServer.statusRequests) {
          expect(statusRequest.method, equals('GET'));
          expect(statusRequest.path, equals('/auth/session/status'));
          expect(statusRequest.queryParameters, isEmpty);
          expect(statusRequest.sessionToken, equals(initRequest.sessionToken));
        }
        expect(authServer.unexpectedPaths, isNot(contains('/callback')));
      });

      test('denied status throws', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [const AuthSessionStatusResponse.denied()],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
        );

        expect(
          service.performOAuthLogin(AuthProvider.github),
          throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('denied'))),
        );
      });
    });

    group('Google OAuth', () {
      test('performOAuthLogin requests Google init path', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          authUrl: 'https://example.com/google-login',
          statusResponses: [
            AuthSessionStatusResponse.complete(
              accessToken: 'google-access-token',
              refreshToken: 'google-refresh-token',
              user: AuthUser(
                id: 'user-1',
                provider: 'google',
                providerUserId: 'google-1',
                providerUsername: null,
              ),
            ),
          ],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
        );

        final tokens = await service.performOAuthLogin(AuthProvider.google);

        expect(tokens.accessToken, equals('google-access-token'));
        expect(tokens.refreshToken, equals('google-refresh-token'));
        expect(tokens.lastProvider, equals(AuthProvider.google));
        expect(authServer.initRequests.single.path, equals('/auth/google/init'));
        expect(authServer.initRequests.single.queryParameters, isEmpty);
        expect(authServer.unexpectedPaths, isNot(contains('/callback')));
      });

      test('expired status throws', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [const AuthSessionStatusResponse.expired()],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
        );

        expect(
          service.performOAuthLogin(AuthProvider.google),
          throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('expired'))),
        );
      });

      test('error status throws', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [const AuthSessionStatusResponse.error(message: 'provider failed')],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
        );

        expect(
          service.performOAuthLogin(AuthProvider.google),
          throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('provider failed'))),
        );
      });

      test('pending status times out', () async {
        final authServer = await _OAuthLongPollTestServer.start(
          statusResponses: [const AuthSessionStatusResponse.pending()],
        );
        addTearDown(authServer.close);
        final service = _createOAuthService(
          authServer: authServer,
          browserLauncher: (_) async {},
          pollTimeout: const Duration(milliseconds: 5),
          pollInterval: const Duration(milliseconds: 1),
        );

        expect(
          service.performOAuthLogin(AuthProvider.google),
          throwsA(isA<TimeoutException>()),
        );
      });
    });
  });

  group('LoginEmailApi', () {
    test('loginWithEmail POSTs to /auth/email and returns tokens', () async {
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

      final api = LoginEmailApi(authBackendUrl: authServer.baseUrl);
      final authResponse = await api.loginWithEmail(
        email: 'test@example.com',
        password: 'correct-password',
      );

      expect(authServer.lastLoginRequest, isNotNull);
      expect(authServer.lastLoginRequest!['email'], equals('test@example.com'));
      expect(authServer.lastLoginRequest!['password'], equals('correct-password'));
      expect(authResponse.accessToken, equals('test-access-token'));
      expect(authResponse.refreshToken, equals('test-refresh-token'));
      expect(authResponse.user.providerUsername, equals('testuser'));
    });

    test('loginWithEmail throws EmailAuthApiException on 401', () async {
      final authServer = await _PasswordLoginTestServer.start();
      authServer.onLoginRequest = (email, password) async {
        return _PasswordLoginResult.failure(401);
      };
      addTearDown(authServer.close);

      final api = LoginEmailApi(authBackendUrl: authServer.baseUrl);
      expect(
        () => api.loginWithEmail(
          email: 'bad@example.com',
          password: 'wrong-password',
        ),
        throwsA(isA<EmailAuthApiException>()),
      );
    });

    test('loginWithEmail throws EmailAuthApiException on 429', () async {
      final authServer = await _PasswordLoginTestServer.start();
      authServer.onLoginRequest = (email, password) async {
        return _PasswordLoginResult.failure(429);
      };
      addTearDown(authServer.close);

      final api = LoginEmailApi(authBackendUrl: authServer.baseUrl);
      expect(
        () => api.loginWithEmail(
          email: 'test@example.com',
          password: 'password',
        ),
        throwsA(isA<EmailAuthApiException>()),
      );
    });
  });

  group('LoginEmailRepository', () {
    ({String email, String password}) mockPrompt() {
      return (email: 'test@example.com', password: 'password123');
    }

    test('successful login returns TokenData with email provider', () async {
      final mockApi = _MockLoginEmailApi();
      final repository = LoginEmailRepository(
        emailAuthApi: mockApi,
        promptForCredentials: mockPrompt,
      );

      final tokens = await repository.performEmailLogin();

      expect(tokens.accessToken, equals('test-access-token'));
      expect(tokens.refreshToken, equals('test-refresh-token'));
      expect(tokens.lastProvider, equals(AuthProvider.email));
    });

    test('401 from API throws EmailLoginExceptionImpl', () async {
      final mockApi = _MockLoginEmailApi.unauthorized();
      final repository = LoginEmailRepository(
        emailAuthApi: mockApi,
        promptForCredentials: mockPrompt,
      );

      expect(
        repository.performEmailLogin,
        throwsA(isA<EmailLoginExceptionImpl>()),
      );
    });

    test('429 from API throws RateLimitException', () async {
      final mockApi = _MockLoginEmailApi.rateLimited();
      final repository = LoginEmailRepository(
        emailAuthApi: mockApi,
        promptForCredentials: mockPrompt,
      );

      expect(
        repository.performEmailLogin,
        throwsA(isA<RateLimitException>()),
      );
    });

    test('missing tokens throws EmailLoginExceptionImpl', () async {
      final mockApi = _MockLoginEmailApi.emptyTokens();
      final repository = LoginEmailRepository(
        emailAuthApi: mockApi,
        promptForCredentials: mockPrompt,
      );

      expect(
        repository.performEmailLogin,
        throwsA(isA<EmailLoginExceptionImpl>()),
      );
    });
  });
}

LoginOAuthService _createOAuthService({
  required _OAuthLongPollTestServer authServer,
  required Future<void> Function(String url) browserLauncher,
  Duration pollTimeout = const Duration(seconds: 2),
  Duration pollInterval = Duration.zero,
  Future<void> Function(Duration duration)? delay,
}) {
  return LoginOAuthService(
    api: LoginOAuthApi(
      authBackendUrl: authServer.baseUrl,
      client: authServer.client,
    ),
    browserLauncher: browserLauncher,
    pollTimeout: pollTimeout,
    pollInterval: pollInterval,
    delay: delay,
  );
}

class _MockLoginEmailApi implements LoginEmailApi {
  @override
  final String authBackendUrl = 'http://test';
  final AuthResponse _response;
  final int? _errorStatus;

  factory _MockLoginEmailApi() {
    return _MockLoginEmailApi._(
      AuthResponse(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        user: AuthUser(
          id: 'user-1',
          provider: 'email',
          providerUserId: 'user-1',
          providerUsername: 'testuser',
        ),
      ),
      null,
    );
  }

  _MockLoginEmailApi._(this._response, this._errorStatus);

  factory _MockLoginEmailApi.unauthorized() => _MockLoginEmailApi._(
    AuthResponse(
      accessToken: '',
      refreshToken: '',
      user: AuthUser(id: '', provider: '', providerUserId: '', providerUsername: null),
    ),
    401,
  );

  factory _MockLoginEmailApi.rateLimited() => _MockLoginEmailApi._(
    AuthResponse(
      accessToken: '',
      refreshToken: '',
      user: AuthUser(id: '', provider: '', providerUserId: '', providerUsername: null),
    ),
    429,
  );

  factory _MockLoginEmailApi.emptyTokens() => _MockLoginEmailApi._(
    AuthResponse(
      accessToken: '',
      refreshToken: '',
      user: AuthUser(
        id: 'user-1',
        provider: 'email',
        providerUserId: 'user-1',
        providerUsername: 'testuser',
      ),
    ),
    null,
  );

  @override
  Future<AuthResponse> loginWithEmail({required String email, required String password}) async {
    if (_errorStatus == 401) {
      throw EmailAuthApiException(statusCode: 401, body: 'Unauthorized');
    }
    if (_errorStatus == 429) {
      throw EmailAuthApiException(statusCode: 429, body: 'Rate limited');
    }
    return _response;
  }
}

class _OAuthRequestRecord {
  final String method;
  final String path;
  final Map<String, String> queryParameters;
  final String? sessionToken;
  final String? contentType;
  final Map<String, dynamic>? body;

  _OAuthRequestRecord({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.sessionToken,
    required this.contentType,
    required this.body,
  });
}

class _OAuthLongPollTestServer {
  final HttpServer _server;
  final String authUrl;
  final List<AuthSessionStatusResponse> _statusResponses;
  final http.Client client = http.Client();
  final List<_OAuthRequestRecord> initRequests = [];
  final List<_OAuthRequestRecord> statusRequests = [];
  final List<String> unexpectedPaths = [];

  _OAuthLongPollTestServer._({
    required HttpServer server,
    required this.authUrl,
    required List<AuthSessionStatusResponse> statusResponses,
  }) : _server = server,
       _statusResponses = List.of(statusResponses) {
    _listen();
  }

  static Future<_OAuthLongPollTestServer> start({
    String authUrl = 'https://example.com/github-login',
    required List<AuthSessionStatusResponse> statusResponses,
  }) async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    return _OAuthLongPollTestServer._(
      server: server,
      authUrl: authUrl,
      statusResponses: statusResponses,
    );
  }

  String get baseUrl => 'http://${_server.address.host}:${_server.port}';

  void _listen() {
    _server.listen((request) async {
      if ((request.uri.path == '/auth/github/init' || request.uri.path == '/auth/google/init') &&
          request.method == 'POST') {
        initRequests.add(await _recordRequest(request));
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'authUrl': authUrl,
            'state': 'oauth-state',
            'userCode': 'ABCD',
            'expiresIn': 120,
          }),
        );
        await request.response.close();
      } else if (request.uri.path == '/auth/session/status' && request.method == 'GET') {
        statusRequests.add(await _recordRequest(request));
        final status = _statusResponses.isEmpty
            ? const AuthSessionStatusResponse.pending()
            : _statusResponses.removeAt(0);
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(status.toJson()));
        await request.response.close();
      } else {
        unexpectedPaths.add(request.uri.path);
        request.response.statusCode = 404;
        await request.response.close();
      }
    });
  }

  Future<_OAuthRequestRecord> _recordRequest(HttpRequest request) async {
    Map<String, dynamic>? body;
    if (request.method == 'POST') {
      final content = await request.fold<List<int>>(
        [],
        (prev, element) => prev..addAll(element as List<int>),
      );
      final text = utf8.decode(Uint8List.fromList(content));
      body = text.isEmpty ? null : jsonDecodeMap(text);
    }

    return _OAuthRequestRecord(
      method: request.method,
      path: request.uri.path,
      queryParameters: Map.of(request.uri.queryParameters),
      sessionToken: request.headers.value(oauthSessionTokenHeader),
      contentType: request.headers.contentType?.mimeType,
      body: body,
    );
  }

  Future<void> close() async {
    client.close();
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
