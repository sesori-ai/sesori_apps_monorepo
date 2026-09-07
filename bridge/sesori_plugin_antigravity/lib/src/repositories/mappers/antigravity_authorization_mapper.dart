import "dart:convert";

import "../../models/antigravity_authentication.dart";

/// Decodes only the pinned stdout challenge line; all other bytes pass through.
class const AntigravityAuthorizationMapper() {
  static const prefix = "Open the following link to authenticate the ACP server: ";

  Uri? parseLine({required List<int> line}) {
    if (line.length < prefix.length) return null;
    for (var index = 0; index < prefix.length; index++) {
      if (line[index] != prefix.codeUnitAt(index)) return null;
    }
    try {
      final text = utf8.decode(line.sublist(prefix.length)).replaceFirst(RegExp(r"\r?\n$"), "");
      if (text.isEmpty || text.length > 16384 || RegExp(r"\s").hasMatch(text)) {
        throw const AntigravityAuthenticationException(message: "Invalid authorization URL", cause: null);
      }
      return Uri.parse(text);
    } on AntigravityAuthenticationException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityAuthenticationException(message: "Cannot decode authorization URL", cause: error),
        stackTrace,
      );
    }
  }
}
