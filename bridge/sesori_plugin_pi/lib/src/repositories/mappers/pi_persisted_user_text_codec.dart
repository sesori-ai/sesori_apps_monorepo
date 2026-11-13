import "dart:convert";

final class const PiPersistedUserTextCodec() {
  static const String marker = "SESORI_PI_USER_TEXT_V1:";
  static final RegExp _positiveLength = RegExp(r"^[1-9][0-9]*$");
  static final RegExp _trailingImageHints = RegExp(r"\n\n\[Image[^\n]*\](?:\n\[Image[^\n]*\])*$");

  /// The user message Pi stores for `/skill:name args`: the skill body in a
  /// `<skill>` block, then the arguments. Pi's own TUI parses it the same way.
  static final RegExp _expandedSkill = RegExp(
    r'^<skill name="([^"]+)" location="[^"]+">\n[\s\S]*\n</skill>(?:\n\n([\s\S]+))?$',
  );

  String encode({required String executionText, required String? userVisibleText}) {
    final visibleText = userVisibleText ?? "";
    if (visibleText.isNotEmpty && !executionText.endsWith(visibleText)) {
      throw ArgumentError("userVisibleText must be an exact suffix of executionText");
    }
    final hiddenText = executionText.substring(0, executionText.length - visibleText.length);
    final hiddenLength = utf8.encode(hiddenText).length;
    final visibleLength = utf8.encode(visibleText).length;
    return "$marker$hiddenLength:$visibleLength:$executionText";
  }

  /// Removes the notes Pi appends to a prompt after resizing, converting, or
  /// omitting its images (`"$prompt\n\n${hints.join("\n")}"`).
  String stripImageHints({required String text}) => text.replaceFirst(_trailingImageHints, "");

  String decodeVisibleText({required String persistedText}) {
    return _decodeVisibleText(persistedText: stripImageHints(text: persistedText));
  }

  /// The skill run Pi stored as [persistedText], named as Pi's command list
  /// names it (`skill:name`), or null when the text is not an expanded skill.
  ({String command, String? arguments})? decodeSkillRun({required String persistedText}) {
    final skill = _expandedSkill.firstMatch(stripImageHints(text: persistedText));
    final name = skill?.group(1);
    if (skill == null || name == null) return null;
    return (command: "skill:$name", arguments: skill.group(2));
  }

  String _decodeVisibleText({required String persistedText}) {
    if (!persistedText.startsWith(marker)) {
      if (decodeSkillRun(persistedText: persistedText) case (:final command, :final arguments)) {
        return arguments == null ? "/$command" : "/$command $arguments";
      }
      if (persistedText.startsWith("/")) {
        final separator = persistedText.indexOf(RegExp(r"\s"));
        return separator < 0 ? persistedText : persistedText.substring(0, separator);
      }
      return persistedText;
    }
    final hiddenSeparator = persistedText.indexOf(":", marker.length);
    if (hiddenSeparator < 0) return persistedText;
    final visibleSeparator = persistedText.indexOf(":", hiddenSeparator + 1);
    if (visibleSeparator < 0) return persistedText;
    final hiddenLength = _parseLength(persistedText.substring(marker.length, hiddenSeparator));
    final visibleLength = _parseLength(persistedText.substring(hiddenSeparator + 1, visibleSeparator));
    if (hiddenLength == null || visibleLength == null) return "";
    final payload = utf8.encode(persistedText.substring(visibleSeparator + 1));
    if (hiddenLength + visibleLength != payload.length) return "";
    try {
      utf8.decode(payload.sublist(0, hiddenLength));
      return utf8.decode(payload.sublist(hiddenLength));
    } on FormatException {
      return "";
    }
  }

  int? _parseLength(String value) {
    if (value == "0") return 0;
    if (value.length > 20 || !_positiveLength.hasMatch(value)) return null;
    return int.tryParse(value);
  }
}
