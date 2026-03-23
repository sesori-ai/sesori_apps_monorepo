import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "access_token_provider.dart";
import "token.dart";
import "token_refresher.dart";

class TokenManager implements AccessTokenProvider, AccessTokenUpdater, TokenRefresher {
  final BehaviorSubject<String> _tokenSubject;
  final String _authBackendUrl;
  final Future<TokenData?> Function() _loadTokens;
  final Future<void> Function(TokenData) _saveTokens;
  final http.Client _client;

  TokenManager({
    required String initialToken,
    required String authBackendUrl,
    required Future<TokenData?> Function() loadTokens,
    required Future<void> Function(TokenData) saveTokens,
    http.Client? client,
  }) : _tokenSubject = BehaviorSubject.seeded(initialToken),
       _authBackendUrl = authBackendUrl,
       _loadTokens = loadTokens,
       _saveTokens = saveTokens,
       _client = client ?? http.Client();

  @override
  String get accessToken => _tokenSubject.value;

  @override
  ValueStream<String> get tokenStream => _tokenSubject.stream;

  @override
  set accessToken(String token) => _tokenSubject.add(token);

  void dispose() => _tokenSubject.close();

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      return _refreshAndPersist();
    }

    final currentToken = _tokenSubject.value;
    final expiry = parseJwtExpiry(currentToken);

    if (expiry == null) {
      return currentToken;
    }

    final ttl = expiry.difference(DateTime.now().toUtc());

    if (ttl > const Duration(seconds: 90)) {
      return currentToken;
    }

    if (ttl > const Duration(seconds: 30)) {
      unawaited(_refreshAndPersist());
      return currentToken;
    }

    return _refreshAndPersist();
  }

  Future<String>? _activeRefresh;

  Future<String> _refreshAndPersist() {
    return _activeRefresh ??= _doRefresh().whenComplete(() {
      _activeRefresh = null;
    });
  }

  Future<String> _doRefresh() async {
    final tokens = await _loadTokens();
    if (tokens == null) {
      throw Exception("No tokens available for refresh");
    }

    final refreshToken = tokens.refreshToken;
    if (refreshToken.isEmpty) {
      throw Exception("Refresh token is empty");
    }

    final base = _authBackendUrl.endsWith("/")
        ? _authBackendUrl.substring(0, _authBackendUrl.length - 1)
        : _authBackendUrl;
    final uri = Uri.parse("$base/auth/refresh");

    final response = await _client.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refreshToken": refreshToken}),
    );

    if (response.statusCode != 200) {
      throw Exception("Token refresh failed with status ${response.statusCode}");
    }

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    final authResponse = AuthResponse.fromJson(jsonBody);

    _tokenSubject.add(authResponse.accessToken);

    final persistedTokens = TokenData(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      bridgeToken: tokens.bridgeToken,
    );
    await _saveTokens(persistedTokens);

    return authResponse.accessToken;
  }
}
