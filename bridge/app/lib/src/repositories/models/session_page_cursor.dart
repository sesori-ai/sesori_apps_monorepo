import "dart:convert";

/// Where a session page continues: the pin group, sort time and id of the
/// previous page's last row. Clients hold it as an opaque string.
class const SessionPageCursor({
  required final bool pinned,
  required final int sortAt,
  required final String sessionId,
}) {
  /// The cursor [encoded] holds, or null when it is not one this bridge wrote.
  static SessionPageCursor? tryParse({required String encoded}) {
    final String decoded;
    try {
      decoded = utf8.decode(base64Url.decode(encoded));
    } on FormatException {
      return null;
    }
    // The session id comes last, so it may itself hold the separator.
    final pinnedEnd = decoded.indexOf(":");
    if (pinnedEnd < 0) return null;
    final sortAtEnd = decoded.indexOf(":", pinnedEnd + 1);
    if (sortAtEnd < 0) return null;
    final pinned = switch (decoded.substring(0, pinnedEnd)) {
      "1" => true,
      "0" => false,
      _ => null,
    };
    final sortAt = int.tryParse(decoded.substring(pinnedEnd + 1, sortAtEnd));
    final sessionId = decoded.substring(sortAtEnd + 1);
    if (pinned == null || sortAt == null || sessionId.isEmpty) return null;
    return SessionPageCursor(pinned: pinned, sortAt: sortAt, sessionId: sessionId);
  }

  String encode() => base64Url.encode(utf8.encode("${pinned ? 1 : 0}:$sortAt:$sessionId"));
}
