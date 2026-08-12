import "package:meta/meta.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

/// A backend runtime's version, ordered per its publisher's own scheme and
/// preserving the exact string that publisher uses.
///
/// [SemanticVersion] alone cannot serve every backend: Cursor publishes
/// calendar builds like `2026.08.04-aaa8809` and `2026.06.15-18-00-12-6f5a2cf`,
/// which either fail semver parsing outright or sort *below* the same-day
/// stable version because semver treats the build hash as a prerelease. Both
/// misreadings are dangerous here — they make a healthy runtime look absent or
/// too old.
///
/// Implementations compare only against their own scheme; mixing schemes is a
/// programming error and throws.
@immutable
sealed class RuntimeVersion implements Comparable<RuntimeVersion> {
  const RuntimeVersion();

  /// The publisher's exact version string, suitable for download URLs and
  /// on-disk version directories. Never a normalized rendering.
  String get raw;

  @override
  String toString() => raw;
}

/// A semver-ordered runtime version (OpenCode, codex).
final class SemanticRuntimeVersion extends RuntimeVersion {
  const SemanticRuntimeVersion._({required this.raw, required this.version});

  factory SemanticRuntimeVersion.parse({required String value}) {
    return SemanticRuntimeVersion._(
      raw: value.trim(),
      version: SemanticVersion.parse(value: value),
    );
  }

  static SemanticRuntimeVersion? tryParse({required String value}) {
    final parsed = SemanticVersion.tryParse(value: value);
    return parsed == null ? null : SemanticRuntimeVersion._(raw: value.trim(), version: parsed);
  }

  @override
  final String raw;

  final SemanticVersion version;

  @override
  int compareTo(RuntimeVersion other) {
    if (other is! SemanticRuntimeVersion) {
      throw ArgumentError.value(other, "other", "cannot compare a semantic version with ${other.runtimeType}");
    }
    return version.compareTo(other.version);
  }

  @override
  bool operator ==(Object other) => other is SemanticRuntimeVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(
    version.major,
    version.minor,
    version.patch,
    Object.hashAll(
      version.prereleaseIdentifiers.map(
        (identifier) => int.tryParse(identifier) ?? identifier,
      ),
    ),
  );
}

/// A calendar-dated runtime version (Cursor): `YYYY.MM.DD` optionally followed
/// by an opaque build suffix (`-aaa8809`, `-18-00-12-6f5a2cf`).
///
/// Ordering uses the calendar date only. The suffix identifies a build within a
/// day and carries no order, so a dated build is never ranked below the same
/// day's bare version — the mistake semver ordering makes.
final class CalendarRuntimeVersion extends RuntimeVersion {
  const CalendarRuntimeVersion._({
    required this.raw,
    required this.year,
    required this.month,
    required this.day,
  });

  static final RegExp _pattern = RegExp(r"^(\d{4})\.(\d{1,2})\.(\d{1,2})(?:[-.].*)?$");

  factory CalendarRuntimeVersion.parse({required String value}) {
    final parsed = tryParse(value: value);
    if (parsed == null) {
      throw FormatException('Version "$value" is not a YYYY.MM.DD calendar build.');
    }
    return parsed;
  }

  static CalendarRuntimeVersion? tryParse({required String value}) {
    final trimmed = value.trim();
    final match = _pattern.firstMatch(trimmed);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return null;
    return CalendarRuntimeVersion._(
      raw: trimmed,
      year: year,
      month: month,
      day: day,
    );
  }

  @override
  final String raw;

  final int year;
  final int month;
  final int day;

  @override
  int compareTo(RuntimeVersion other) {
    if (other is! CalendarRuntimeVersion) {
      throw ArgumentError.value(other, "other", "cannot compare a calendar version with ${other.runtimeType}");
    }
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    if (byMonth != 0) return byMonth;
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarRuntimeVersion && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
