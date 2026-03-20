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

  static const noReconnectCodes = {
    authFailure,
    authRequired,
    roomFull,
    roomNotFound,
    accountFull,
  };

  /// Returns true if the close code indicates the client should attempt reconnection.
  /// Returns false for terminal errors (auth failure, auth required, room full, room not found, account full).
  static bool shouldReconnect(int? closeCode) {
    if (closeCode == null) return true;
    return !noReconnectCodes.contains(closeCode);
  }
}
