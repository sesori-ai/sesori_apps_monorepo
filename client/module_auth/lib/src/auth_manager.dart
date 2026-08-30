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
import "models/auth_login_result.dart";
import "models/auth_state.dart";
import "platform/oauth_device_descriptor_provider.dart";
import "storage/oauth_storage_service.dart";
import "storage/token_storage_service.dart";

@lazySingleton
class AuthManager(
  final http.Client _client,
  final TokenStorageService _tokenStorage,
  final OAuthStorageService _oAuthStorage,
  final OAuthDeviceDescriptorProvider _deviceDescriptorProvider, {
  @visibleForTesting final Duration _pollInterval = _defaultPollInterval,
  @visibleForTesting final Duration _pollTimeout = _defaultPollTimeout,
  @visibleForTesting Future<void> Function(Duration duration)? delay,
}) implements AuthTokenProvider, OAuthFlowProvider, AuthSession {
  static const _sessionTokenHeader = "X-Sesori-Session-Token";
  static const _defaultPollInterval = Duration(milliseconds: 250);
  static const _defaultPollTimeout = Duration(minutes: 5);
  static const _defaultRequestTimeout = Duration(seconds: 35);
  static const _ackRequestTimeout = Duration(seconds: 5);

  final BehaviorSubject<AuthState> _authState;
  final Future<void> Function(Duration duration) _delay = delay ?? Future<void>.delayed;
  final _AuthMutationLock _mutationLock = _AuthMutationLock();
  String? _oAuthSessionToken;
  int? _oAuthSessionGeneration;
  int _logoutGeneration = 0;

  this : _authState = BehaviorSubject.seeded(const AuthState.initial());

  /// Builds the singleton with only its production dependencies.
  ///
  /// injectable uses this factory instead of the default constructor so the
  /// `@visibleForTesting` seams (`pollInterval`, `pollTimeout`, `delay`) keep
  /// their defaults. Without it, injectable_generator 3.0.2 under analyzer 10.x
  /// tries to inject those optional params from get_it — and can't resolve the
  /// inline `delay` function type at all.
  @factoryMethod
  factory create(
    http.Client client,
    TokenStorageService tokenStorage,
    OAuthStorageService oAuthStorage,
    OAuthDeviceDescriptorProvider deviceDescriptorProvider,
  ) => AuthManager(client, tokenStorage, oAuthStorage, deviceDescriptorProvider);

  @override
  ValueStream<AuthState> get authStateStream => _authState.stream;

  @override
  AuthState get currentState => _authState.value;

  bool _isCurrentGeneration({required int generation}) => generation == _logoutGeneration;

  /// Starts a new auth epoch and invalidates results from the prior epoch.
  ///
  /// Logout and a new interactive login both use this boundary: a restore or
  /// refresh that started for the previous account must not overwrite the
  /// account the user is now establishing.
  int _beginAuthGeneration() {
    final int generation = ++_logoutGeneration;
    _oAuthSessionToken = null;
    _oAuthSessionGeneration = null;
    return generation;
  }

  int _beginLocalLogout() => _beginAuthGeneration();

  int _beginInteractiveLogin() => _beginAuthGeneration();

  void _throwIfGenerationSuperseded({required int generation}) {
    if (!_isCurrentGeneration(generation: generation)) {
      throw const _AuthFlowSuperseded();
    }
  }

  @override
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) {
    final int generation = _logoutGeneration;
    return _getFreshAccessToken(
      generation: generation,
      minTtl: minTtl,
      forceRefresh: forceRefresh,
    );
  }

  Future<String?> _getFreshAccessToken({
    required int generation,
    required Duration minTtl,
    required bool forceRefresh,
  }) async {
    if (!_isCurrentGeneration(generation: generation)) {
      return null;
    }
    if (forceRefresh) {
      final String? token = await _refreshAndPersistTokens(generation: generation);
      return _isCurrentGeneration(generation: generation) ? token : null;
    }

    final tokenAndValidityLeft = await _tokenStorage.getAccessToken();
    if (!_isCurrentGeneration(generation: generation)) {
      return null;
    }

    if (tokenAndValidityLeft == null || tokenAndValidityLeft.validityLeft < minTtl) {
      final String? token = await _refreshAndPersistTokens(generation: generation);
      return _isCurrentGeneration(generation: generation) ? token : null;
    }

    if (tokenAndValidityLeft.validityLeft < const Duration(seconds: 90)) {
      unawaited(_refreshAndPersistTokens(generation: generation));
    }

    return _isCurrentGeneration(generation: generation) ? tokenAndValidityLeft.token : null;
  }

  @override
  Future<AuthInitResponse> startOAuthFlow({required OAuthProvider provider}) async {
    final int generation = _beginInteractiveLogin();
    final String sessionToken = _generateSessionToken();
    _oAuthSessionToken = sessionToken;
    _oAuthSessionGeneration = generation;

    try {
      final descriptor = await _deviceDescriptorProvider.describe();
      final uri = Uri.parse("$authBaseUrl/auth/${provider.key}/init");
      final response = await _post(
        uri,
        body: AuthInitRequest(clientType: descriptor.clientType, device: descriptor.device).toJson(),
        headers: {_sessionTokenHeader: sessionToken},
      );
      _ensureSuccess(response, context: "Failed to start ${provider.label} auth flow");

      final initResponse = AuthInitResponse.fromJson(jsonDecodeMap(response.body));
      final expiresAt = DateTime.now().add(Duration(seconds: initResponse.expiresIn));
      await _mutationLock.run(
        action: () async {
          _throwIfGenerationSuperseded(generation: generation);
          if (!_ownsOAuthSession(generation: generation, sessionToken: sessionToken)) {
            throw const _AuthFlowSuperseded();
          }
          await _oAuthStorage.saveOAuthSession(
            sessionToken: sessionToken,
            expiresAt: expiresAt,
          );
          _throwIfGenerationSuperseded(generation: generation);
          if (!_ownsOAuthSession(generation: generation, sessionToken: sessionToken)) {
            throw const _AuthFlowSuperseded();
          }
        },
      );
      _throwIfGenerationSuperseded(generation: generation);
      if (!_ownsOAuthSession(generation: generation, sessionToken: sessionToken)) {
        throw const _AuthFlowSuperseded();
      }
      return initResponse;
    } on Object catch (error, stackTrace) {
      try {
        await _clearOAuthStateIfOwned(generation: generation, sessionToken: sessionToken);
      } on Object catch (cleanupError, cleanupStackTrace) {
        developer.log(
          "Failed to clear OAuth state after starting the flow failed",
          error: cleanupError,
          stackTrace: cleanupStackTrace,
          name: "sesori_auth",
        );
      }
      if (identical(_oAuthSessionToken, sessionToken)) {
        _oAuthSessionToken = null;
        _oAuthSessionGeneration = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<AuthLoginResult> pollForResult() async {
    final int observedGeneration = _logoutGeneration;
    final String? initialSessionToken = _oAuthSessionToken;
    final int? initialSessionGeneration = _oAuthSessionGeneration;
    final storedSession = await _oAuthStorage.getOAuthSession();

    _throwIfGenerationSuperseded(generation: observedGeneration);
    if (_oAuthSessionToken != initialSessionToken || _oAuthSessionGeneration != initialSessionGeneration) {
      throw const _AuthFlowSuperseded();
    }

    final String? sessionToken = initialSessionToken ?? storedSession.sessionToken;
    final DateTime? expiresAt = storedSession.expiresAt;
    if (sessionToken == null || sessionToken.isEmpty) {
      throw StateError("No OAuth flow is active");
    }
    final int generation;
    if (initialSessionToken == null) {
      // A persisted OAuth flow is a new interactive login after a relaunch;
      // advance the epoch so an older restore or refresh cannot win over it.
      generation = _beginInteractiveLogin();
      _oAuthSessionToken = sessionToken;
      _oAuthSessionGeneration = generation;
    } else {
      generation = observedGeneration;
    }
    if (!_ownsOAuthSession(generation: generation, sessionToken: sessionToken)) {
      throw const _AuthFlowSuperseded();
    }

    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      try {
        await _clearOAuthStateIfOwned(generation: generation, sessionToken: sessionToken);
      } finally {
        _releaseOAuthSessionIfOwned(generation: generation, sessionToken: sessionToken);
      }
      throw TimeoutException("OAuth authorization expired");
    }

    try {
      while (expiresAt == null || DateTime.now().isBefore(expiresAt)) {
        _throwIfGenerationSuperseded(generation: generation);
        if (!_ownsOAuthSession(generation: generation, sessionToken: sessionToken)) {
          throw const _AuthFlowSuperseded();
        }
        final remaining = expiresAt?.difference(DateTime.now()) ?? _pollTimeout;
        final requestTimeout = remaining < _defaultRequestTimeout ? remaining : _defaultRequestTimeout;
        if (requestTimeout <= Duration.zero) break;
        final isFinalRequest = expiresAt != null && remaining <= _defaultRequestTimeout;

        final uri = Uri.parse("$authBaseUrl/auth/session/status");
        final http.Response response;
        try {
          response = await _getSessionStatus(
            uri: uri,
            sessionToken: sessionToken,
            requestTimeout: requestTimeout,
            expiresAt: expiresAt,
            isFinalRequest: isFinalRequest,
          );
        } on TimeoutException {
          await _clearOAuthStateIfOwned(generation: generation, sessionToken: sessionToken);
          rethrow;
        }
        _throwIfGenerationSuperseded(generation: generation);

        final status = _parseSessionStatus(response);
        switch (status) {
          case AuthSessionStatusResponsePending():
            final delayRemaining = expiresAt?.difference(DateTime.now()) ?? _pollTimeout;
            final delay = _pollInterval < delayRemaining ? _pollInterval : delayRemaining;
            if (delay > Duration.zero) {
              await _delay(delay);
            }
          case AuthSessionStatusResponseComplete(
            :final accessToken,
            :final refreshToken,
            :final user,
            :final accountStatus,
          ):
            final bool persisted = await _persistAuthenticatedResult(
              generation: generation,
              accessToken: accessToken,
              refreshToken: refreshToken,
              user: user,
              clearOAuthState: true,
              requireOAuthOwnership: true,
              oauthSessionToken: sessionToken,
            );
            if (!persisted) {
              throw const _AuthFlowSuperseded();
            }
            _ackOAuthCompletion(sessionToken: sessionToken);
            return AuthLoginResult(user: user, accountStatus: accountStatus);
          case AuthSessionStatusResponseDenied():
            await _clearOAuthStateIfOwned(generation: generation, sessionToken: sessionToken);
            throw StateError("OAuth authorization was denied");
          case AuthSessionStatusResponseExpired():
            await _clearOAuthStateIfOwned(generation: generation, sessionToken: sessionToken);
            throw StateError("OAuth authorization expired");
          case AuthSessionStatusResponseError(:final message):
            await _clearOAuthStateIfOwned(generation: generation, sessionToken: sessionToken);
            throw StateError("OAuth authorization failed: $message");
        }
      }

      await _clearOAuthStateIfOwned(generation: generation, sessionToken: sessionToken);
      _throwIfGenerationSuperseded(generation: generation);
      throw TimeoutException("OAuth authorization timed out");
    } finally {
      _releaseOAuthSessionIfOwned(generation: generation, sessionToken: sessionToken);
    }
  }

  void _releaseOAuthSessionIfOwned({required int generation, required String sessionToken}) {
    if (_ownsOAuthSession(generation: generation, sessionToken: sessionToken)) {
      _oAuthSessionToken = null;
      _oAuthSessionGeneration = null;
    }
  }

  Future<http.Response> _getSessionStatus({
    required Uri uri,
    required String sessionToken,
    required Duration requestTimeout,
    required DateTime? expiresAt,
    required bool isFinalRequest,
  }) async {
    try {
      return await _get(
        uri,
        headers: {_sessionTokenHeader: sessionToken},
      ).timeout(requestTimeout);
    } on TimeoutException catch (_, stackTrace) {
      if (isFinalRequest || (expiresAt != null && !DateTime.now().isBefore(expiresAt))) {
        Error.throwWithStackTrace(
          TimeoutException("OAuth authorization timed out"),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(
        http.ClientException("OAuth session status request timed out", uri),
        stackTrace,
      );
    }
  }

  Future<bool> _persistAuthenticatedResult({
    required int generation,
    required String accessToken,
    required String refreshToken,
    required AuthUser user,
    required bool clearOAuthState,
    required bool requireOAuthOwnership,
    required String? oauthSessionToken,
  }) {
    return _mutationLock.run(
      action: () async {
        if (!_isCurrentGeneration(generation: generation)) {
          return false;
        }
        if (requireOAuthOwnership && !_ownsOAuthSession(generation: generation, sessionToken: oauthSessionToken)) {
          return false;
        }

        await _tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        if (!_isCurrentGeneration(generation: generation) ||
            (requireOAuthOwnership && !_ownsOAuthSession(generation: generation, sessionToken: oauthSessionToken))) {
          await _clearTokensAfterSupersededResult();
          return false;
        }

        final bool userSaved = await _saveUserBestEffort(
          user: user,
          generation: generation,
        );
        if (!userSaved ||
            !_isCurrentGeneration(generation: generation) ||
            (requireOAuthOwnership && !_ownsOAuthSession(generation: generation, sessionToken: oauthSessionToken))) {
          await _clearTokensAfterSupersededResult();
          return false;
        }

        if (clearOAuthState) {
          final bool oauthStateCleared = await _clearOAuthStateInMutation(
            generation: generation,
            sessionToken: oauthSessionToken,
            requireOwnership: requireOAuthOwnership,
          );
          if (!oauthStateCleared ||
              !_isCurrentGeneration(generation: generation) ||
              (requireOAuthOwnership && !_ownsOAuthSession(generation: generation, sessionToken: oauthSessionToken))) {
            await _clearTokensAfterSupersededResult();
            return false;
          }
        }

        if (!_isCurrentGeneration(generation: generation) ||
            (requireOAuthOwnership && !_ownsOAuthSession(generation: generation, sessionToken: oauthSessionToken))) {
          await _clearTokensAfterSupersededResult();
          return false;
        }
        _authState.add(AuthState.authenticated(user: user));
        return true;
      },
    );
  }

  bool _ownsOAuthSession({required int generation, required String? sessionToken}) =>
      sessionToken != null && _oAuthSessionGeneration == generation && _oAuthSessionToken == sessionToken;

  Future<void> _clearOAuthStateIfOwned({required int generation, required String? sessionToken}) {
    return _mutationLock.run(
      action: () => _clearOAuthStateInMutation(
        generation: generation,
        sessionToken: sessionToken,
        requireOwnership: true,
      ),
    );
  }

  Future<bool> _clearOAuthStateInMutation({
    required int generation,
    required String? sessionToken,
    required bool requireOwnership,
  }) async {
    if (!_isCurrentGeneration(generation: generation) ||
        (requireOwnership && !_ownsOAuthSession(generation: generation, sessionToken: sessionToken))) {
      return false;
    }

    Object? firstCleanupError;
    StackTrace? firstCleanupStackTrace;

    Future<void> attemptCleanup({required Future<void> Function() action}) async {
      try {
        await action();
      } catch (error, stackTrace) {
        firstCleanupError ??= error;
        firstCleanupStackTrace ??= stackTrace;
      }
    }

    await attemptCleanup(action: _oAuthStorage.clearPkceVerifier);
    if (!_isCurrentGeneration(generation: generation) ||
        (requireOwnership && !_ownsOAuthSession(generation: generation, sessionToken: sessionToken))) {
      return false;
    }

    await attemptCleanup(action: _oAuthStorage.clearAuthProvider);
    if (!_isCurrentGeneration(generation: generation) ||
        (requireOwnership && !_ownsOAuthSession(generation: generation, sessionToken: sessionToken))) {
      return false;
    }

    await attemptCleanup(action: _oAuthStorage.clearOAuthSession);
    final Object? cleanupError = firstCleanupError;
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, firstCleanupStackTrace ?? StackTrace.current);
    }
    return true;
  }

  Future<void> _clearTokensAfterSupersededResult() async {
    try {
      await _tokenStorage.clearTokens();
    } on Object catch (error, stackTrace) {
      developer.log(
        "Failed to clear tokens after an authentication result was superseded",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
    }
  }

  void _ackOAuthCompletion({required String sessionToken}) {
    unawaited(_sendOAuthCompletionAck(sessionToken: sessionToken));
  }

  Future<void> _sendOAuthCompletionAck({required String sessionToken}) async {
    try {
      final uri = Uri.parse("$authBaseUrl/auth/session/status/ack");
      final response = await _post(
        uri,
        headers: {_sessionTokenHeader: sessionToken},
      ).timeout(_ackRequestTimeout);
      _ensureSuccess(response, context: "Failed to acknowledge OAuth session completion");
    } catch (error, stackTrace) {
      developer.log(
        "Failed to acknowledge OAuth session completion; server will expire it",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
    }
  }

  /// Persists [user] to local storage, swallowing (and logging) any failure.
  ///
  /// User caching only accelerates the offline restore path
  /// ([restoreLocalSession]); it is never authoritative. A write failure must
  /// not abort a flow whose tokens are already saved and whose in-memory
  /// session is valid, so callers stay authenticated even if this fails.
  Future<bool> _saveUserBestEffort({required AuthUser user, required int generation}) async {
    if (!_isCurrentGeneration(generation: generation)) {
      return false;
    }
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
    return _isCurrentGeneration(generation: generation);
  }

  AuthSessionStatusResponse _parseSessionStatus(http.Response response) {
    // Only trust the body on success (2xx) or the explicit 410 expired response.
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    final isExpired = response.statusCode == 410;

    if (!isSuccess && !isExpired) {
      _ensureSuccess(response, context: "OAuth session polling failed");
      throw StateError("OAuth session polling failed");
    }

    if (response.body.isNotEmpty) {
      try {
        return AuthSessionStatusResponse.fromJson(jsonDecodeMap(response.body));
      } on Object catch (e) {
        throw Exception("Failed to parse auth session status response: ${e.toString()}");
      }
    }

    throw StateError("OAuth session polling failed: empty response body");
  }

  @override
  Future<AuthLoginResult> resumeOAuthFlow() async {
    final session = await _oAuthStorage.getOAuthSession();
    if (session.sessionToken == null) {
      throw StateError("No OAuth flow is active");
    }
    return await pollForResult();
  }

  @override
  Future<bool> hasActiveOAuthSession() async {
    final int generation = _logoutGeneration;
    final session = await _oAuthStorage.getOAuthSession();
    if (!_isCurrentGeneration(generation: generation) || session.sessionToken == null || session.expiresAt == null) {
      return false;
    }
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt);
  }

  @override
  Future<AuthUser?> getCurrentUser() {
    final int generation = _logoutGeneration;
    return _getCurrentUser(generation: generation);
  }

  Future<AuthUser?> _getCurrentUser({required int generation}) async {
    try {
      final String? accessToken = await _getFreshAccessToken(
        generation: generation,
        minTtl: const Duration(seconds: 30),
        forceRefresh: false,
      );
      if (accessToken == null || !_isCurrentGeneration(generation: generation)) {
        return null;
      }

      final uri = Uri.parse("$authBaseUrl/auth/me");
      final response = await _get(
        uri,
        headers: _authHeader(accessToken),
      );
      if (!_isCurrentGeneration(generation: generation)) {
        return null;
      }
      _ensureSuccess(response, context: "Failed to fetch current user");

      final authMeResponse = AuthMeResponse.fromJson(jsonDecodeMap(response.body));
      return _isCurrentGeneration(generation: generation) ? authMeResponse.user : null;
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
    final int generation = _logoutGeneration;
    final AuthUser? user = await _getCurrentUser(generation: generation);
    if (user == null) {
      return false;
    }

    return await _mutationLock.run(
      action: () async {
        if (!_isCurrentGeneration(generation: generation)) {
          return false;
        }
        // Persist the user for sessions that were authenticated before it was
        // stored locally; /auth/me is the authoritative source for the value.
        // Best-effort: a local persistence failure must not block restoring a
        // session that /auth/me just confirmed.
        final bool userSaved = await _saveUserBestEffort(
          user: user,
          generation: generation,
        );
        if (!userSaved || !_isCurrentGeneration(generation: generation)) {
          return false;
        }
        _authState.add(AuthState.authenticated(user: user));
        return true;
      },
    );
  }

  @override
  Future<bool> restoreLocalSession() async {
    final int generation = _logoutGeneration;
    try {
      if (!await _tokenStorage.hasLocallyValidSession() || !_isCurrentGeneration(generation: generation)) {
        return false;
      }
      final AuthUser? user = await _tokenStorage.getUser();
      if (user == null || !_isCurrentGeneration(generation: generation)) {
        return false;
      }

      return await _mutationLock.run(
        action: () async {
          if (!_isCurrentGeneration(generation: generation)) {
            return false;
          }
          _authState.add(AuthState.authenticated(user: user));
          return true;
        },
      );
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
  Future<AuthLoginResult> loginWithEmail({required String email, required String password}) async {
    final int generation = _beginInteractiveLogin();
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
    final AuthLoginResponse authResponse;
    try {
      authResponse = AuthLoginResponse.fromJson(decodedBody);
    } on Object catch (e) {
      throw Exception("Failed to parse auth response: ${e.toString()}");
    }

    final bool persisted = await _persistAuthenticatedResult(
      generation: generation,
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      user: authResponse.user,
      clearOAuthState: true,
      requireOAuthOwnership: false,
      oauthSessionToken: null,
    );
    if (!persisted) {
      throw const _AuthFlowSuperseded();
    }
    return AuthLoginResult(user: authResponse.user, accountStatus: authResponse.accountStatus);
  }

  @override
  Future<AuthLoginResult> loginWithApple({required String idToken, required String nonce}) async {
    final int generation = _beginInteractiveLogin();
    final uri = Uri.parse("$authBaseUrl/auth/apple/native");
    final response = await _post(
      uri,
      body: {"idToken": idToken, "nonce": nonce},
    );

    _ensureSuccess(response, context: "Apple Sign-In failed");

    final decodedBody = jsonDecodeMap(response.body);
    final AuthLoginResponse authResponse;
    try {
      authResponse = AuthLoginResponse.fromJson(decodedBody);
    } on Object catch (e) {
      throw Exception("Failed to parse auth response: ${e.toString()}");
    }

    final bool persisted = await _persistAuthenticatedResult(
      generation: generation,
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      user: authResponse.user,
      clearOAuthState: true,
      requireOAuthOwnership: false,
      oauthSessionToken: null,
    );
    if (!persisted) {
      throw const _AuthFlowSuperseded();
    }
    return AuthLoginResult(user: authResponse.user, accountStatus: authResponse.accountStatus);
  }

  @override
  Future<void> invalidateAllSessions() async {
    final int requestGeneration = _logoutGeneration;
    final String? accessToken = await _getFreshAccessToken(
      generation: requestGeneration,
      minTtl: const Duration(seconds: 30),
      forceRefresh: false,
    );
    if (!_isCurrentGeneration(generation: requestGeneration)) {
      return;
    }
    if (accessToken != null) {
      final uri = Uri.parse("$authBaseUrl/auth/logout");
      final response = await _post(
        uri,
        headers: _authHeader(accessToken),
      );
      _throwIfGenerationSuperseded(generation: requestGeneration);
      _ensureSuccess(response, context: "Failed to invalidate all sessions");
    }

    final int generation = _beginLocalLogout();
    await _clearLocalAuthState(generation: generation);
  }

  @override
  Future<void> logoutCurrentDevice() async {
    final int generation = _beginLocalLogout();
    await _clearLocalAuthState(generation: generation);
  }

  Future<void> _clearLocalAuthState({required int generation}) {
    return _mutationLock.run(
      action: () async {
        await Future.wait([
          _tokenStorage.clearTokens(),
          _oAuthStorage.clearPkceVerifier(),
          _oAuthStorage.clearAuthProvider(),
          _oAuthStorage.clearOAuthSession(),
        ]);
        if (_isCurrentGeneration(generation: generation)) {
          _authState.add(const AuthState.unauthenticated());
        }
      },
    );
  }

  Future<String?>? _activeRefresh;
  int? _activeRefreshGeneration;

  Future<String?> _refreshAndPersistTokens({required int generation}) {
    if (!_isCurrentGeneration(generation: generation)) {
      return Future<String?>.value(null);
    }
    final Future<String?>? activeRefresh = _activeRefresh;
    if (activeRefresh != null && _activeRefreshGeneration == generation) {
      return activeRefresh;
    }
    // A refresh from an older auth generation may be stuck in an HTTP client
    // indefinitely. Detach it rather than making a new account wait for an
    // operation whose result is already fenced from persistence.

    late final Future<String?> refresh;
    refresh = _doRefreshAndPersist(generation: generation).whenComplete(() {
      if (identical(_activeRefresh, refresh)) {
        _activeRefresh = null;
        _activeRefreshGeneration = null;
      }
    });
    _activeRefresh = refresh;
    _activeRefreshGeneration = generation;
    return refresh;
  }

  Future<String?> _doRefreshAndPersist({required int generation}) async {
    try {
      if (!_isCurrentGeneration(generation: generation)) {
        return null;
      }
      final String? refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty || !_isCurrentGeneration(generation: generation)) {
        return null;
      }

      final uri = Uri.parse("$authBaseUrl/auth/refresh");
      final response = await _post(
        uri,
        body: {"refreshToken": refreshToken},
      );
      if (!_isCurrentGeneration(generation: generation)) {
        return null;
      }
      // The auth server uses 401 for an invalid or revoked refresh token.
      // Other 4xx responses (for example 408/429 from a gateway) are not
      // proof that the persisted credentials are invalid.
      if (response.statusCode == 401) {
        await _handleDefinitiveRefreshRejection(generation: generation);
        return null;
      }
      _ensureSuccess(response, context: "Token refresh failed");

      final decodedBody = jsonDecodeMap(response.body);
      final AuthResponse authResponse;
      try {
        authResponse = AuthResponse.fromJson(decodedBody);
      } on Object catch (e) {
        throw Exception("Failed to parse auth response: ${e.toString()}");
      }

      final bool persisted = await _persistRefreshedTokens(
        generation: generation,
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
      );
      return persisted && _isCurrentGeneration(generation: generation) ? authResponse.accessToken : null;
    } on _AuthFlowSuperseded {
      return null;
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

  Future<bool> _persistRefreshedTokens({
    required int generation,
    required String accessToken,
    required String refreshToken,
  }) {
    return _mutationLock.run(
      action: () async {
        if (!_isCurrentGeneration(generation: generation)) {
          return false;
        }
        await _tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        if (!_isCurrentGeneration(generation: generation)) {
          await _clearTokensAfterSupersededResult();
          return false;
        }
        return true;
      },
    );
  }

  Future<void> _handleDefinitiveRefreshRejection({required int generation}) async {
    if (!_isCurrentGeneration(generation: generation)) {
      return;
    }
    final int rejectionGeneration = _beginAuthGeneration();
    await _mutationLock.run(
      action: () async {
        await _tokenStorage.clearTokens();
        if (_isCurrentGeneration(generation: rejectionGeneration)) {
          _authState.add(const AuthState.unauthenticated());
        }
      },
    );
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

final class const _AuthFlowSuperseded() implements Exception {
  @override
  String toString() => "Authentication operation was superseded";
}

class _AuthMutationLock() {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>({required Future<T> Function() action}) async {
    final Future<void> previous = _tail;
    final Completer<void> release = Completer<void>();
    _tail = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }
}
