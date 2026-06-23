import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("PlatformOs.fromOperatingSystem", () {
    test("maps supported operating systems", () {
      expect(PlatformOs.fromOperatingSystem(operatingSystem: "macos"), equals(PlatformOs.macos));
      expect(PlatformOs.fromOperatingSystem(operatingSystem: "linux"), equals(PlatformOs.linux));
      expect(PlatformOs.fromOperatingSystem(operatingSystem: "windows"), equals(PlatformOs.windows));
    });

    test("throws ArgumentError for an unsupported os", () {
      expect(
        () => PlatformOs.fromOperatingSystem(operatingSystem: "freebsd"),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group("PlatformArch.fromDartVersion", () {
    test("detects arm64 from runtime version variants", () {
      expect(
        PlatformArch.fromDartVersion(dartVersion: "Dart VM version on arm64"),
        equals(PlatformArch.arm64),
      );
      expect(
        PlatformArch.fromDartVersion(dartVersion: "Dart VM version on aarch64"),
        equals(PlatformArch.arm64),
      );
    });

    test("detects x64 from runtime version variants", () {
      expect(
        PlatformArch.fromDartVersion(dartVersion: "Dart VM version on x86_64"),
        equals(PlatformArch.x64),
      );
      expect(
        PlatformArch.fromDartVersion(dartVersion: "Dart VM version on x64"),
        equals(PlatformArch.x64),
      );
    });

    test("throws ArgumentError when the runtime version is unknown", () {
      expect(
        () => PlatformArch.fromDartVersion(dartVersion: "Dart VM version on something-else"),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group("PlatformTarget", () {
    test("key joins os and arch", () {
      const target = PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64);
      expect(target.key, equals("macos arm64"));
    });

    test("value equality is by os and arch", () {
      expect(
        const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64),
        equals(const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64)),
      );
      expect(
        const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64),
        isNot(equals(const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64))),
      );
    });

    test("current() resolves to the host target without throwing", () {
      final target = PlatformTarget.current();
      expect(PlatformOs.values, contains(target.os));
      expect(PlatformArch.values, contains(target.arch));
    });
  });
}
