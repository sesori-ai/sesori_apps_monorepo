import "dart:convert";

final class const PiPersistedUserTextCodec() {
  static const String marker = "SESORI_PI_USER_TEXT_V1:";
  static final RegExp _positiveLength = RegExp(r"^[1-9][0-9]*$");

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

  String decodeVisibleText({required String persistedText}) {
    if (!persistedText.startsWith(marker)) return persistedText;
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
