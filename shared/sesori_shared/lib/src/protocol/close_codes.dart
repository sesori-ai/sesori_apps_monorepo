/// Semantic WebSocket close codes for the relay protocol.
abstract final class RelayCloseCodes() {
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
}
