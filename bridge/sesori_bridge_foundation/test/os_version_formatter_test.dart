import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  const formatter = OsVersionFormatter();

  String? format({
    required String os,
    String version = "",
    String? osRelease,
  }) =>
      formatter.format(
        operatingSystem: os,
        operatingSystemVersion: version,
        osReleaseContents: osRelease,
      );

  group("macOS", () {
    test("extracts the version number from the raw version string", () {
      expect(format(os: "macos", version: "Version 14.5 (Build 23F79)"), equals("macOS 14.5"));
      expect(format(os: "macos", version: "Version 26.0 (Build 25A100)"), equals("macOS 26.0"));
    });

    test("returns null when no version number is present", () {
      expect(format(os: "macos", version: "Version macOS"), isNull);
    });
  });

  group("Windows", () {
    test("maps build >= 22000 to Windows 11", () {
      expect(format(os: "windows", version: "10.0 (Build 22631)"), equals("Windows 11"));
      expect(format(os: "windows", version: "10.0.26100"), equals("Windows 11"));
    });

    test("maps lower builds to Windows 10", () {
      expect(format(os: "windows", version: "10.0 (Build 19045)"), equals("Windows 10"));
      expect(format(os: "windows", version: "10.0.19045"), equals("Windows 10"));
    });

    test("returns null when no build number is present", () {
      expect(format(os: "windows", version: "10.0"), isNull);
    });
  });

  group("Linux", () {
    test("prefers PRETTY_NAME from /etc/os-release", () {
      const osRelease = '''
NAME="Ubuntu"
VERSION_ID="22.04"
PRETTY_NAME="Ubuntu 22.04.3 LTS"
''';
      expect(format(os: "linux", osRelease: osRelease), equals("Ubuntu 22.04.3 LTS"));
    });

    test("falls back to NAME + VERSION_ID when PRETTY_NAME is absent", () {
      const osRelease = '''
NAME="Debian GNU/Linux"
VERSION_ID="12"
''';
      expect(format(os: "linux", osRelease: osRelease), equals("Debian GNU/Linux 12"));
    });

    test("tolerates single quotes, comments, and blank lines", () {
      const osRelease = '''
# a comment

PRETTY_NAME='Fedora Linux 40'
''';
      expect(format(os: "linux", osRelease: osRelease), equals("Fedora Linux 40"));
    });

    test("returns null when os-release contents are unavailable", () {
      expect(format(os: "linux", osRelease: null), isNull);
    });
  });

  test("returns null for an unknown operating system", () {
    expect(format(os: "fuchsia", version: "1.0"), isNull);
  });

  test("clamps the label to the 40-char server limit", () {
    const osRelease = 'PRETTY_NAME="A Very Long Distribution Name That Exceeds The Limit"';
    final result = format(os: "linux", osRelease: osRelease);
    expect(result, isNotNull);
    expect(result!.length, lessThanOrEqualTo(OsVersionFormatter.maxLength));
  });
}
