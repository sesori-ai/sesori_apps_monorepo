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

  group("resolveSesoriAttachmentsDirectory", () {
    test("uses macOS Application Support", () {
      expect(
        resolveSesoriAttachmentsDirectory(
          environment: const {"HOME": "/Users/alex"},
          operatingSystem: PlatformOs.macos,
        ),
        "/Users/alex/Library/Application Support/Sesori Attachments",
      );
    });

    test("honors Linux XDG_DATA_HOME", () {
      expect(
        resolveSesoriAttachmentsDirectory(
          environment: const {
            "HOME": "/home/alex",
            "XDG_DATA_HOME": "/srv/alex-data",
          },
          operatingSystem: PlatformOs.linux,
        ),
        "/srv/alex-data/sesori-attachments",
      );
    });

    test("uses the Linux data fallback when XDG_DATA_HOME is blank", () {
      expect(
        resolveSesoriAttachmentsDirectory(
          environment: const {"HOME": "/home/alex", "XDG_DATA_HOME": " "},
          operatingSystem: PlatformOs.linux,
        ),
        "/home/alex/.local/share/sesori-attachments",
      );
    });

    test("uses Windows Local AppData", () {
      expect(
        resolveSesoriAttachmentsDirectory(
          environment: const {
            "LOCALAPPDATA": r"C:\Users\Alex\AppData\Local",
          },
          operatingSystem: PlatformOs.windows,
        ),
        r"C:\Users\Alex\AppData\Local\Sesori Attachments",
      );
    });
  });
}
