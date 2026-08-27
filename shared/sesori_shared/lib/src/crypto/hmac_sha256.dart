import "dart:typed_data";

import "package:cryptography/cryptography.dart" show Hmac, SecretKey;

/// Calculates a generic HMAC-SHA-256 digest through the shared crypto boundary.
Future<Uint8List> calculateHmacSha256({
  required List<int> secret,
  required List<int> message,
}) async {
  final mac = await Hmac.sha256().calculateMac(message, secretKey: SecretKey(secret));
  return Uint8List.fromList(mac.bytes);
}
