import "../crypto/session_encryptor.dart";

const int protocolVersion = 0x01;

/// Encrypts plaintext and prepends the protocol version byte.
/// Returns: [version_byte][encrypted_payload]
Future<List<int>> frame(List<int> plaintext, {required SessionEncryptor encryptor}) async {
  final encrypted = await encryptor.encrypt(plaintext);
  return [protocolVersion, ...encrypted];
}

/// Validates protocol version byte and decrypts the remainder.
Future<List<int>> unframe(List<int> data, {required SessionEncryptor encryptor}) async {
  if (data.isEmpty) {
    throw const FormatException("Frame too short: expected at least 1 byte");
  }
  if (data[0] != protocolVersion) {
    throw FormatException(
      "Protocol version mismatch: expected 0x${protocolVersion.toRadixString(16).padLeft(2, "0")}, got 0x${data[0].toRadixString(16).padLeft(2, "0")}",
    );
  }
  return encryptor.decrypt(data.sublist(1));
}
