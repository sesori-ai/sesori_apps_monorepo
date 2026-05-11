import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge/src/server/codex_binary_resolver.dart";
import "package:test/test.dart";

void main() {
  group("CodexBinaryResolver", () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("codex-resolver-test-");
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort.
      }
    });

    test("uses --codex-bin path when the file exists", () async {
      final binary = File(p.join(tempDir.path, "fake-codex"))
        ..createSync(recursive: true);
      final resolver = CodexBinaryResolver(
        codexBinFlag: binary.path,
        environment: {"HOME": tempDir.path},
      );
      expect(await resolver.resolve(), equals(binary.absolute.path));
    });

    test(
      "returns --codex-bin verbatim when it's a non-default value and the file is missing",
      () async {
        // Design intent: a user who passes an explicit path means it.
        // We surface their path so Process.start fails with a clear error
        // rather than silently swapping in PATH `codex`.
        final missing = p.join(tempDir.path, "does-not-exist");
        final resolver = CodexBinaryResolver(
          codexBinFlag: missing,
          environment: {"HOME": tempDir.path},
        );
        expect(await resolver.resolve(), equals(missing));
      },
    );

    test("uses cached binary when present and flag is the default", () async {
      final binName = Platform.isWindows ? "codex.exe" : "codex";
      final cachePath = p.join(
        tempDir.path,
        ".local",
        "share",
        "sesori",
        "codex",
        pinnedCodexVersion,
        binName,
      );
      File(cachePath)
        ..createSync(recursive: true)
        ..writeAsStringSync("stub");

      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex",
        environment: {"HOME": tempDir.path},
      );
      expect(await resolver.resolve(), equals(cachePath));
    });

    test(
      "falls back to PATH when no override, no cache, and SHA-256 manifest is empty",
      () async {
        final resolver = CodexBinaryResolver(
          codexBinFlag: "codex",
          environment: {"HOME": tempDir.path},
        );
        // Default manifest ships with empty hashes → no auto-download → PATH.
        expect(await resolver.resolve(), equals("codex"));
      },
    );

    test("XDG_DATA_HOME overrides ~/.local/share for cache lookup", () async {
      final xdg = Directory(p.join(tempDir.path, "xdg"))..createSync();
      final binName = Platform.isWindows ? "codex.exe" : "codex";
      final cachePath = p.join(
        xdg.path,
        "sesori",
        "codex",
        pinnedCodexVersion,
        binName,
      );
      File(cachePath)
        ..createSync(recursive: true)
        ..writeAsStringSync("stub");

      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex",
        environment: {"HOME": tempDir.path, "XDG_DATA_HOME": xdg.path},
      );
      expect(await resolver.resolve(), equals(cachePath));
    });
  });
}
