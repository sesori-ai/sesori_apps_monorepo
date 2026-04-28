import "dart:async";
import "dart:convert";
import "dart:developer" as developer;
import "dart:math";

import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";
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
  final http.Client _client;
  final TokenStorageService _tokenStorage;
  final OAuthStorageService _oAuthStorage;
  final BehaviorSubject<AuthState> _authState;

  AuthManager(
    http.Client client,
    TokenStorageService tokenStorage,
    OAuthStorageService oAuthStorage,
  ) : _client = client,
      _tokenStorage = tokenStorage,
      _oAuthStorage = oAuthStorage,
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
  Future<String> getAuthorizationUrl(AuthProvider provider, String redirectUri) async {
    if (provider == AuthProvider.email) {
      throw ArgumentError(
        'AuthProvider.email is not supported by getAuthorizationUrl. '
        'Use loginWithEmail for email-based authentication.',
      );
    }

    final (codeVerifier, codeChallenge) = await _generatePkce();

    await _oAuthStorage.saveAuthProviderAndPkceVerifier(
      codeVerifier: codeVerifier,
      provider: provider,
    );

    final uri = Uri.parse("$authBaseUrl/auth/${provider.key}").replace(
      queryParameters: {
        "redirect_uri": redirectUri,
        "code_challenge": codeChallenge,
        "code_challenge_method": "S256",
      },
    );

    final response = await _get(uri);
    _ensureSuccess(response, context: "Failed to get ${provider.label} auth URL");

    final decodedBody = jsonDecodeMap(response.body);
    final authUrlResponse = AuthUrlResponse.fromJson(decodedBody);
    return authUrlResponse.authUrl;
  }

  @override
  Future<AuthUser> exchangeCode({
    required String code,
    required String state,
    required String redirectUri,
  }) async {
    final codeVerifier = await _oAuthStorage.getPkceVerifier();
    if (codeVerifier == null || codeVerifier.isEmpty) {
      throw StateError("Missing PKCE verifier for OAuth code exchange");
    }

    final provider = await _oAuthStorage.getAuthProvider();
    if (provider == null) {
      throw StateError("Missing OAuth provider for code exchange");
    }

    final uri = Uri.parse("$authBaseUrl/auth/${provider.key}/callback");
    final response = await _post(
      uri,
      body: {
        "code": code,
        "codeVerifier": codeVerifier,
        "state": state,
        "redirectUri": redirectUri,
      },
    );
    _ensureSuccess(response, context: "${provider.label} code exchange failed");

    final decodedBody = jsonDecodeMap(response.body);
    late AuthResponse authResponse;
    try {
      authResponse = AuthResponse.fromJson(decodedBody);
    } on Object catch (e) {
      throw Exception("Failed to parse auth response: $e");
    }

    await _tokenStorage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );

    await Future.wait([
      _oAuthStorage.clearPkceVerifier(),
      _oAuthStorage.clearAuthProvider(),
    ]);

    _authState.add(AuthState.authenticated(user: authResponse.user));
    return authResponse.user;
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
  Future<bool> restoreSession() async {
    final user = await getCurrentUser();
    if (user == null) return false;

    _authState.add(AuthState.authenticated(user: user));
    return true;
  }

  @override
  Future<AuthUser> loginWithEmail(String email, String password) async {
    final uri = Uri.parse("$authBaseUrl/auth/password/login");
    final response = await _post(
      uri,
      body: {"email": email, "password": password},
    );

    if (response.statusCode == 401) {
      throw Exception("Invalid email or password");
    }
    _ensureSuccess(response, context: "Email/password login failed");

    final decodedBody = jsonDecodeMap(response.body);
    late AuthResponse authResponse;
    try {
      authResponse = AuthResponse.fromJson(decodedBody);
    } on Object catch (e) {
      throw Exception("Failed to parse auth response: $e");
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
    late AuthResponse authResponse;
    try {
      authResponse = AuthResponse.fromJson(decodedBody);
    } on Object catch (e) {
      throw Exception("Failed to parse auth response: $e");
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

  Future<(String codeVerifier, String codeChallenge)> _generatePkce() async {
    final random = Random.secure();
    final verifierBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final codeVerifier = base64Url.encode(verifierBytes).replaceAll("=", "");

    final hashAlgo = Sha256();
    final hash = await hashAlgo.hash(utf8.encode(codeVerifier));
    final codeChallenge = base64Url.encode(hash.bytes).replaceAll("=", "");

    return (codeVerifier, codeChallenge);
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
