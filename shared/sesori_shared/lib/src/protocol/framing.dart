import "dart:typed_data";

import "../crypto/session_encryptor.dart";

const int protocolVersion = 0x01;

/// Encrypts plaintext and prepends the protocol version byte.
/// Returns: [version_byte][encrypted_payload]
Future<Uint8List> frame(List<int> plaintext, {required SessionEncryptor encryptor}) async {
  final encrypted = await encryptor.encrypt(plaintext);
  final framed = Uint8List(1 + encrypted.length);
  framed[0] = protocolVersion;
  framed.setRange(1, framed.length, encrypted);
  return framed;
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
  final encrypted = data is Uint8List ? Uint8List.sublistView(data, 1) : data.sublist(1);
  return await encryptor.decrypt(encrypted);
}
