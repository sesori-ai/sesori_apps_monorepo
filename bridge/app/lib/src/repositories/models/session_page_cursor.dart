import "dart:convert";

/// Where a session page continues: the pin order, sort time and id of the
/// previous page's last row, with no pin order for an unpinned row or a page
/// not ordered pinned first. Clients hold it as an opaque string.
class const SessionPageCursor({
  required final int? pinOrder,
  required final int sortAt,
  required final String sessionId,
}) {
  static const String _unpinned = "-";

  /// The cursor [encoded] holds, or null when it is not one this bridge wrote.
  static SessionPageCursor? tryParse({required String encoded}) {
    final String decoded;
    try {
      decoded = utf8.decode(base64Url.decode(encoded));
    } on FormatException {
      return null;
    }
    // The session id comes last, so it may itself hold the separator.
    final pinEnd = decoded.indexOf(":");
    if (pinEnd < 0) return null;
    final sortAtEnd = decoded.indexOf(":", pinEnd + 1);
    if (sortAtEnd < 0) return null;
    final pin = decoded.substring(0, pinEnd);
    final pinOrder = pin.startsWith("p") ? int.tryParse(pin.substring(1)) : null;
    if (pinOrder == null && pin != _unpinned) return null;
    final sortAt = int.tryParse(decoded.substring(pinEnd + 1, sortAtEnd));
    final sessionId = decoded.substring(sortAtEnd + 1);
    if (sortAt == null || sessionId.isEmpty) return null;
    return SessionPageCursor(pinOrder: pinOrder, sortAt: sortAt, sessionId: sessionId);
  }

  String encode() {
    final pin = switch (pinOrder) {
      final pinOrder? => "p$pinOrder",
      null => _unpinned,
    };
    return base64Url.encode(utf8.encode("$pin:$sortAt:$sessionId"));
  }
}
