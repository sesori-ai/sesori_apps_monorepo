import "dart:io";

import "package:crypto/crypto.dart";

/// Validates a downloaded file against an expected SHA-256 digest.
///
/// A pure verification primitive shared by the bridge self-updater and the
/// managed OpenCode runtime installer: both pin per-asset checksums and must
/// confirm a payload before it is unpacked or placed.
class ChecksumValidator {
  /// Whether [filePath] hashes to [expectedHash] (case-insensitive hex).
  /// Returns `false` when the file is missing rather than throwing, so a caller
  /// can treat a vanished download as a failed verification.
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

  /// Streams [filePath] through SHA-256 and returns the lowercase hex digest.
  Future<String> computeSha256({required String filePath}) async {
    final file = File(filePath);
    final stream = file.openRead();

    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }
}
