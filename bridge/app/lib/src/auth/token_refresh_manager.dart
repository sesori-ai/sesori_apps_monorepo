import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

import "access_token_provider.dart";
import "jwt_expiry.dart";
import "token.dart";
import "token_refresher.dart";

class TokenRefreshManager implements TokenRefresher {
  final AccessTokenProvider _tokenProvider;
  final AccessTokenUpdater _tokenUpdater;
  final String _authBackendUrl;
  final Future<TokenData?> Function() _loadTokens;
  final Future<void> Function(TokenData) _saveTokens;
  final http.Client _client;

  TokenRefreshManager({
    required AccessTokenProvider tokenProvider,
    required AccessTokenUpdater tokenUpdater,
    required String authBackendUrl,
    required Future<TokenData?> Function() loadTokens,
    required Future<void> Function(TokenData) saveTokens,
    http.Client? client,
  }) : _tokenProvider = tokenProvider,
       _tokenUpdater = tokenUpdater,
       _authBackendUrl = authBackendUrl,
       _loadTokens = loadTokens,
       _saveTokens = saveTokens,
       _client = client ?? http.Client();

  @override
  Future<String> getFreshAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      return _refreshAndPersist();
    }

    final currentToken = _tokenProvider.accessToken;
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

    _tokenUpdater.accessToken = authResponse.accessToken;

    final persistedTokens = TokenData(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      bridgeToken: tokens.bridgeToken,
    );
    await _saveTokens(persistedTokens);

    return authResponse.accessToken;
  }
}
