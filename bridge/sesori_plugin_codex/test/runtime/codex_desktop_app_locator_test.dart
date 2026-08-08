import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  group("codexDesktopAppCliCandidates", () {
    test("macOS probes both bundle names under system and user Applications", () {
      final candidates = codexDesktopAppCliCandidates(
        environment: const {"HOME": "/Users/dev"},
        os: PlatformOs.macos,
      );

      expect(candidates, [
        p.join("/Applications", "ChatGPT.app", "Contents", "Resources", "codex"),
        p.join("/Applications", "Codex.app", "Contents", "Resources", "codex"),
        p.join("/Users/dev", "Applications", "ChatGPT.app", "Contents", "Resources", "codex"),
        p.join("/Users/dev", "Applications", "Codex.app", "Contents", "Resources", "codex"),
      ]);
    });

    test("macOS omits user Applications without a home directory", () {
      final candidates = codexDesktopAppCliCandidates(
        environment: const {},
        os: PlatformOs.macos,
      );

      expect(candidates, hasLength(2));
      expect(candidates, everyElement(startsWith("/Applications")));
    });

    test("windows probes the stable path and hash subdirectories newest first", () async {
      final localAppData = Directory.systemTemp.createTempSync("codex-locator-test");
      addTearDown(() => localAppData.deleteSync(recursive: true));
      final binDir = Directory(p.join(localAppData.path, "OpenAI", "Codex", "bin"))
        ..createSync(recursive: true);
      final older = Directory(p.join(binDir.path, "aaaa1111"))..createSync();
      // Directory mtimes cannot be set directly from dart:io; a real delay
      // between creations keeps newest-first ordering observable.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final newer = Directory(p.join(binDir.path, "bbbb2222"))..createSync();

      final candidates = codexDesktopAppCliCandidates(
        environment: {"LOCALAPPDATA": localAppData.path},
        os: PlatformOs.windows,
      );

      expect(candidates, [
        p.join(binDir.path, "codex.exe"),
        p.join(newer.path, "codex.exe"),
        p.join(older.path, "codex.exe"),
      ]);
    });

    test("windows yields no candidates without LOCALAPPDATA", () {
      expect(
        codexDesktopAppCliCandidates(environment: const {}, os: PlatformOs.windows),
        isEmpty,
      );
    });

    test("linux has no desktop app", () {
      expect(
        codexDesktopAppCliCandidates(
          environment: const {"HOME": "/home/dev"},
          os: PlatformOs.linux,
        ),
        isEmpty,
      );
    });
  });
}
