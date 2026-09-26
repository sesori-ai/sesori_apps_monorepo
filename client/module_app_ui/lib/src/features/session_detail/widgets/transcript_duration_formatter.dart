import "../../../l10n/app_localizations.dart";

/// The one way the transcript writes a duration: "42s", "1m 02s" or
/// "1h 05m 12s", seconds always shown.
abstract final class TranscriptDurationFormatter() {
  /// A negative [duration] reads "0s": a start stamped by the harness machine's
  /// clock can sit a little ahead of this device's.
  static String format({required AppLocalizations loc, required Duration duration}) {
    final clamped = duration.isNegative ? Duration.zero : duration;
    final seconds = _twoDigits(value: clamped.inSeconds % 60);
    if (clamped.inMinutes < 1) return loc.transcriptTurnSeconds(clamped.inSeconds);
    if (clamped.inHours < 1) return loc.transcriptTurnMinutes(clamped.inMinutes, seconds);
    return loc.transcriptTurnHours(clamped.inHours, _twoDigits(value: clamped.inMinutes % 60), seconds);
  }

  static String _twoDigits({required int value}) => "$value".padLeft(2, "0");
}
