import "dart:convert";

import "package:cryptography/dart.dart";

const _projectGlossaryDigestPrefix = "sesori-project-glossary-v1\u0000";
const _projectGlossaryKeyPrefix = "prj_v1_";

final RegExp _projectGlossaryKeyPattern = RegExp(r"^prj_v1_[A-Za-z0-9_-]{43}$");

String deriveProjectGlossaryKey(String projectId) {
  final digestInput = utf8.encode("$_projectGlossaryDigestPrefix$projectId");
  final digest = const DartSha256().hashSync(digestInput).bytes;
  return "$_projectGlossaryKeyPrefix${base64UrlEncode(digest).replaceAll("=", "")}";
}

bool isValidProjectGlossaryKey(String value) => _projectGlossaryKeyPattern.hasMatch(value);
