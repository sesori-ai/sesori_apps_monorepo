import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  group("resolveUserHomeDirectory", () {
    test("prefers the platform-specific environment variable", () {
      expect(
        resolveUserHomeDirectory(
          environment: const {"HOME": "/home/alex", "USERPROFILE": r"C:\Users\Alex"},
        ),
        equals(Platform.isWindows ? r"C:\Users\Alex" : "/home/alex"),
      );
    });

    test("falls back when the platform-specific value is blank", () {
      expect(
        resolveUserHomeDirectory(
          environment: Platform.isWindows
              ? const {"USERPROFILE": "  ", "HOME": "/home/alex"}
              : const {"HOME": "\t", "USERPROFILE": r"C:\Users\Alex"},
        ),
        equals(Platform.isWindows ? "/home/alex" : r"C:\Users\Alex"),
      );
    });

    test("returns null when neither value is available", () {
      expect(resolveUserHomeDirectory(environment: const {}), isNull);
    });

    test("returns null when both values are blank", () {
      expect(
        resolveUserHomeDirectory(
          environment: const {"HOME": " ", "USERPROFILE": "\t"},
        ),
        isNull,
      );
    });
  });

  group("sesoriDataDirectory", () {
    test("resolves the canonical per-platform Sesori data directory", () {
      final dir = sesoriDataDirectory();
      if (Platform.isWindows) {
        expect(dir, equals("${Platform.environment["LOCALAPPDATA"]}/sesori"));
      } else {
        expect(dir, equals("${Platform.environment["HOME"]}/.local/share/sesori"));
      }
    });

    test("is stable across calls (single resolution)", () {
      expect(sesoriDataDirectory(), equals(sesoriDataDirectory()));
    });
  });
}
