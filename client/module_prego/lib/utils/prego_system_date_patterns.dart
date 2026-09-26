import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// The user's own date and time patterns, read from the OS on Apple platforms.
///
/// Apple keeps the region and custom formats apart from the language, and
/// Flutter's locale carries only the language: English with a Bulgarian region
/// reports `en_US`, so intl would format month/day. Patterns are keyed by intl
/// skeleton (`yMd`, `Md`, `MMMd`, `yMMMd`, `jm`) and are empty on other
/// platforms, where the platform locale already carries the region.
abstract final class PregoSystemDatePatterns() {
  static const _channel = MethodChannel("theme_prego/date_patterns");

  static Map<String, String> _patterns = const {};

  static Map<String, String> get patterns => _patterns;

  /// Reads the patterns once at startup; a region change applies on relaunch.
  /// A failure is reported and leaves intl's patterns in place, since startup
  /// must not stop over a date format.
  static Future<void> load() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      final patterns = await _channel.invokeMapMethod<String, String>("load");
      if (patterns != null) debugSetPatterns(patterns);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: "theme_prego",
          context: ErrorDescription("while reading the OS date patterns"),
        ),
      );
    }
  }

  /// Takes the OS patterns; the yearless month/day comes from the short date,
  /// which is where a custom format such as `d/M/yy` lives.
  @visibleForTesting
  static void debugSetPatterns(Map<String, String> patterns) {
    final shortDate = patterns["yMd"];
    final monthDay = shortDate == null ? null : _withoutYear(shortDate);
    _patterns = {...patterns, "Md": ?monthDay};
  }

  // ponytail: drops a leading or trailing year and its separator, which covers
  // every short date format in CLDR; anything else falls back to intl's `Md`.
  static String? _withoutYear(String pattern) {
    final stripped = pattern.replaceFirst(RegExp(r"^y+[^A-Za-z']*|[^A-Za-z']*y+$"), "");
    return stripped.isEmpty || stripped.contains("y") ? null : stripped;
  }
}
