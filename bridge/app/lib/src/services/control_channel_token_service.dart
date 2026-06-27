import "dart:async";
import "dart:convert";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ControlMessage, ControlTokenResponse, jsonDecodeMap;

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
/// [accessToken] getter and [tokenStream] reflect it. (Pushed `token_update`
/// refreshes and the live relay re-auth that consumes [tokenStream] are wired
/// separately.)
///
/// It owns its subscription to [ControlChannelClient.inbound], decoding each
/// frame into a [ControlMessage] and completing the matching pending request.
/// Non-token-response frames are ignored here (other control messages are
/// handled elsewhere); undecodable frames are logged and skipped so a malformed
/// or forward-compat message can't stall a pull.
class ControlChannelTokenService implements AccessTokenProvider, TokenRefresher {
  static const Duration _defaultRequestTimeout = Duration(seconds: 30);

  final ControlChannelClient _client;
  final Duration _requestTimeout;
  final BehaviorSubject<String> _tokenSubject = BehaviorSubject<String>();
  final Map<String, Completer<String?>> _pending = <String, Completer<String?>>{};
  late final StreamSubscription<String> _subscription;
  int _nextRequestId = 0;
  bool _disposed = false;
  Future<void>? _disposeFuture;

  ControlChannelTokenService({
    required ControlChannelClient client,
    Duration requestTimeout = _defaultRequestTimeout,
  })  : _client = client,
        _requestTimeout = requestTimeout {
    _subscription = _client.inbound.listen(_handleFrame);
  }

  /// The most recently pulled access token. Only valid after the first
  /// successful [getAccessToken]; the composition root awaits the bootstrap pull
  /// before exposing this service as the provider, so this never reads ahead of
  /// a token in practice.
  @override
  String get accessToken {
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
      _client.send(jsonEncode(ControlMessage.tokenRequest(id: id, forceRefresh: forceRefresh).toJson()));
      final accessToken = await completer.future.timeout(_requestTimeout);
      if (accessToken == null) {
        throw const ControlTokenUnavailableException(
          "The desktop app could not supply an access token (signed out or mid-login).",
        );
      }
      // Cache the latest token so the synchronous getter and tokenStream stay
      // current. Skip if a dispose raced this pull (which closes the subject) —
      // returning the token to the caller is still correct mid-shutdown.
      if (!_disposed) {
        _tokenSubject.add(accessToken);
      }
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
    if (message is ControlTokenResponse) {
      final completer = _pending.remove(message.id);
      if (completer != null && !completer.isCompleted) {
        completer.complete(message.accessToken);
      }
    }
    // Other control-message variants are not this service's concern.
  }
}
