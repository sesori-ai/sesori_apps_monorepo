import "dart:typed_data";

import "package:cryptography/cryptography.dart" show Sha256;

/// Calculates a generic SHA-256 digest through the shared crypto boundary.
Future<Uint8List> calculateSha256({required List<int> message}) async {
  final hash = await Sha256().hash(message);
  return Uint8List.fromList(hash.bytes);
}
