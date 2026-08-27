import "dart:convert";

import "package:cryptography/dart.dart";

const _projectGlossaryDigestPrefix = "sesori-project-glossary-v1\u0000";
const _projectGlossaryKeyPrefix = "prj_v1_";

final RegExp _projectGlossaryKeyPattern = RegExp(r"^prj_v1_[A-Za-z0-9_-]{43}$");

/// Derives the auth server's opaque project glossary key without exposing the
/// bridge's project identifier, which may contain a local filesystem path.
String deriveProjectGlossaryKey({required String projectId}) {
  if (projectId.isEmpty) {
    throw ArgumentError.value(projectId, "projectId", "must not be empty");
  }

  final digestInput = utf8.encode("$_projectGlossaryDigestPrefix$projectId");
  final digest = const DartSha256().hashSync(digestInput).bytes;
  return "$_projectGlossaryKeyPrefix${base64UrlEncode(digest).replaceAll("=", "")}";
}

bool isValidProjectGlossaryKey({required String value}) => _projectGlossaryKeyPattern.hasMatch(value);
