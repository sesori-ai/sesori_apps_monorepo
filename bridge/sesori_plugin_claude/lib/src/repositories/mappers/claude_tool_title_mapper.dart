/// Extracts the primary argument of a Claude tool input as the card title:
/// the skill name, the file path of Read/Write/Edit, the Grep/Glob pattern,
/// or the WebFetch/WebSearch target. Bash keeps its command through
/// [ClaudeShellCommandMapper] and the projection uses it as the title.
abstract final class ClaudeToolTitleMapper() {
  static const _keys = ["skill", "file_path", "pattern", "path", "url", "query"];

  static String? map({required Object? input}) {
    if (input is! Map) return null;
    for (final key in _keys) {
      final value = input[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }
}
