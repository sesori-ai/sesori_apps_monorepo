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
import "platform/oauth_device_descriptor_provider.dart";
import "storage/oauth_storage_service.dart";
import "storage/token_storage_service.dart";

typedef _OAuthSessionOwner = ({DateTime expiresAt, int generation, String sessionToken});

@lazySingleton
class AuthManager implements AuthTokenProvider, OAuthFlowProvider, AuthSession {
  static const _sessionTokenHeader = "X-Sesori-Session-Token";
  static const _defaultPollInterval = Duration(milliseconds: 250);
  static const _defaultPollTimeout = Duration(minutes: 5);
  static const _defaultRequestTimeout = Duration(seconds: 35);
  static const _ackRequestTimeout = Duration(seconds: 5);

  final http.Client _client;
  final TokenStorageService _tokenStorage;
  final OAuthStorageService _oAuthStorage;
  final OAuthDeviceDescriptorProvider _deviceDescriptorProvider;
  final BehaviorSubject<AuthState> _authState;
  final Duration _pollInterval;
  final Duration _pollTimeout;
  final Future<void> Function(Duration duration) _delay;
  Future<void> _oAuthMutationTail = Future<void>.value();
  _OAuthMutationHealth _oAuthMutationHealth = _OAuthMutationHealth.healthy;
  Future<void>? _oAuthPoisonCleanup;
  int _nextOAuthGeneration = 0;
  _OAuthSessionOwner? _oAuthSessionOwner;

