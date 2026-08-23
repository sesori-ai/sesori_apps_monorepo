import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "access_token_provider.dart";
import "auth_repository.dart";
import "token.dart";
import "token_refresh_exception.dart";
import "token_refresher.dart";

class TokenService({
  required String initialToken,
  required final Future<TokenData?> Function() _loadTokens,
  required final Future<void> Function(TokenData) _saveTokens,
  required final AuthRepository _authRepository,
}) implements AccessTokenProvider, TokenRefresher {
  final BehaviorSubject<String> _tokenSubject = BehaviorSubject.seeded(initialToken);

  @override
  String get accessToken => _tokenSubject.value;

  @override
  ValueStream<String> get tokenStream => _tokenSubject.stream;

  void dispose() {
    _tokenSubject.close();
  }

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      return await _refreshAndPersist();
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
      unawaited(
        _refreshAndPersist().catchError((Object error, StackTrace stackTrace) {
          Log.w("[token] background refresh failed", error, stackTrace);
          return currentToken;
        }),
      );
      return currentToken;
    }

    return await _refreshAndPersist();
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
      throw const TokenRefreshException("No tokens available for refresh");
    }

    final refreshToken = tokens.refreshToken;
    if (refreshToken.isEmpty) {
      throw const TokenRefreshException("Refresh token is empty");
    }

    final refresh = await _authRepository.refreshToken(refreshToken: refreshToken);
    final authResponse = switch (refresh) {
      AuthTokenRefreshed(:final response) => response,
      AuthTokenRefreshRejected(:final statusCode) => throw TokenRefreshException(
        "Token refresh failed with status $statusCode",
      ),
    };

    // Re-read the token file before persisting (and before publishing the new
    // access token in-memory) so a logout that deletes it mid-refresh is not
    // resurrected: a missing file — whether it throws or loads as null —
    // propagates a TokenRefreshException so the refresh neither recreates the
    // file nor leaves a usable token on the in-memory stream for a reconnect.
    // A corrupt file (FormatException) is the one recoverable case: fall back
    // to the pre-refresh snapshot and let the save below repair it. Only
    // `lastProvider` carries over; access/refresh come from the response.
    TokenData latestTokens;
    try {
      final reloaded = await _loadTokens();
      if (reloaded == null) {
        throw const TokenRefreshException("Token file cleared during refresh");
      }
      latestTokens = reloaded;
    } on FormatException {
      latestTokens = tokens;
    }
    final persistedTokens = TokenData(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      lastProvider: latestTokens.lastProvider,
    );
    await _saveTokens(persistedTokens);

    _tokenSubject.add(authResponse.accessToken);

    return authResponse.accessToken;
  }
}
