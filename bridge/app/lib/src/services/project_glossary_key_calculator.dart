import "dart:convert";

import "package:cryptography/cryptography.dart" show SecretKeyData;
import "package:cryptography/dart.dart";

/// Derives the auth server's opaque key with bridge-local HMAC material that
/// the server cannot use to dictionary-test path-based project identifiers.
class const ProjectGlossaryKeyCalculator() {
  static const String _digestPrefix = "sesori-project-glossary-v1\u0000";
  static const String _keyPrefix = "prj_v1_";

  String calculate({
    required List<int> secret,
    required String bridgeId,
    required String projectId,
  }) {
    if (secret.length < 32) {
      throw ArgumentError.value(secret.length, "secret", "must contain at least 32 bytes");
    }
    if (bridgeId.isEmpty) {
      throw ArgumentError.value(bridgeId, "bridgeId", "must not be empty");
    }
    if (projectId.isEmpty) {
      throw ArgumentError.value(projectId, "projectId", "must not be empty");
    }

    final bridgeIdBytes = utf8.encode(bridgeId);
    final input = utf8.encode("$_digestPrefix${bridgeIdBytes.length}\u0000$bridgeId\u0000$projectId");
    final mac = DartHmac.sha256().calculateMacSync(
      input,
      secretKeyData: SecretKeyData(secret),
      nonce: const [],
    );
    return "$_keyPrefix${base64UrlEncode(mac.bytes).replaceAll("=", "")}";
  }
}