  AuthManager(
    http.Client client,
    TokenStorageService tokenStorage,
    OAuthStorageService oAuthStorage,
    OAuthDeviceDescriptorProvider deviceDescriptorProvider, {
    @visibleForTesting Duration pollInterval = _defaultPollInterval,
    @visibleForTesting Duration pollTimeout = _defaultPollTimeout,
    @visibleForTesting Future<void> Function(Duration duration)? delay,
  }) : _client = client,
       _tokenStorage = tokenStorage,
       _oAuthStorage = oAuthStorage,
       _deviceDescriptorProvider = deviceDescriptorProvider,
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
    OAuthDeviceDescriptorProvider deviceDescriptorProvider,
  ) => AuthManager(client, tokenStorage, oAuthStorage, deviceDescriptorProvider);

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
  Future<AuthInitResponse> startOAuthFlow({required OAuthProvider provider, required DateTime? deadline}) async {
    final sessionToken = _generateSessionToken();
    final flowDeadline = deadline ?? DateTime.now().add(_pollTimeout);
    var owner = (
      expiresAt: flowDeadline,
      generation: ++_nextOAuthGeneration,
      sessionToken: sessionToken,
    );

    try {
      final activation = _mutateOAuthState(
        mutation: () async {
          if (!DateTime.now().isBefore(flowDeadline)) {
            throw TimeoutException("OAuth authorization timed out");
          }
          _oAuthSessionOwner = owner;
        },
      );
      await _awaitOAuthMutationBeforeDeadline(
        deadline: flowDeadline,
        mutation: activation,
      );
      final descriptor = await _beforeOAuthDeadline(
        deadline: flowDeadline,
        operation: _deviceDescriptorProvider.describe,
      );
      final uri = Uri.parse("$authBaseUrl/auth/${provider.key}/init");
      final response = await _postOAuthInit(
        uri: uri,
        deadline: flowDeadline,
        body: AuthInitRequest(clientType: descriptor.clientType, device: descriptor.device),
        headers: {_sessionTokenHeader: sessionToken},
      );
      if (response.statusCode == 503) {
        throw OAuthSessionRestartRequiredException(
          restartAfter: _parseRestartAfter(header: response.headers["retry-after"]),
          deadline: flowDeadline,
          operation: OAuthSessionRestartOperation.init,
          reason: OAuthSessionRestartReason.serviceUnavailable,
        );
      }
      _ensureSuccess(response, context: "Failed to start ${provider.label} auth flow");

      final initResponse = AuthInitResponse.fromJson(jsonDecodeMap(response.body));
      final serverExpiresAt = DateTime.now().add(Duration(seconds: initResponse.expiresIn));
      final expiresAt = flowDeadline.isBefore(serverExpiresAt) ? flowDeadline : serverExpiresAt;
      final activatedOwner = owner;
      owner = (
        expiresAt: expiresAt,
        generation: owner.generation,
        sessionToken: owner.sessionToken,
      );
      final sessionSave = _mutateOAuthState(
        mutation: () async {
          _throwIfOAuthSessionSuperseded(owner: activatedOwner);
          _oAuthSessionOwner = owner;
          await _oAuthStorage.saveOAuthSession(
            sessionToken: sessionToken,
            expiresAt: expiresAt,
          );
        },
      );
      await _awaitOAuthMutationBeforeDeadline(
        deadline: flowDeadline,
        mutation: sessionSave,
      );
      await _assertOAuthSessionOwner(owner: owner);
      return initResponse;
    } on Object catch (error, stackTrace) {
      if (_oAuthMutationHealth == _OAuthMutationHealth.healthy && error is! _OAuthMutationPoisonedException) {
        final cleanup = _clearOAuthSessionIfOwned(owner: owner);
        try {
          await _awaitOAuthMutationBeforeDeadline(
            deadline: flowDeadline,
            mutation: cleanup,
          );
        } on TimeoutException {
          // Poison recovery owns the late cleanup. Preserve the original
          // operation failure rather than replacing it with rollback timing.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<AuthUser> pollForResult() async {
    final owner = await _mutateOAuthState(
      mutation: () async {
        final activeOwner = _oAuthSessionOwner;
        if (activeOwner != null) {
          return activeOwner;
        }

        final storedSession = await _oAuthStorage.getOAuthSession();
        final storedToken = storedSession.sessionToken;
        if (storedToken == null || storedToken.isEmpty) {
          throw StateError("No OAuth flow is active");
        }

        final restoredOwner = (
          expiresAt: storedSession.expiresAt ?? DateTime.now().add(_pollTimeout),
          generation: ++_nextOAuthGeneration,
          sessionToken: storedToken,
        );
        _oAuthSessionOwner = restoredOwner;
        return restoredOwner;
      },
    );
    final sessionToken = owner.sessionToken;
    final expiresAt = owner.expiresAt;

    if (!DateTime.now().isBefore(expiresAt)) {
      await _clearOAuthSessionIfOwned(owner: owner);
      throw TimeoutException("OAuth authorization expired");
    }

    var completionCommitted = false;
    try {
      while (DateTime.now().isBefore(expiresAt)) {
        final remaining = expiresAt.difference(DateTime.now());
        final requestTimeout = remaining < _defaultRequestTimeout ? remaining : _defaultRequestTimeout;
        if (requestTimeout <= Duration.zero) break;
        final isFinalRequest = remaining <= _defaultRequestTimeout;

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
          await _clearOAuthSessionIfOwned(owner: owner);
          rethrow;
        }

        await _assertOAuthSessionOwner(owner: owner);
        if (response.statusCode == 503 || response.statusCode == 404) {
          final restartAfter = response.statusCode == 404
              ? Duration.zero
              : _parseRestartAfter(header: response.headers["retry-after"]);
          await _clearOAuthSessionBeforeDeadline(
            deadline: expiresAt,
            owner: owner,
          );
          throw OAuthSessionRestartRequiredException(
            restartAfter: restartAfter,
            deadline: expiresAt,
            operation: OAuthSessionRestartOperation.status,
            reason: response.statusCode == 404
                ? OAuthSessionRestartReason.sessionMissing
                : OAuthSessionRestartReason.serviceUnavailable,
          );
        }
        final status = _parseSessionStatus(response);
        switch (status) {
          case AuthSessionStatusResponsePending():
            final delayRemaining = expiresAt.difference(DateTime.now());
            final delay = _pollInterval < delayRemaining ? _pollInterval : delayRemaining;
            if (delay > Duration.zero) {
              await _delay(delay);
            }
          case AuthSessionStatusResponseComplete(
            accessToken: final accessToken,
            refreshToken: final refreshToken,
            user: final user,
          ):
            await _persistOAuthCompletion(
              owner: owner,
              deadline: expiresAt,
              accessToken: accessToken,
              refreshToken: refreshToken,
              user: user,
            );
            completionCommitted = true;
            _ackOAuthCompletion(sessionToken: sessionToken);
            return user;
          case AuthSessionStatusResponseDenied():
            await _clearOAuthSessionIfOwned(owner: owner);
            throw StateError("OAuth authorization was denied");
          case AuthSessionStatusResponseExpired():
            await _clearOAuthSessionIfOwned(owner: owner);
            throw StateError("OAuth authorization expired");
          case AuthSessionStatusResponseError(:final message):
            await _clearOAuthSessionIfOwned(owner: owner);
            throw StateError("OAuth authorization failed: $message");
        }
      }

      await _clearOAuthSessionIfOwned(owner: owner);
      throw TimeoutException("OAuth authorization timed out");
    } finally {
      if (!completionCommitted) {
        try {
          await _releaseOAuthSessionIfOwned(owner: owner);
        } on _OAuthMutationPoisonedException {
          // Poison recovery owns final cleanup; preserve the established result.
        }
      }
    }
  }

  Duration _parseRestartAfter({required String? header}) {
    final seconds = header != null && RegExp(r"^[0-9]+$").hasMatch(header) ? int.tryParse(header) : null;
    return seconds != null && seconds <= 5 ? Duration(seconds: seconds) : const Duration(seconds: 1);
  }

  Future<http.Response> _postOAuthInit({
    required Uri uri,
    required DateTime deadline,
    required AuthInitRequest body,
    required Map<String, String> headers,
  }) async {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException("OAuth authorization timed out");
    }

    final abortTrigger = Completer<void>();
    final requestTimer = Timer(remaining, abortTrigger.complete);
    try {
      final request = http.AbortableRequest("POST", uri, abortTrigger: abortTrigger.future)
        ..headers.addAll({
          "Accept": "application/json",
          "Content-Type": "application/json",
          ...headers,
        })
        ..body = jsonEncode(body.toJson());
      return await http.Response.fromStream(await _client.send(request));
    } on http.RequestAbortedException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        OAuthRequestTimeoutException(
          message: "OAuth authorization timed out",
          uri: uri,
          cause: error,
        ),
        stackTrace,
      );
    } finally {
      requestTimer.cancel();
    }
  }

  Future<http.Response> _getSessionStatus({
    required Uri uri,
    required String sessionToken,
    required Duration requestTimeout,
    required DateTime? expiresAt,
    required bool isFinalRequest,
  }) async {
    final abortTrigger = Completer<void>();
    final requestTimer = Timer(requestTimeout, abortTrigger.complete);
    try {
      final request = http.AbortableRequest("GET", uri, abortTrigger: abortTrigger.future)
        ..headers.addAll({
          "Accept": "application/json",
          _sessionTokenHeader: sessionToken,
        });
      return await http.Response.fromStream(await _client.send(request));
    } on http.RequestAbortedException catch (error, stackTrace) {
      _throwSessionStatusTimeout(
        cause: error,
        expiresAt: expiresAt,
        isFinalRequest: isFinalRequest,
        stackTrace: stackTrace,
        uri: uri,
      );
    } on TimeoutException catch (error, stackTrace) {
      _throwSessionStatusTimeout(
        cause: error,
        expiresAt: expiresAt,
        isFinalRequest: isFinalRequest,
        stackTrace: stackTrace,
        uri: uri,
      );
    } finally {
      requestTimer.cancel();
    }
  }

  Never _throwSessionStatusTimeout({
    required Exception cause,
    required DateTime? expiresAt,
    required bool isFinalRequest,
    required StackTrace stackTrace,
    required Uri uri,
  }) {
    if (isFinalRequest || (expiresAt != null && !DateTime.now().isBefore(expiresAt))) {
      Error.throwWithStackTrace(
        OAuthRequestTimeoutException(
          message: "OAuth authorization timed out",
          uri: uri,
          cause: cause,
        ),
        stackTrace,
      );
    }
    Error.throwWithStackTrace(
      OAuthSessionStatusClientException(uri: uri, cause: cause),
      stackTrace,
    );
  }

  Future<void> _persistOAuthCompletion({
    required _OAuthSessionOwner owner,
    required DateTime deadline,
    required String accessToken,
    required String refreshToken,
    required AuthUser user,
  }) => _mutateOAuthState(
    mutation: () async {
      _throwIfOAuthSessionSuperseded(owner: owner);
      if (!DateTime.now().isBefore(deadline)) {
        _oAuthSessionOwner = null;
        await _oAuthStorage.clearOAuthSession();
        throw TimeoutException("OAuth authorization timed out");
      }
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
      _throwIfOAuthSessionSuperseded(owner: owner);
      _oAuthSessionOwner = null;
      _authState.add(AuthState.authenticated(user: user));
    },
  );

  Future<T> _beforeOAuthDeadline<T>({
    required DateTime deadline,
    required Future<T> Function() operation,
  }) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return Future<T>.error(TimeoutException("OAuth authorization timed out"));
    }

    return operation().timeout(
      remaining,
      onTimeout: () => throw TimeoutException("OAuth authorization timed out"),
    );
  }

  Future<T> _awaitOAuthMutationBeforeDeadline<T>({
    required DateTime deadline,
    required Future<T> mutation,
  }) async {
    try {
      return await _beforeOAuthDeadline(deadline: deadline, operation: () => mutation);
    } on TimeoutException {
      _poisonOAuthMutation(timedOutMutation: mutation);
      rethrow;
    }
  }

  Future<T> _mutateOAuthState<T>({required Future<T> Function() mutation}) {
    if (_oAuthMutationHealth != _OAuthMutationHealth.healthy) {
      if (_oAuthMutationHealth == _OAuthMutationHealth.cleanupRequired) {
        return (() async {
          await _retryPoisonedOAuthCleanup();
          return _mutateOAuthState(mutation: mutation);
        })();
      }
      return Future<T>.error(const _OAuthMutationPoisonedException());
    }

    final previous = _oAuthMutationTail;
    final completion = Completer<void>();
    _oAuthMutationTail = completion.future;
    return (() async {
      await previous;
      try {
        return await mutation();
      } finally {
        completion.complete();
      }
    })();
  }

  Future<void> _clearOAuthSessionBeforeDeadline({
    required DateTime deadline,
    required _OAuthSessionOwner owner,
  }) {
    final cleanup = _clearOAuthSessionIfOwned(owner: owner);
    return _awaitOAuthMutationBeforeDeadline(
      deadline: deadline,
      mutation: cleanup,
    );
  }

  Future<void> _clearOAuthSessionIfOwned({required _OAuthSessionOwner owner}) => _mutateOAuthState(
    mutation: () async {
      if (!_ownsOAuthSession(owner: owner)) {
        return;
      }

      _oAuthSessionOwner = null;
      await _oAuthStorage.clearOAuthSession();
    },
  );

  Future<void> _releaseOAuthSessionIfOwned({required _OAuthSessionOwner owner}) => _mutateOAuthState(
    mutation: () async {
      if (_ownsOAuthSession(owner: owner)) {
        _oAuthSessionOwner = null;
      }
    },
  );

  Future<void> _assertOAuthSessionOwner({required _OAuthSessionOwner owner}) => _mutateOAuthState(
    mutation: () async {
      _throwIfOAuthSessionSuperseded(owner: owner);
    },
  );

  bool _ownsOAuthSession({required _OAuthSessionOwner owner}) => _oAuthSessionOwner == owner;

  void _throwIfOAuthSessionSuperseded({required _OAuthSessionOwner owner}) {
    if (!_ownsOAuthSession(owner: owner)) {
      throw const _OAuthSessionSupersededException();
    }
  }

  void _poisonOAuthMutation<T>({required Future<T> timedOutMutation}) {
    if (_oAuthMutationHealth != _OAuthMutationHealth.healthy) {
      return;
    }

    _oAuthMutationHealth = _OAuthMutationHealth.drainingTimedOutMutation;
    unawaited(_recoverPoisonedOAuthMutation(timedOutMutation: timedOutMutation));
  }

  Future<void> _recoverPoisonedOAuthMutation<T>({required Future<T> timedOutMutation}) async {
    try {
      await timedOutMutation;
    } catch (error, stackTrace) {
      developer.log(
        "Timed-out OAuth mutation eventually failed",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
    }

    try {
      await _oAuthMutationTail;
      _oAuthMutationHealth = _OAuthMutationHealth.cleanupRequired;
      await _retryPoisonedOAuthCleanup();
    } catch (error, stackTrace) {
      developer.log(
        "Failed to recover poisoned OAuth mutation state",
        error: error,
        stackTrace: stackTrace,
        name: "sesori_auth",
      );
    }
  }

  Future<void> _retryPoisonedOAuthCleanup() {
    return _oAuthPoisonCleanup ??= _runPoisonedOAuthCleanup();
  }

  Future<void> _runPoisonedOAuthCleanup() async {
    try {
      _oAuthSessionOwner = null;
      await _oAuthStorage.clearOAuthSession();
      _oAuthMutationHealth = _OAuthMutationHealth.healthy;
    } finally {
      _oAuthPoisonCleanup = null;
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
  Future<AuthUser> resumeOAuthFlow() async {
    final session = await _oAuthStorage.getOAuthSession();
    if (session.sessionToken == null) {
      throw StateError("No OAuth flow is active");
    }
    return pollForResult();
  }

  @override
  Future<bool> hasActiveOAuthSession() async {
    final session = await _oAuthStorage.getOAuthSession();
    if (session.sessionToken == null || session.expiresAt == null) {
      return false;
    }
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt);
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
      throw StateError("$context (HTTP ${response.statusCode})");
    }
  }
}

enum _OAuthMutationHealth {
  healthy,
  drainingTimedOutMutation,
  cleanupRequired,
}

final class _OAuthSessionSupersededException implements Exception {
  const _OAuthSessionSupersededException();
}

final class _OAuthMutationPoisonedException implements Exception {
  const _OAuthMutationPoisonedException();
}

final class OAuthRequestTimeoutException extends TimeoutException {
  OAuthRequestTimeoutException({
    required String message,
    required this.uri,
    required this.cause,
  }) : super(message);

  final Uri uri;
  final Exception cause;
}

final class OAuthSessionStatusClientException extends http.ClientException {
  OAuthSessionStatusClientException({
    required Uri uri,
    required this.cause,
  }) : super("OAuth session status request timed out", uri);

  final Exception cause;
}
