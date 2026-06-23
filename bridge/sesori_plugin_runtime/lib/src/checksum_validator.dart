import "dart:io";

import "package:crypto/crypto.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Validates a downloaded file against an expected SHA-256 digest.
///
/// A pure verification primitive shared by the bridge self-updater and the
/// managed OpenCode runtime installer: both pin per-asset checksums and must
/// confirm a payload before it is unpacked or placed.
class ChecksumValidator {
  /// Whether [filePath] hashes to [expectedHash] (case-insensitive hex).
  /// Returns `false` (rather than throwing) when the file is missing or cannot
  /// be read, so a caller can treat a vanished/unreadable download as a failed
  /// verification and stay fail-soft.
  Future<bool> verify({
    required String filePath,
    required String expectedHash,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return false;
    }

    final String computedHash;
    try {
      computedHash = await computeSha256(filePath: filePath);
    } on Object catch (error) {
      // TOCTOU / read failure: the file vanished or became unreadable after the
      // existence check. Treat as a failed verification rather than aborting.
      Log.w("ChecksumValidator: failed to read '$filePath' for verification: $error");
      return false;
    }
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
