import "dart:convert";

/// Where a session page continues: the sort time and id of the previous
/// page's last row. Clients hold it as an opaque string.
class const SessionPageCursor({required final int sortAt, required final String sessionId}) {
  /// The cursor [encoded] holds, or null when it is not one this bridge wrote.
  static SessionPageCursor? tryParse({required String encoded}) {
    final String decoded;
    try {
      decoded = utf8.decode(base64Url.decode(encoded));
    } on FormatException {
      return null;
    }
    final separator = decoded.indexOf(":");
    if (separator < 0) return null;
    final sortAt = int.tryParse(decoded.substring(0, separator));
    final sessionId = decoded.substring(separator + 1);
    if (sortAt == null || sessionId.isEmpty) return null;
    return SessionPageCursor(sortAt: sortAt, sessionId: sessionId);
  }

  String encode() => base64Url.encode(utf8.encode("$sortAt:$sessionId"));
}
