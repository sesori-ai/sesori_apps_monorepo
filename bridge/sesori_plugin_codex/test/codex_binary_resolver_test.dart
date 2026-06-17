import "dart:convert";
import "dart:io";

import "package:codex_plugin/src/codex_binary_resolver.dart";
import "package:crypto/crypto.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

String _cachedBinName() => Platform.isWindows ? "codex.exe" : "codex";

String _cachedPath(String home) =>
    p.join(home, ".local", "share", "sesori", "codex", pinnedCodexVersion, _cachedBinName());

void main() {
  group("release manifest data", () {
    test("pins codex 0.139.0", () {
      expect(pinnedCodexVersion, equals("0.139.0"));
    });

    test("every platform has a 64-char lowercase-hex sha and an asset", () {
      expect(codexSha256Manifest.keys.toSet(), equals(codexAssetFor.keys.toSet()));
      final hex = RegExp(r"^[0-9a-f]{64}$");
      for (final entry in codexSha256Manifest.entries) {
        expect(entry.value, matches(hex), reason: "sha for ${entry.key}");
      }
    });

    test("asset filenames match the rust-v0.139.0 release shapes", () {
      expect(codexAssetFor["darwin-arm64"], equals("codex-aarch64-apple-darwin.tar.gz"));
      expect(codexAssetFor["darwin-x64"], equals("codex-x86_64-apple-darwin.tar.gz"));
      expect(codexAssetFor["linux-x64"], equals("codex-x86_64-unknown-linux-musl.tar.gz"));
      expect(codexAssetFor["linux-arm64"], equals("codex-aarch64-unknown-linux-musl.tar.gz"));
      // 0.139.0 ships the Windows binary as an `.exe.zip` (member is the .exe).
      expect(codexAssetFor["windows-x64"], equals("codex-x86_64-pc-windows-msvc.exe.zip"));
    });
  });

  group("codexBinaryNameInArchive", () {
    test("strips .tar.gz to the target-triple binary name", () {
      expect(
        codexBinaryNameInArchive("codex-aarch64-apple-darwin.tar.gz"),
        equals("codex-aarch64-apple-darwin"),
      );
    });

    test("strips .zip, keeping the inner .exe for Windows", () {
      expect(
        codexBinaryNameInArchive("codex-x86_64-pc-windows-msvc.exe.zip"),
        equals("codex-x86_64-pc-windows-msvc.exe"),
      );
    });
  });

  group("CodexBinaryResolver.resolve", () {
    late Directory home;

    setUp(() => home = Directory.systemTemp.createTempSync("codex-resolver-"));
    tearDown(() {
      try {
        home.deleteSync(recursive: true);
      } catch (_) {}
    });

    test("an existing --codex-bin override wins outright", () async {
      final override = File(p.join(home.path, "my-codex"))..writeAsStringSync("#!/bin/sh\n");
      final resolver = CodexBinaryResolver(
        codexBinFlag: override.path,
        environment: {"HOME": home.path},
        httpClient: MockClient((_) async => fail("must not download with an override")),
      );
      expect(await resolver.resolve(), equals(override.absolute.path));
    });

    test("uses the cached managed binary before downloading", () async {
      final cached = File(_cachedPath(home.path))..parent.createSync(recursive: true);
      cached.writeAsStringSync("#!/bin/sh\n");
      // A properly-cached binary carries the execute bit; the resolver now
      // rejects a present-but-non-executable cache and re-downloads.
      if (!Platform.isWindows) {
        Process.runSync("chmod", ["+x", cached.path]);
      }
      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex",
        environment: {"HOME": home.path},
        httpClient: MockClient((_) async => fail("must not download when cached")),
      );
      expect(await resolver.resolve(), equals(cached.path));
    });

    test("downloads, verifies the sha, and normalizes the triple-named binary", () async {
      final env = {"HOME": home.path};
      final key = currentCodexPlatformKey(environment: env);
      if (key == null) {
        markTestSkipped("unsupported host platform");
        return;
      }
      final asset = codexAssetFor[key]!;
      final innerName = codexBinaryNameInArchive(asset);

      final archiveBytes = utf8.encode("fake-codex-archive-bytes");
      final expectedSha = sha256.convert(archiveBytes).toString();

      var extracted = false;
      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex",
        environment: env,
        sha256Manifest: {key: expectedSha},
        httpClient: MockClient((_) async => http.Response.bytes(archiveBytes, 200)),
        extractor: (archivePath, destDir) async {
          extracted = true;
          // Simulate the real archive: it unpacks to a triple-named binary.
          File(p.join(destDir, innerName)).writeAsStringSync("#!/bin/sh\necho codex\n");
        },
      );

      final resolved = await resolver.resolve();
      final dest = _cachedPath(home.path);
      expect(extracted, isTrue);
      expect(resolved, equals(dest));
      expect(File(dest).existsSync(), isTrue, reason: "binary normalized to canonical name");
      expect(
        File(p.join(p.dirname(dest), innerName)).existsSync(),
        isFalse,
        reason: "triple-named binary was renamed away",
      );
    });

    test("a sha mismatch refuses the download and falls back to PATH", () async {
      final env = {"HOME": home.path};
      final key = currentCodexPlatformKey(environment: env);
      if (key == null) {
        markTestSkipped("unsupported host platform");
        return;
      }
      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex-on-path",
        environment: env,
        sha256Manifest: {key: "0" * 64}, // never matches real bytes
        httpClient: MockClient((_) async => http.Response.bytes(utf8.encode("x"), 200)),
        extractor: (_, __) async => fail("must not extract on a sha mismatch"),
      );
      expect(await resolver.resolve(), equals("codex-on-path"));
    });

    test("an empty manifest hash skips download and falls back to PATH", () async {
      final env = {"HOME": home.path};
      final key = currentCodexPlatformKey(environment: env);
      if (key == null) {
        markTestSkipped("unsupported host platform");
        return;
      }
      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex",
        environment: env,
        sha256Manifest: {key: ""},
        httpClient: MockClient((_) async => fail("must not download with an empty hash")),
      );
      expect(await resolver.resolve(), equals("codex"));
    });
  });

  group("CodexBinaryResolver.willDownloadManagedBinary", () {
    late Directory home;

    setUp(() => home = Directory.systemTemp.createTempSync("codex-probe-"));
    tearDown(() {
      try {
        home.deleteSync(recursive: true);
      } catch (_) {}
    });

    test("true when codex is absent but the managed binary is downloadable", () async {
      final env = {"HOME": home.path};
      final key = currentCodexPlatformKey(environment: env);
      if (key == null) {
        markTestSkipped("unsupported host platform");
        return;
      }
      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex",
        environment: env,
        sha256Manifest: {key: "a" * 64},
        httpClient: MockClient((_) async => fail("probe must not download")),
      );
      // Regression guard: a read-only availability probe must report a fresh
      // install (codex absent on PATH, but downloadable) as available so
      // startup is not blocked before resolve() can fetch the binary.
      expect(await resolver.willDownloadManagedBinary(), isTrue);
    });

    test("false when a usable cached binary already exists", () async {
      final env = {"HOME": home.path};
      final key = currentCodexPlatformKey(environment: env);
      if (key == null) {
        markTestSkipped("unsupported host platform");
        return;
      }
      final cached = File(_cachedPath(home.path))..parent.createSync(recursive: true);
      cached.writeAsStringSync("#!/bin/sh\n");
      if (!Platform.isWindows) {
        Process.runSync("chmod", ["+x", cached.path]);
      }
      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex",
        environment: env,
        sha256Manifest: {key: "a" * 64},
        httpClient: MockClient((_) async => fail("no network")),
      );
      expect(await resolver.willDownloadManagedBinary(), isFalse);
    });

    test("false when an existing --codex-bin override is set", () async {
      final env = {"HOME": home.path};
      final key = currentCodexPlatformKey(environment: env);
      if (key == null) {
        markTestSkipped("unsupported host platform");
        return;
      }
      final override = File(p.join(home.path, "my-codex"))..writeAsStringSync("#!/bin/sh\n");
      final resolver = CodexBinaryResolver(
        codexBinFlag: override.path,
        environment: env,
        sha256Manifest: {key: "a" * 64},
        httpClient: MockClient((_) async => fail("no network")),
      );
      expect(await resolver.willDownloadManagedBinary(), isFalse);
    });

    test("false when no checksummed asset exists for the platform", () async {
      final env = {"HOME": home.path};
      final key = currentCodexPlatformKey(environment: env);
      if (key == null) {
        markTestSkipped("unsupported host platform");
        return;
      }
      final resolver = CodexBinaryResolver(
        codexBinFlag: "codex",
        environment: env,
        sha256Manifest: const {},
        httpClient: MockClient((_) async => fail("no network")),
      );
      expect(await resolver.willDownloadManagedBinary(), isFalse);
    });
  });
}
