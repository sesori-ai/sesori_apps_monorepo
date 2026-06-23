import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("SemanticVersion", () {
    test("newer major compares positive", () {
      expect(
        SemanticVersion.parse(value: "2.0.0").compareTo(SemanticVersion.parse(value: "1.0.0")),
        isPositive,
      );
    });

    test("newer minor compares positive", () {
      expect(
        SemanticVersion.parse(value: "0.3.0").compareTo(SemanticVersion.parse(value: "0.2.0")),
        isPositive,
      );
    });

    test("newer patch compares positive", () {
      expect(
        SemanticVersion.parse(value: "0.2.1").compareTo(SemanticVersion.parse(value: "0.2.0")),
        isPositive,
      );
    });

    test("equal versions compare to zero", () {
      expect(
        SemanticVersion.parse(value: "1.2.3").compareTo(SemanticVersion.parse(value: "1.2.3")),
        equals(0),
      );
    });

    test("older major compares negative", () {
      expect(
        SemanticVersion.parse(value: "0.1.0").compareTo(SemanticVersion.parse(value: "0.2.0")),
        isNegative,
      );
    });

    test("prerelease is lower precedence than stable with same base", () {
      expect(
        SemanticVersion.parse(value: "1.0.0-beta").compareTo(SemanticVersion.parse(value: "1.0.0")),
        isNegative,
      );
    });

    test("stable is higher precedence than prerelease with same base", () {
      expect(
        SemanticVersion.parse(value: "1.0.0").compareTo(SemanticVersion.parse(value: "1.0.0-beta")),
        isPositive,
      );
    });

    test("stable is higher precedence than internal build with same base", () {
      expect(
        SemanticVersion.parse(value: "9.8.7").compareTo(SemanticVersion.parse(value: "9.8.7-internal.53")),
        isPositive,
      );
      expect(
        SemanticVersion.parse(value: "9.8.7-internal.53").compareTo(SemanticVersion.parse(value: "9.8.7")),
        isNegative,
      );
    });

    test("internal builds with same base compare numerically by build number", () {
      expect(
        SemanticVersion.parse(value: "1.0.9-internal.9").compareTo(SemanticVersion.parse(value: "1.0.9-internal.53")),
        isNegative,
      );
      expect(
        SemanticVersion.parse(value: "1.0.9-internal.54").compareTo(SemanticVersion.parse(value: "1.0.9-internal.53")),
        isPositive,
      );
    });

    test("internal build of a newer base is higher than an older stable", () {
      expect(
        SemanticVersion.parse(value: "1.0.9-internal.53").compareTo(SemanticVersion.parse(value: "1.0.8")),
        isPositive,
      );
    });

    test("prerelease with newer numeric base still compares positive", () {
      expect(
        SemanticVersion.parse(value: "2.0.0-beta").compareTo(SemanticVersion.parse(value: "1.9.9")),
        isPositive,
      );
    });

    test("prerelease identifiers compare lexically when numeric base matches", () {
      expect(
        SemanticVersion.parse(value: "1.0.0-alpha").compareTo(SemanticVersion.parse(value: "1.0.0-beta")),
        isNegative,
      );
    });

    test("build metadata does not affect comparison precedence", () {
      expect(
        SemanticVersion.parse(value: "1.2.3+build.1").compareTo(SemanticVersion.parse(value: "1.2.3+build.9")),
        equals(0),
      );
    });

    test("isStable reflects the absence of prerelease identifiers", () {
      expect(SemanticVersion.parse(value: "1.2.3").isStable, isTrue);
      expect(SemanticVersion.parse(value: "1.2.3-internal.1").isStable, isFalse);
    });

    test("tryParse returns null for invalid strings", () {
      expect(SemanticVersion.tryParse(value: "not-a-version"), isNull);
    });
  });
}
