import "dart:async";
import "dart:convert";

import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart" show ControlMessage;

import "../auth/access_token_provider.dart";
import "../auth/token_refresher.dart";
import "../foundation/control_channel_client.dart";

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
/// is adopted directly into the cache (driving [accessToken]/[tokenStream]). A pull
/// also seeds the cache. Every cache write (a token or a sign-out invalidation) is
/// stamped with a monotonic sequence at the moment it is ordered — a pull when it
/// is issued, a push when it is adopted — and applies only if it is newer than the
/// write currently reflected in the cache. So the newest-ISSUED decision always
/// wins regardless of which response arrives first: a slow older pull can neither
/// overwrite a newer pushed/pulled token nor clear a newer sign-out, and a later
/// forced refresh is never masked by an older routine pull that completes first.
///
/// A null [ControlTokenResponse] (signed out / mid-login) invalidates the cache: the
/// synchronous [accessToken] getter throws again until a fresh token (pull or push)
/// arrives, so a reconnect can never re-authenticate the relay as a signed-out user
/// from a stale cached token. (`tokenUpdate.accessToken` is non-null, so a push can
/// never signal sign-out — only a null `tokenResponse` can.)
///
/// It does NOT subscribe to [ControlChannelClient.inbound] itself: the
/// `BridgeControlMessageDispatcher` owns the single inbound subscription and
/// decode, delivering token-class messages through the typed delegates
/// [handleTokenResponse] and [handleTokenUpdate]. The request-correlation state
/// and the `token_request` send path stay here.
class ControlChannelTokenService implements AccessTokenProvider, TokenRefresher {
  static const Duration _defaultRequestTimeout = Duration(seconds: 30);

  final ControlChannelClient _client;
  final Duration _requestTimeout;
  final BehaviorSubject<String> _tokenSubject = BehaviorSubject<String>();
  final Map<String, Completer<String?>> _pending = <String, Completer<String?>>{};
  // Monotonic sequence stamped on every write candidate at the moment it is
  // ordered: a pull captures its seq when it is ISSUED; a push takes a fresh seq
  // when it is ADOPTED (so it always outranks every pull already in flight).
  int _nextSeq = 0;
  // The seq of the write currently reflected in the cache. A write applies only
  // if its seq is newer than this, so the newest-ISSUED decision wins regardless
  // of which response happens to arrive first: an older in-flight pull can never
  // overwrite a newer push/pull's token nor clear a newer sign-out, and a later
  // forced refresh is never masked just because an older routine pull completed
  // first.
  int _appliedSeq = -1;
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
        _requestTimeout = requestTimeout;

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
    // After dispose no delegate delivery is accepted, so a response can never
    // arrive — fail fast instead of registering a completer that would only
    // resolve via the timeout.
    if (_disposed) {
      throw const ControlTokenUnavailableException(
        "Control channel token service has been disposed.",
      );
    }
    // Stamp this pull's issue order. Its result (cache the token, or invalidate
    // on null) applies only if it is still the newest-issued write when it
    // resolves — a later pull or a GUI push (each taking a higher seq) wins even
    // if it completes first.
    final seq = _nextSeq++;
    final id = "token-$seq";
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
        // reconnect can't re-authenticate the relay from a stale token. The GUI
        // push (token_update) is non-null and so can never signal this. Apply
        // only if this is still the newest-issued write, so a stale null can't
        // clear a newer token (push or a later pull issued after the sign-out).
        _applyWrite(seq, _invalidateCache);
        throw const ControlTokenUnavailableException(
          "The desktop app could not supply an access token (signed out or mid-login).",
        );
      }
      // Seed the cache so the synchronous getter and tokenStream stay current,
      // but only if this is still the newest-issued write: a GUI token_update
      // push or a later pull must not be reverted by a slow older pull, even one
      // that completes after them. The caller still receives this pull's own
      // token below regardless.
      _applyWrite(seq, () => _cacheToken(accessToken));
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

  /// Delivers the GUI's reply to a pending [ControlMessage.tokenRequest].
  /// Called by the control-message dispatcher (the single inbound subscriber);
  /// replies for unknown or already-resolved ids are ignored (e.g. arriving
  /// after the request timed out).
  void handleTokenResponse({required String id, required String? accessToken}) {
    if (_disposed) return;
    final completer = _pending.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(accessToken);
    }
  }

  /// Adopts a token the GUI pushed without a request. It takes a fresh seq at
  /// adoption time, so it outranks every pull already in flight and becomes the
  /// newest write — a slow older pull resolving afterwards can't revert it.
  /// (Non-null by protocol, so a push never invalidates the cache — only a null
  /// pull response can.) Called by the control-message dispatcher.
  void handleTokenUpdate({required String accessToken}) {
    if (_disposed) return;
    _applyWrite(_nextSeq++, () => _cacheToken(accessToken));
  }

  /// Runs [write] only if [seq] is newer than the write currently reflected in
  /// the cache, advancing [_appliedSeq] when it does. This makes the
  /// newest-issued write win regardless of completion order, so an older pull
  /// resolving late can neither overwrite a newer token nor clear a newer
  /// sign-out.
  void _applyWrite(int seq, void Function() write) {
    if (seq <= _appliedSeq) return;
    _appliedSeq = seq;
    write();
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
