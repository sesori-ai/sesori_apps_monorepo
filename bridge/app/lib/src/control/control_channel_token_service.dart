import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ControlMessage, ControlTokenResponse, jsonDecodeMap;

import "../foundation/control_channel_client.dart";

/// Thrown when the GUI cannot supply an access token over the control channel —
/// either it replied with a null token (signed out / mid-login) or it did not
/// reply within the request timeout. The supervised-startup caller surfaces and
/// logs this once, so this path deliberately does not log it (avoids
/// double-logging).
class ControlTokenUnavailableException implements Exception {
  final String reason;
  const ControlTokenUnavailableException(this.reason);
  @override
  String toString() => "ControlTokenUnavailableException: $reason";
}

/// Supervised-mode token bootstrap over the loopback control channel: the GUI,
/// not an interactive terminal, is the bridge's token authority. This service
/// asks the GUI for an access token by sending a [ControlMessage.tokenRequest]
/// and awaiting the id-correlated [ControlMessage.tokenResponse], replacing the
/// standalone interactive login during startup.
///
/// It owns its subscription to [ControlChannelClient.inbound], decoding each
/// frame into a [ControlMessage] and completing the matching pending request.
/// Non-token-response frames are ignored here (other control messages are
/// handled elsewhere); undecodable frames are logged and skipped so a malformed
/// or forward-compat message can't stall the bootstrap.
class ControlChannelTokenService {
  static const Duration _defaultRequestTimeout = Duration(seconds: 30);

  final ControlChannelClient _client;
  final Map<String, Completer<String?>> _pending = <String, Completer<String?>>{};
  late final StreamSubscription<String> _subscription;
  int _nextRequestId = 0;
  bool _disposed = false;

  ControlChannelTokenService({required ControlChannelClient client}) : _client = client {
    _subscription = _client.inbound.listen(_handleFrame);
  }

  /// Requests an access token from the GUI over the control channel and waits
  /// for the correlated reply. Throws [ControlTokenUnavailableException] when
  /// the GUI replies with no token (signed out / mid-login) or does not reply
  /// within [timeout]. Does not log on failure — the caller surfaces it once.
  Future<String> requestToken({
    bool forceRefresh = false,
    Duration timeout = _defaultRequestTimeout,
  }) async {
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
      final accessToken = await completer.future.timeout(timeout);
      if (accessToken == null) {
        throw const ControlTokenUnavailableException(
          "The desktop app could not supply an access token (signed out or mid-login).",
        );
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

  Future<void> dispose() async {
    if (_disposed) return;
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
