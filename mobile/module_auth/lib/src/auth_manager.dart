import "dart:async";
import "dart:convert";
import "dart:developer" as developer;
import "dart:math";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "auth_config.dart";
import "interfaces/auth_session.dart";
import "interfaces/auth_token_provider.dart";
import "interfaces/oauth_flow_provider.dart";
import "models/auth_state.dart";
import "storage/oauth_storage_service.dart";
import "storage/token_storage_service.dart";

@lazySingleton
class AuthManager implements AuthTokenProvider, OAuthFlowProvider, AuthSession {
  static const _sessionTokenHeader = "X-Sesori-Session-Token";
  static const _mobileClientType = "app";
  static const _defaultPollInterval = Duration(milliseconds: 250);
  static const _defaultPollTimeout = Duration(minutes: 5);

  final http.Client _client;
  final TokenStorageService _tokenStorage;
  final OAuthStorageService _oAuthStorage;
  final BehaviorSubject<AuthState> _authState;
  final Duration _pollInterval;
  final Duration _pollTimeout;
  final Future<void> Function(Duration duration) _delay;
  String? _oAuthSessionToken;

  AuthManager(
    http.Client client,
    TokenStorageService tokenStorage,
    OAuthStorageService oAuthStorage, {
    @visibleForTesting Duration pollInterval = _defaultPollInterval,
    @visibleForTesting Duration pollTimeout = _defaultPollTimeout,
    @visibleForTesting Future<void> Function(Duration duration)? delay,
  }) : _client = client,
       _tokenStorage = tokenStorage,
       _oAuthStorage = oAuthStorage,
       _pollInterval = pollInterval,
       _pollTimeout = pollTimeout,
       _delay = delay ?? Future<void>.delayed,
       _authState = BehaviorSubject.seeded(const AuthState.initial());

  @override
  ValueStream<AuthState> get authStateStream => _authState.stream;

  @override
  AuthState get currentState => _authState.value;

