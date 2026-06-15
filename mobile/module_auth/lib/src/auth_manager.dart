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
  static const _defaultRequestTimeout = Duration(seconds: 35);

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

  /// Builds the singleton with only its production dependencies.
  ///
  /// injectable uses this factory instead of the default constructor so the
  /// `@visibleForTesting` seams (`pollInterval`, `pollTimeout`, `delay`) keep
  /// their defaults. Without it, injectable_generator 3.0.2 under analyzer 10.x
  /// tries to inject those optional params from get_it — and can't resolve the
  /// inline `delay` function type at all.
  @factoryMethod
  factory AuthManager.create(
    http.Client client,
    TokenStorageService tokenStorage,
    OAuthStorageService oAuthStorage,
  ) => AuthManager(client, tokenStorage, oAuthStorage);

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
    _logAuth("startOAuthFlow: provider=${provider.key} sessionToken=${_short(sessionToken)}");

    try {
      final uri = Uri.parse("$authBaseUrl/auth/${provider.key}/init");
      final response = await _post(
        uri,
        body: const AuthInitRequest(clientType: _mobileClientType).toJson(),
        headers: {_sessionTokenHeader: sessionToken},
      );
      _logAuth("startOAuthFlow: /auth/${provider.key}/init -> HTTP ${response.statusCode}");
      _ensureSuccess(response, context: "Failed to start ${provider.label} auth flow");

      final initResponse = AuthInitResponse.fromJson(jsonDecodeMap(response.body));
      final expiresAt = DateTime.now().add(Duration(seconds: initResponse.expiresIn));
      await _oAuthStorage.saveOAuthSession(
        sessionToken: sessionToken,
        expiresAt: expiresAt,
      );
      _logAuth(
        "startOAuthFlow: ready provider=${provider.key} userCode=${initResponse.userCode} "
        "expiresIn=${initResponse.expiresIn}s expiresAt=${expiresAt.toIso8601String()} "
        "authUrlHost=${Uri.tryParse(initResponse.authUrl)?.host}",
      );
      return initResponse;
    } catch (e, st) {
      _logAuth("startOAuthFlow: failed for provider=${provider.key}", e, st);
      _oAuthSessionToken = null;
      await _oAuthStorage.clearOAuthSession();
      rethrow;
    }
  }

  @override
  Future<AuthUser> pollForResult() async {
    final sessionToken = _oAuthSessionToken ?? (await _oAuthStorage.getOAuthSession()).sessionToken;
    final expiresAt = (await _oAuthStorage.getOAuthSession()).expiresAt;
    _logAuth(
      "pollForResult: start inMemoryToken=${_oAuthSessionToken != null} "
      "sessionToken=${sessionToken == null ? "null" : _short(sessionToken)} "
      "expiresAt=${expiresAt?.toIso8601String()}",
    );

    if (sessionToken == null || sessionToken.isEmpty) {
      _logAuth("pollForResult: aborting -- no active OAuth session token");
      throw StateError("No OAuth flow is active");
    }

    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      _logAuth("pollForResult: aborting -- session already expired at ${expiresAt.toIso8601String()}");
      await _oAuthStorage.clearOAuthSession();
      _oAuthSessionToken = null;
      throw TimeoutException("OAuth authorization expired");
    }

    var pollCount = 0;
    try {
      while (expiresAt == null || DateTime.now().isBefore(expiresAt)) {
        final remaining = expiresAt?.difference(DateTime.now()) ?? _pollTimeout;
        final requestTimeout = remaining < _defaultRequestTimeout ? remaining : _defaultRequestTimeout;
        if (requestTimeout <= Duration.zero) break;

        final uri = Uri.parse("$authBaseUrl/auth/session/status");
        pollCount++;
        final http.Response response;
        try {
          response = await _get(
            uri,
            headers: {_sessionTokenHeader: sessionToken},
          ).timeout(requestTimeout);
        } catch (e, st) {
          _logAuth("pollForResult: HTTP request failed on poll #$pollCount", e, st);
          rethrow;
        }

        final status = _parseSessionStatus(response);
        switch (status) {
          case AuthSessionStatusResponsePending():
            if (pollCount == 1 || pollCount % 40 == 0) {
              _logAuth("pollForResult: pending (poll #$pollCount, HTTP ${response.statusCode})");
            }
            final delayRemaining = expiresAt?.difference(DateTime.now()) ?? _pollTimeout;
            final delay = _pollInterval < delayRemaining ? _pollInterval : delayRemaining;
            if (delay > Duration.zero) {
              await _delay(delay);
            }
          case AuthSessionStatusResponseComplete(
            accessToken: final accessToken,
            refreshToken: final refreshToken,
            user: final user,
          ):
            _logAuth(
              "pollForResult: COMPLETE after $pollCount poll(s) -- "
              "user=${user.id} provider=${user.provider.key}",
            );
            await _persistOAuthCompletion(
              accessToken: accessToken,
              refreshToken: refreshToken,
              user: user,
            );
            return user;
          case AuthSessionStatusResponseDenied():
            _logAuth("pollForResult: DENIED after $pollCount poll(s)");
            await _oAuthStorage.clearOAuthSession();
            throw StateError("OAuth authorization was denied");
          case AuthSessionStatusResponseExpired():
            _logAuth("pollForResult: EXPIRED after $pollCount poll(s)");
            await _oAuthStorage.clearOAuthSession();
            throw StateError("OAuth authorization expired");
          case AuthSessionStatusResponseError(:final message):
            _logAuth("pollForResult: ERROR after $pollCount poll(s) -- message=$message");
            await _oAuthStorage.clearOAuthSession();
            throw StateError("OAuth authorization failed: $message");
        }
      }

      _logAuth("pollForResult: timed out after $pollCount poll(s)");
      await _oAuthStorage.clearOAuthSession();
      throw TimeoutException("OAuth authorization timed out");
    } finally {
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
    // Best-effort: the tokens above already make this a valid session, so a
    // local user-cache write failure must not abort a completed login.
    await _saveUserBestEffort(user);

    await Future.wait([
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
      _oAuthStorage.clearOAuthSession(),
    ]);

    _authState.add(AuthState.authenticated(user: user));
  }

  /// Persists [user] to local storage, swallowing (and logging) any failure.
  ///
  /// User caching only accelerates the offline restore path
  /// ([restoreLocalSession]); it is never authoritative. A write failure must
  /// not abort a flow whose tokens are already saved and whose in-memory
  /// session is valid, so callers stay authenticated even if this fails.
  Future<void> _saveUserBestEffort(AuthUser user) async {
    try {
      await _tokenStorage.saveUser(user);
    } catch (error, stackTrace) {
      developer.log(
        "Failed to persist user; continuing with the in-memory session",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
    }
  }

  AuthSessionStatusResponse _parseSessionStatus(http.Response response) {
    // Only trust the body on success (2xx) or the explicit 410 expired response.
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    final isExpired = response.statusCode == 410;

    if (!isSuccess && !isExpired) {
      _logAuth(
        "session/status: non-success HTTP ${response.statusCode} body=${_bodyPreview(response.body)}",
      );
      _ensureSuccess(response, context: "OAuth session polling failed");
      throw StateError("OAuth session polling failed");
    }

    if (response.body.isNotEmpty) {
      try {
        return AuthSessionStatusResponse.fromJson(jsonDecodeMap(response.body));
      } on Object catch (e) {
        _logAuth(
          "session/status: parse failure HTTP ${response.statusCode} body=${_bodyPreview(response.body)}",
          e,
        );
        throw Exception("Failed to parse auth session status response: ${e.toString()}");
      }
    }

    _logAuth("session/status: empty body with HTTP ${response.statusCode}");
    throw StateError("OAuth session polling failed: empty response body");
  }

  @override
  Future<AuthUser> resumeOAuthFlow() async {
    final session = await _oAuthStorage.getOAuthSession();
    final storedToken = session.sessionToken;
    _logAuth(
      "resumeOAuthFlow: sessionToken=${storedToken == null ? "null" : _short(storedToken)} "
      "expiresAt=${session.expiresAt?.toIso8601String()}",
    );
    if (storedToken == null) {
      _logAuth("resumeOAuthFlow: aborting -- no stored OAuth session");
      throw StateError("No OAuth flow is active");
    }
    return pollForResult();
  }

  @override
  Future<bool> hasActiveOAuthSession() async {
    final session = await _oAuthStorage.getOAuthSession();
    if (session.sessionToken == null || session.expiresAt == null) {
      _logAuth(
        "hasActiveOAuthSession: false (hasToken=${session.sessionToken != null}, "
        "hasExpiry=${session.expiresAt != null})",
      );
      return false;
    }
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    final active = DateTime.now().isBefore(expiresAt);
    _logAuth("hasActiveOAuthSession: $active (expiresAt=${expiresAt.toIso8601String()})");
    return active;
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

    // Persist the user for sessions that were authenticated before it was
    // stored locally; /auth/me is the authoritative source for the value.
    // Best-effort: a local persistence failure must not block restoring a
    // session that /auth/me just confirmed.
    await _saveUserBestEffort(user);
    _authState.add(AuthState.authenticated(user: user));
    return true;
  }

  @override
  Future<bool> restoreLocalSession() async {
    try {
      if (!await _tokenStorage.hasLocallyValidSession()) return false;
      final user = await _tokenStorage.getUser();
      if (user == null) return false;

      _authState.add(AuthState.authenticated(user: user));
      return true;
    } catch (error, stackTrace) {
      developer.log(
        "Failed to restore local session",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
      return false;
    }
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
    await _tokenStorage.saveUser(authResponse.user);

    // Clear any stale OAuth temp state so a later deep-link callback
    // cannot unexpectedly exchange using stale PKCE data.
    await Future.wait([
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
      _oAuthStorage.clearOAuthSession(),
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
    await _tokenStorage.saveUser(authResponse.user);

    // Clear any stale OAuth temp state so a later deep-link callback
    // cannot unexpectedly exchange using stale PKCE data.
    await Future.wait([
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
      _oAuthStorage.clearOAuthSession(),
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
      _oAuthStorage.clearOAuthSession(),
    ]);
    _authState.add(const AuthState.unauthenticated());
  }

  @override
  Future<void> logoutCurrentDevice() async {
    await Future.wait([
      _tokenStorage.clearTokens(),
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
      _oAuthStorage.clearOAuthSession(),
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
      _logAuth("$context (HTTP ${response.statusCode}) body=${_bodyPreview(response.body)}");
      throw StateError("$context (HTTP ${response.statusCode})");
    }
  }

  /// Structured auth diagnostics routed through `dart:developer` under the
  /// shared `sesori_auth` log name, so they can be filtered in `flutter logs`
  /// and the DevTools logging view.
  // ignore: no_slop_linter/prefer_required_named_parameters, logging convenience API keeps optional positional context
  void _logAuth(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: "sesori_auth",
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// First 8 chars of a token-like value, for correlating logs across the flow
  /// without leaking the full secret.
  String _short(String value) => value.length <= 8 ? value : "${value.substring(0, 8)}...";

  /// Truncates an HTTP body for logging. Only ever called on non-success,
  /// parse-failure, or empty responses -- never on a successfully parsed
  /// "complete" body -- so access/refresh tokens are never written to logs.
  String _bodyPreview(String body) {
    final trimmed = body.trim();
    const maxChars = 500;
    if (trimmed.length <= maxChars) return trimmed;
    return "${trimmed.substring(0, maxChars)}... (${trimmed.length} chars total)";
  }
}
