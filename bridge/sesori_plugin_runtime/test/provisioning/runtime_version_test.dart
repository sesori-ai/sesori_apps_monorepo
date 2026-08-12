import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("SemanticRuntimeVersion", () {
    test("orders per semver and preserves the published string", () {
      final older = SemanticRuntimeVersion.parse(value: "1.17.9");
      final newer = SemanticRuntimeVersion.parse(value: "1.18.11");

      expect(older.compareTo(newer), isNegative);
      expect(newer.raw, "1.18.11");
    });

    test("rejects a non-semver string", () {
      expect(SemanticRuntimeVersion.tryParse(value: "2026.08.04-18-00-12-abc"), isNull);
    });

    test("equality follows semver precedence", () {
      final first = SemanticRuntimeVersion.parse(value: "1.18.11+first");
      final second = SemanticRuntimeVersion.parse(value: "1.18.11+second");

      expect(first.compareTo(second), isZero);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test("equal numeric prerelease identifiers have equal hashes", () {
      final first = SemanticRuntimeVersion.parse(value: "1.18.11-1");
      final second = SemanticRuntimeVersion.parse(value: "1.18.11-01");

      expect(first.compareTo(second), isZero);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  group("CalendarRuntimeVersion", () {
    test("parses every Cursor build shape semver cannot", () {
      // The multi-dash historical shape fails semver parsing outright, which
      // would make a healthy CLI look absent.
      expect(CalendarRuntimeVersion.tryParse(value: "2026.06.15-18-00-12-6f5a2cf"), isNotNull);
      expect(CalendarRuntimeVersion.tryParse(value: "2026.08.04-aaa8809"), isNotNull);
      expect(CalendarRuntimeVersion.tryParse(value: "2026.07.16"), isNotNull);
    });

    test("preserves the publisher's exact string, leading zeros included", () {
      // Normalizing to 2026.8.4 would 404 the download URL and mis-name the
      // on-disk version directory.
      expect(CalendarRuntimeVersion.parse(value: "2026.08.04-aaa8809").raw, "2026.08.04-aaa8809");
    });

    test("a dated build is not ranked below the same day's bare version", () {
      // Semver treats the build suffix as a prerelease and sorts it *below*
      // the bare version, which would reject a CLI exactly at the floor.
      final floor = CalendarRuntimeVersion.parse(value: "2026.07.16");
      final build = CalendarRuntimeVersion.parse(value: "2026.07.16-899851b");

      expect(build.compareTo(floor), isZero);
      expect(build.compareTo(floor), isNot(isNegative));
    });

    test("orders by calendar date", () {
      final july = CalendarRuntimeVersion.parse(value: "2026.07.16-899851b");
      final august = CalendarRuntimeVersion.parse(value: "2026.08.04-aaa8809");

      expect(july.compareTo(august), isNegative);
      expect(august.compareTo(july), isPositive);
    });

    test("rejects a non-calendar string", () {
      expect(CalendarRuntimeVersion.tryParse(value: "1.18.11"), isNull);
      expect(CalendarRuntimeVersion.tryParse(value: "not-a-version"), isNull);
    });

    test("rejects impossible calendar dates", () {
      expect(CalendarRuntimeVersion.tryParse(value: "2026.13.01-build"), isNull);
      expect(CalendarRuntimeVersion.tryParse(value: "2026.02.30-build"), isNull);
    });
  });

  test("comparing across schemes is a programming error", () {
    final semver = SemanticRuntimeVersion.parse(value: "1.0.0");
    final calendar = CalendarRuntimeVersion.parse(value: "2026.07.16");

    expect(() => semver.compareTo(calendar), throwsArgumentError);
    expect(() => calendar.compareTo(semver), throwsArgumentError);
  });
}