  @override
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      return _refreshAndPersistTokens();
    }

    final tokenAndValidityLeft = await _tokenStorage.getAccessToken();

    if (tokenAndValidityLeft == null || tokenAndValidityLeft.validityLeft < minTtl) {
      return _refreshAndPersistTokens();
    }

    if (tokenAndValidityLeft.validityLeft < const Duration(seconds: 90)) {
      unawaited(_refreshAndPersistTokens());
    }

    return tokenAndValidityLeft.token;
  }

  @override
  Future<AuthInitResponse> startOAuthFlow({required OAuthProvider provider}) async {
    final sessionToken = _generateSessionToken();
    _oAuthSessionToken = sessionToken;

    try {
      final uri = Uri.parse("$authBaseUrl/auth/${provider.key}/init");
      final response = await _post(
        uri,
        body: const AuthInitRequest(clientType: _mobileClientType).toJson(),
        headers: {_sessionTokenHeader: sessionToken},
      );
      _ensureSuccess(response, context: "Failed to start ${provider.label} auth flow");

      return AuthInitResponse.fromJson(jsonDecodeMap(response.body));
    } catch (_) {
      _oAuthSessionToken = null;
      rethrow;
    }
  }

  @override
  Future<AuthUser> pollForResult() async {
    final sessionToken = _oAuthSessionToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw StateError("No OAuth flow is active");
    }

    final stopwatch = Stopwatch()..start();
    try {
      while (stopwatch.elapsed < _pollTimeout) {
        final uri = Uri.parse("$authBaseUrl/auth/session/status");
        final response = await _get(
          uri,
          headers: {_sessionTokenHeader: sessionToken},
        ).timeout(_pollTimeout - stopwatch.elapsed);

        final status = _parseSessionStatus(response);
        switch (status) {
          case AuthSessionStatusResponsePending():
            final remaining = _pollTimeout - stopwatch.elapsed;
            final delay = _pollInterval < remaining ? _pollInterval : remaining;
            if (delay > Duration.zero) {
              await _delay(delay);
            }
          case AuthSessionStatusResponseComplete(
            accessToken: final accessToken,
            refreshToken: final refreshToken,
            user: final user,
          ):
            await _persistOAuthCompletion(
              accessToken: accessToken,
              refreshToken: refreshToken,
              user: user,
            );
            return user;
          case AuthSessionStatusResponseDenied():
            throw StateError("OAuth authorization was denied");
          case AuthSessionStatusResponseExpired():
            throw StateError("OAuth authorization expired");
          case AuthSessionStatusResponseError():
            throw StateError("OAuth authorization failed");
        }
      }

      throw TimeoutException("OAuth authorization timed out", _pollTimeout);
    } finally {
      stopwatch.stop();
      _oAuthSessionToken = null;
    }
  }

  Future<void> _persistOAuthCompletion({
    required String accessToken,
    required String refreshToken,
    required AuthUser user,
  }) async {
    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    await Future.wait([
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
    ]);

    _authState.add(AuthState.authenticated(user: user));
  }

  AuthSessionStatusResponse _parseSessionStatus(http.Response response) {
    if (response.body.isNotEmpty) {
      try {
        return AuthSessionStatusResponse.fromJson(jsonDecodeMap(response.body));
      } on Object catch (e) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw Exception("Failed to parse auth session status response: ${e.toString()}");
        }
      }
    }

    _ensureSuccess(response, context: "OAuth session polling failed");
    throw StateError("OAuth session polling failed");
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    try {
      final accessToken = await getFreshAccessToken();
      if (accessToken == null) {
        return null;
      }

      final uri = Uri.parse("$authBaseUrl/auth/me");
      final response = await _get(
        uri,
        headers: _authHeader(accessToken),
      );
      _ensureSuccess(response, context: "Failed to fetch current user");

      final authMeResponse = AuthMeResponse.fromJson(jsonDecodeMap(response.body));
      return authMeResponse.user;
    } on http.ClientException catch (error, stackTrace) {
      developer.log(
        "Failed to fetch current user due to network error",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    } on FormatException catch (error, stackTrace) {
      developer.log(
        "Failed to parse current user response",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
      // ignore: avoid_catching_errors, StateError is thrown for non-2xx auth responses
    } on StateError catch (error, stackTrace) {
      developer.log(
        "Failed to fetch current user: auth/me returned non-success",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    }
  }

  @override
  Future<bool> hasLocallyValidSession() {
    return _tokenStorage.hasLocallyValidSession();
  }

  @override
  Future<bool> restoreSession() async {
    final user = await getCurrentUser();
    if (user == null) return false;

    _authState.add(AuthState.authenticated(user: user));
    return true;
  }

  @override
  Future<AuthUser> loginWithEmail({required String email, required String password}) async {
    final uri = Uri.parse("$authBaseUrl/auth/email");
    final response = await _post(
      uri,
      body: {"email": email, "password": password},
    );

    if (response.statusCode == 401) {
      throw Exception("Invalid email or password");
    }
    _ensureSuccess(response, context: "Email/password login failed");

    final decodedBody = jsonDecodeMap(response.body);
    final AuthResponse authResponse;
    try {
      authResponse = AuthResponse.fromJson(decodedBody);
    } on Object catch (e) {
      throw Exception("Failed to parse auth response: ${e.toString()}");
    }

    await _tokenStorage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );

    // Clear any stale OAuth temp state so a later deep-link callback
    // cannot unexpectedly exchange using stale PKCE data.
    await Future.wait([
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
    ]);

    _authState.add(AuthState.authenticated(user: authResponse.user));
    return authResponse.user;
  }

  @override
  Future<AuthUser> loginWithApple({required String idToken, required String nonce}) async {
    final uri = Uri.parse("$authBaseUrl/auth/apple/native");
    final response = await _post(
      uri,
      body: {"idToken": idToken, "nonce": nonce},
    );

    _ensureSuccess(response, context: "Apple Sign-In failed");

    final decodedBody = jsonDecodeMap(response.body);
    final AuthResponse authResponse;
    try {
      authResponse = AuthResponse.fromJson(decodedBody);
    } on Object catch (e) {
      throw Exception("Failed to parse auth response: ${e.toString()}");
    }

    await _tokenStorage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );

    // Clear any stale OAuth temp state so a later deep-link callback
    // cannot unexpectedly exchange using stale PKCE data.
    await Future.wait([
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
    ]);

    _authState.add(AuthState.authenticated(user: authResponse.user));
    return authResponse.user;
  }

  @override
  Future<void> invalidateAllSessions() async {
    final accessToken = await getFreshAccessToken();
    if (accessToken != null) {
      final uri = Uri.parse("$authBaseUrl/auth/logout");
      final response = await _post(
        uri,
        headers: _authHeader(accessToken),
      );
      _ensureSuccess(response, context: "Failed to invalidate all sessions");
    }

    await Future.wait([
      _tokenStorage.clearTokens(),
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
    ]);
    _authState.add(const AuthState.unauthenticated());
  }

  @override
  Future<void> logoutCurrentDevice() async {
    await Future.wait([
      _tokenStorage.clearTokens(),
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
    ]);
    _authState.add(const AuthState.unauthenticated());
  }

  Future<String?>? _activeRefresh;

  Future<String?> _refreshAndPersistTokens() {
    return _activeRefresh ??= _doRefreshAndPersist().whenComplete(() {
      _activeRefresh = null;
    });
  }

  Future<String?> _doRefreshAndPersist() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return null;
      }

      final uri = Uri.parse("$authBaseUrl/auth/refresh");
      final response = await _post(
        uri,
        body: {"refreshToken": refreshToken},
      );
      _ensureSuccess(response, context: "Token refresh failed");

      final decodedBody = jsonDecodeMap(response.body);
      final AuthResponse authResponse;
      try {
        authResponse = AuthResponse.fromJson(decodedBody);
      } on Object catch (e) {
        throw Exception("Failed to parse auth response: ${e.toString()}");
      }

      await _tokenStorage.saveTokens(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );

      return authResponse.accessToken;
    } catch (error, stackTrace) {
      developer.log(
        "Token refresh failed",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return null;
    }
  }

  String _generateSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<http.Response> _get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _client.get(
      url,
      headers: {
        "Accept": "application/json",
        ...?headers,
      },
    );
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, optional HTTP parameters
  Future<http.Response> _post(
    Uri url, {
    // ignore: no_slop_linter/prefer_specific_type
    Object? body,
    Map<String, String>? headers,
  }) {
    return _client.post(
      url,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        ...?headers,
      },
      body: body == null ? null : jsonEncode(body),
    );
  }

  Map<String, String> _authHeader(String accessToken) => {
    "Authorization": "Bearer $accessToken",
  };

  void _ensureSuccess(http.Response response, {required String context}) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError("$context (HTTP ${response.statusCode})");
    }
  }
}
