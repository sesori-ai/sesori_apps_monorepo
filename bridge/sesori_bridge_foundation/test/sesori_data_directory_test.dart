import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  group("resolveUserHomeDirectory", () {
    test("prefers HOME", () {
      expect(
        resolveUserHomeDirectory(
          environment: const {"HOME": "/home/alex", "USERPROFILE": r"C:\Users\Alex"},
        ),
        equals("/home/alex"),
      );
    });

    test("falls back to USERPROFILE when HOME is empty", () {
      expect(
        resolveUserHomeDirectory(
          environment: const {"HOME": "", "USERPROFILE": r"C:\Users\Alex"},
        ),
        equals(r"C:\Users\Alex"),
      );
    });

    test("returns null when neither value is available", () {
      expect(resolveUserHomeDirectory(environment: const {}), isNull);
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
