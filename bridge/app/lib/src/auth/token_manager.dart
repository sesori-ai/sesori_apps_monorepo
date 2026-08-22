import "dart:async";
import "dart:convert";

import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "access_token_provider.dart";
import "token.dart";
import "token_refresh_exception.dart";
import "token_refresher.dart";

/// Takes ownership of the injected HTTP client and closes it in [dispose].
class TokenManager({
  required String initialToken,
  required final String _authBackendUrl,
  required final Future<TokenData?> Function() _loadTokens,
  required final Future<void> Function(TokenData) _saveTokens,
  required final http.Client _ownedClient,
  required final Duration _requestDeadline,
}) implements AccessTokenProvider, TokenRefresher {
  static const Duration defaultRequestDeadline = Duration(seconds: 35);

  final BehaviorSubject<String> _tokenSubject = BehaviorSubject.seeded(initialToken);

  @override
  String get accessToken => _tokenSubject.value;

  @override
  ValueStream<String> get tokenStream => _tokenSubject.stream;

  void dispose() {
    _tokenSubject.close();
    _ownedClient.close();
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

    final base = _authBackendUrl.endsWith("/")
        ? _authBackendUrl.substring(0, _authBackendUrl.length - 1)
        : _authBackendUrl;
    final uri = Uri.parse("$base/auth/refresh");

    final abortCompleter = Completer<void>();
    final deadlineTimer = Timer(_requestDeadline, abortCompleter.complete);
    final request = http.AbortableRequest("POST", uri, abortTrigger: abortCompleter.future)
      ..headers["Content-Type"] = "application/json"
      ..body = jsonEncode({"refreshToken": refreshToken});
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _ownedClient.send(request));
    } finally {
      deadlineTimer.cancel();
    }

    if (response.statusCode != 200) {
      throw TokenRefreshException("Token refresh failed with status ${response.statusCode}");
    }

    final authResponse = AuthResponse.fromJson(jsonDecodeMap(response.body));

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
