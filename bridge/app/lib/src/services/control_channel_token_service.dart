import "dart:async";
import "dart:convert";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart"
    show ControlMessage, ControlTokenResponse, ControlTokenUpdate, jsonDecodeMap;

import "../auth/access_token_provider.dart";
import "../auth/token_refresher.dart";
import "../foundation/control_channel_client.dart";

/// Thrown when the GUI cannot supply an access token over the control channel —
/// either it replied with a null token (signed out / mid-login) or it did not
/// reply within the request timeout. The caller surfaces and logs this once, so
/// this path deliberately does not log it (avoids double-logging).
class ControlTokenUnavailableException implements Exception {
  final String reason;
  const ControlTokenUnavailableException(this.reason);
  @override
  String toString() => "ControlTokenUnavailableException: $reason";
}

/// Supervised-mode access-token authority over the loopback control channel: the
/// GUI, not an interactive terminal or the auth server's refresh endpoint, is
/// the bridge's token source. This service is the supervised-mode counterpart of
/// the standalone [TokenManager] — both implement [AccessTokenProvider] and
/// [TokenRefresher], and the composition root picks one by mode.
///
/// [getAccessToken] asks the GUI for a token by sending a
/// [ControlMessage.tokenRequest] and awaiting the id-correlated
/// [ControlMessage.tokenResponse], forwarding `forceRefresh` so the GUI knows
/// whether to mint a fresh token. The latest token is cached so the synchronous
/// [accessToken] getter and [tokenStream] reflect it.
///
/// The GUI is the authoritative token source: a pushed [ControlMessage.tokenUpdate]
/// is adopted directly into the cache (driving [accessToken]/[tokenStream]), so the
/// steady-state cache writer is the push, not pull ordering — there is no
/// pull-sequence freshness heuristic. A pull still seeds the cache before any push
/// exists (bootstrap), and the last write wins.
///
/// A null [ControlTokenResponse] (signed out / mid-login) invalidates the cache: the
/// synchronous [accessToken] getter throws again until a fresh token (pull or push)
/// arrives, so a reconnect can never re-authenticate the relay as a signed-out user
/// from a stale cached token. (`tokenUpdate.accessToken` is non-null, so a push can
/// never signal sign-out — only a null `tokenResponse` can.)
///
/// It owns its subscription to [ControlChannelClient.inbound], decoding each
/// frame into a [ControlMessage] and completing the matching pending request.
/// Non-token frames are ignored here (other control messages are handled
/// elsewhere); undecodable frames are logged and skipped so a malformed or
/// forward-compat message can't stall a pull.
class ControlChannelTokenService implements AccessTokenProvider, TokenRefresher {
  static const Duration _defaultRequestTimeout = Duration(seconds: 30);

  final ControlChannelClient _client;
  final Duration _requestTimeout;
  final BehaviorSubject<String> _tokenSubject = BehaviorSubject<String>();
  final Map<String, Completer<String?>> _pending = <String, Completer<String?>>{};
  late final StreamSubscription<String> _subscription;
  int _nextRequestId = 0;
  // A null token_response (signed out / mid-login) sets this so the synchronous
  // accessToken getter throws even though the BehaviorSubject still holds the
  // last (now stale) value — a BehaviorSubject cannot un-emit. Cleared the next
  // time a real token is cached (pull or push).
  bool _invalidated = false;
  bool _disposed = false;
  Future<void>? _disposeFuture;

  ControlChannelTokenService({
    required ControlChannelClient client,
    Duration requestTimeout = _defaultRequestTimeout,
  })  : _client = client,
        _requestTimeout = requestTimeout {
    _subscription = _client.inbound.listen(_handleFrame);
  }

  /// The most recently cached access token. Only valid after the first token is
  /// cached (the bootstrap [getAccessToken] the composition root awaits before
  /// exposing this provider, or a pushed [ControlMessage.tokenUpdate]), and only
  /// while it has not been invalidated by a signed-out [ControlTokenResponse].
  /// Throws [StateError] in either unavailable case so a caller can never read a
  /// missing or stale-after-sign-out token.
  @override
  String get accessToken {
    if (_invalidated) {
      throw StateError(
        "accessToken is unavailable — the desktop app reported no token "
        "(signed out or mid-login); await a fresh getAccessToken() first.",
      );
    }
    if (!_tokenSubject.hasValue) {
      throw StateError(
        "accessToken read before the initial control-channel token pull — "
        "await getAccessToken() before using this provider.",
      );
    }
    return _tokenSubject.value;
  }

  @override
  ValueStream<String> get tokenStream => _tokenSubject.stream;

