import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
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
