/// Semantic WebSocket close codes for the relay protocol.
abstract final class RelayCloseCodes {
  /// Authentication failure — do NOT reconnect.
  static const authFailure = 4001;

  /// Authentication required but not provided — do NOT reconnect.
  static const authRequired = 4002;

  /// Room is full (already has 2 connections) — do NOT reconnect.
  static const roomFull = 4003;

  /// Room not found or expired — do NOT reconnect.
  static const roomNotFound = 4004;

  /// Account full — too many devices connected (>5) — do NOT reconnect.
  static const accountFull = 4005;

  /// Bridge revoked — the bridge's registration was deleted on the auth
  /// server. The bridge must re-register before connecting again — do NOT
  /// reconnect with the same bridge id.
  static const bridgeRevoked = 4006;

  /// Bridge replaced — another bridge for the same account connected and took
  /// this bridge's single relay slot. The displaced bridge SHOULD still
  /// reconnect (headless/VM failover), but only on a long backoff so two
  /// always-on bridges don't tight-loop kicking each other. Deliberately NOT
  /// in [noReconnectCodes]: the policy is long-backoff, not never-reconnect.
  static const bridgeReplaced = 4007;

  /// The close reason the relay pairs with a `1000` normal close when it
  /// displaces a bridge, used only as a rollout fallback before the relay
  /// emits [bridgeReplaced]. Close reason strings are fragile (intermediaries
  /// may strip/rewrite them), so [bridgeReplaced] is the authoritative signal;
  /// this matches only during the relay-deploy window.
  static const bridgeReplacedFallbackReason = "replaced";

  static const noReconnectCodes = {
    authFailure,
    authRequired,
    roomFull,
    roomNotFound,
    accountFull,
    bridgeRevoked,
  };

  /// Returns true if the close code indicates the client should attempt reconnection.
  /// Returns false for terminal errors (auth failure, auth required, room full, room not found, account full,
  /// bridge revoked).
  static bool shouldReconnect(int? closeCode) {
    if (closeCode == null) return true;
    return !noReconnectCodes.contains(closeCode);
  }

  /// Whether a close indicates this bridge was displaced by another bridge on
  /// the same account (see [bridgeReplaced]). The dedicated [bridgeReplaced]
  /// code is authoritative and reason-independent; a `1000` normal close whose
  /// reason is [bridgeReplacedFallbackReason] is only matched as a rollout
  /// fallback for the relay-deploy window.
  ///
  /// This is the single detection rule shared by the reconnect-loop policy and
  /// the supervised status push, so the two never diverge on what a takeover
  /// looks like.
  static bool isBridgeReplaced({required int? closeCode, required String? closeReason}) {
    if (closeCode == bridgeReplaced) return true;
    return closeCode == 1000 && closeReason == bridgeReplacedFallbackReason;
  }
}