  /// Requests an access token from the GUI over the control channel and waits
  /// for the correlated reply, forwarding [forceRefresh] so the GUI can mint a
  /// fresh token instead of returning a cached one. Throws
  /// [ControlTokenUnavailableException] when the GUI replies with no token
  /// (signed out / mid-login) or does not reply within the request timeout.
  /// Does not log on failure — the caller surfaces it once.
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    // After dispose the inbound subscription is cancelled, so a response can
    // never arrive — fail fast instead of registering a completer that would
    // only resolve via the timeout.
    if (_disposed) {
      throw const ControlTokenUnavailableException(
        "Control channel token service has been disposed.",
      );
    }
    final id = "token-${_nextRequestId++}";
    final completer = Completer<String?>();
    _pending[id] = completer;
    try {
      try {
        _client.send(jsonEncode(ControlMessage.tokenRequest(id: id, forceRefresh: forceRefresh).toJson()));
      } on ControlChannelNotConnectedException {
        // The loopback channel is down (GUI outage / mid-reconnect). Surface the
        // documented typed failure so refresh callers (e.g. relay re-auth) handle
        // a GUI-unavailable pull uniformly instead of a raw transport error.
        throw const ControlTokenUnavailableException(
          "The desktop app control channel is not connected.",
        );
      }
      final accessToken = await completer.future.timeout(_requestTimeout);
      if (accessToken == null) {
        // Signed out / mid-login: invalidate any previously cached token so a
        // reconnect can't re-authenticate the relay from a stale token. The
        // GUI push (token_update) is non-null and so can never signal this.
        _invalidateCache();
        throw const ControlTokenUnavailableException(
          "The desktop app could not supply an access token (signed out or mid-login).",
        );
      }
      // Seed the cache so the synchronous getter and tokenStream stay current.
      // No pull-sequence gate: the GUI's token_update push is the authoritative
      // steady-state writer, so the last write simply wins. A pull only seeds
      // the cache before any push exists (bootstrap).
      _cacheToken(accessToken);
      return accessToken;
    } on TimeoutException {
      throw const ControlTokenUnavailableException(
        "Timed out waiting for the desktop app to supply an access token.",
      );
    } finally {
      _pending.remove(id);
    }
  }

  /// Memoized so concurrent callers await the same teardown — a second caller
  /// must not observe completion before the first dispose's cancel/sweep has
  /// finished.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    // Set synchronously (before the first await) so a getAccessToken racing
    // dispose sees the disposed guard immediately.
    _disposed = true;
    // Isolate the cancel so a failure still lets teardown finish.
    try {
      await _subscription.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[control][token] failed to cancel inbound subscription", error, stackTrace);
    }
    // Fail any in-flight request so a shutdown mid-request doesn't hang on the
    // full request timeout.
    final pending = List<Completer<String?>>.of(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(
          const ControlTokenUnavailableException("Control channel token service disposed before a token arrived."),
        );
      }
    }
    await _tokenSubject.close();
  }

  void _handleFrame(String frame) {
    if (_disposed) return;
    final ControlMessage message;
    try {
      message = ControlMessage.fromJson(jsonDecodeMap(frame));
    } on Object catch (error, stackTrace) {
      // A frame we can't decode (malformed, or a forward-compat message type a
      // newer GUI added) is not fatal — skip it and keep serving requests.
      Log.w("[control][token] ignoring undecodable control frame", error, stackTrace);
      return;
    }
    switch (message) {
      case ControlTokenResponse():
        final completer = _pending.remove(message.id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message.accessToken);
        }
      case ControlTokenUpdate():
        // The GUI pushed a refreshed token to adopt without a request. This is
        // the authoritative cache writer: drive accessToken/tokenStream so a
        // live re-auth consumer sees the new token. (Non-null by protocol, so a
        // push can never invalidate the cache — only a null pull response can.)
        _cacheToken(message.accessToken);
      default:
        // Other control-message variants are not this service's concern.
        break;
    }
  }

  /// Caches [token] as the current access token, clearing any prior sign-out
  /// invalidation. Skipped after dispose (the subject is closed) — callers still
  /// receive their token; only the cache write is moot mid-shutdown.
  void _cacheToken(String token) {
    if (_disposed) return;
    _invalidated = false;
    _tokenSubject.add(token);
  }

  /// Marks the cache unavailable after a signed-out [ControlTokenResponse] so the
  /// synchronous [accessToken] getter throws until a fresh token arrives. The
  /// BehaviorSubject still holds the stale value (it cannot un-emit), but the
  /// guarded getter refuses to return it.
  void _invalidateCache() {
    _invalidated = true;
  }
}
