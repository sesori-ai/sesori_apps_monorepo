/// The one way the transcript writes a token count: "940", "142k" or "1.2M".
/// Below ten thousand and from a million on it keeps one decimal, dropping a
/// trailing ".0".
abstract final class TranscriptTokenCountFormatter() {
  static String format({required int tokens}) {
    if (tokens < 1000) return "$tokens";
    // 999,500 and up round to a thousand thousands, so they read as millions.
    if (tokens < 999500) {
      final thousands = tokens / 1000;
      return "${thousands < 9.95 ? _oneDecimal(value: thousands) : "${thousands.round()}"}k";
    }
    return "${_oneDecimal(value: tokens / 1000000)}M";
  }

  static String _oneDecimal({required double value}) {
    final fixed = value.toStringAsFixed(1);
    return fixed.endsWith(".0") ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}
