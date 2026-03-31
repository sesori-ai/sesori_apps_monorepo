import 'dart:io';

import 'package:crypto/crypto.dart';

class ChecksumVerifierApi {
  Future<bool> verify({
    required String filePath,
    required String expectedHash,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return false;
    }

    final computedHash = await computeSha256(filePath: filePath);
    return computedHash.toLowerCase() == expectedHash.toLowerCase();
  }

  Future<String> computeSha256({required String filePath}) async {
    final file = File(filePath);
    final stream = file.openRead();

    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }
}
