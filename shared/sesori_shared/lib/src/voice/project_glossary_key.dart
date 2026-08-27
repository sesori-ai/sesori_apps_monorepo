import "dart:convert";

import "package:cryptography/dart.dart";

const _projectGlossaryDigestPrefix = "sesori-project-glossary-v1\u0000";
const _projectGlossaryKeyPrefix = "prj_v1_";

final RegExp _projectGlossaryKeyPattern = RegExp(r"^prj_v1_[A-Za-z0-9_-]{43}$");

/// Derives the auth server's opaque project glossary key without exposing the
/// bridge registration id or project identifier, which may contain a local
/// filesystem path.
String deriveProjectGlossaryKey({required String bridgeId, required String projectId}) {
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
  final digest = const DartSha256().hashSync(digestInput).bytes;
  return "$_projectGlossaryKeyPrefix${base64UrlEncode(digest).replaceAll("=", "")}";
}

bool isValidProjectGlossaryKey({required String value}) => _projectGlossaryKeyPattern.hasMatch(value);
