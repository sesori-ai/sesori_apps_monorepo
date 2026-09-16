/// The `code#state` text Claude's sign-in page shows after the user approves.
final class ClaudePastedCode._({required final String value}) {
  static const int maxLength = 512;

  /// Returns null unless [raw] is one `#` between two non-empty parts, with no
  /// whitespace and at most [maxLength] characters. The CLI rejects any other
  /// shape and keeps waiting for another line.
  static ClaudePastedCode? tryParse({required String raw}) {
    if (raw.length > maxLength || raw.contains(RegExp(r"\s"))) return null;
    return switch (raw.split("#")) {
      [final code, final state] when code.isNotEmpty && state.isNotEmpty => ClaudePastedCode._(value: raw),
      _ => null,
    };
  }
}
