import "dart:convert";

import "package:cryptography/cryptography.dart" show SecretKeyData;
import "package:cryptography/dart.dart";

const _projectGlossaryDigestPrefix = "sesori-project-glossary-v1\u0000";
const _projectGlossaryKeyPrefix = "prj_v1_";

final RegExp _projectGlossaryKeyPattern = RegExp(r"^prj_v1_[A-Za-z0-9_-]{43}$");

/// Derives the auth server's opaque project glossary key using bridge-local
/// key material unknown to the server. The project identifier may contain a
/// local filesystem path, so an unkeyed digest is insufficient.
String deriveProjectGlossaryKey({
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
  final digestInput = utf8.encode(
    "$_projectGlossaryDigestPrefix${bridgeIdBytes.length}\u0000$bridgeId\u0000$projectId",
  );
  final mac = DartHmac.sha256().calculateMacSync(
    digestInput,
    secretKeyData: SecretKeyData(secret),
    nonce: const [],
  );
  return "$_projectGlossaryKeyPrefix${base64UrlEncode(mac.bytes).replaceAll("=", "")}";
}

bool isValidProjectGlossaryKey({required String value}) => _projectGlossaryKeyPattern.hasMatch(value);
