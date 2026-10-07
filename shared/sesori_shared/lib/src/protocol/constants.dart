/// Wire protocol constants shared with relay and bridge.
abstract final class RelayProtocol() {
  // Message types for bridge status control messages from relay
  static const typeBridgeConnected = "bridge_connected";
  static const typeBridgeDisconnected = "bridge_disconnected";

  // Auth message fields
  static const typeAuth = "auth";
  static const rolePhone = "phone";

  // Payload type detection
  static const int versionByte = 0x01;
  static const int jsonStartByte = 0x7B;

  /// First byte of a decrypted plaintext that holds a deflated message.
  ///
  /// The layout is this marker followed by a raw deflate stream (no zlib
  /// header) of the UTF-8 JSON message. A plain plaintext always starts with
  /// [jsonStartByte], so the reader needs no other signal. Only a response to
  /// a `RelayRequest` whose `acceptsDeflatedResponse` is true uses it; the
  /// outer frame and [versionByte] are unchanged.
  static const int deflatedPlaintextMarker = 0x00;

  /// Relay WebSocket messages are capped at 64 MiB by the relay server.
  static const int maxMessageBytes = 64 * 1024 * 1024;

  /// One protocol-version byte, a 24-byte XChaCha20 nonce, and a 16-byte tag.
  static const int encryptedMessageOverheadBytes = 1 + 24 + 16;
  static const int maxPlaintextMessageBytes = maxMessageBytes - encryptedMessageOverheadBytes;

  static bool canEncryptMessage({required int plaintextBytes}) {
    return plaintextBytes >= 0 && plaintextBytes <= maxPlaintextMessageBytes;
  }
}
