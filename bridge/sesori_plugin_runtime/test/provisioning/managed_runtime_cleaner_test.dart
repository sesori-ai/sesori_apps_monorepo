import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("ManagedRuntimeCleaner.sweep", () {
    late Directory managedDir;

    setUp(() async {
      managedDir = await Directory.systemTemp.createTemp("runtime-cleaner");
    });

    tearDown(() async {
      if (managedDir.existsSync()) {
        await managedDir.delete(recursive: true);
      }
    });

    void makeVersionDir(String version) {
      final dir = Directory(p.join(managedDir.path, version))..createSync(recursive: true);
      File(p.join(dir.path, "opencode")).writeAsStringSync("binary");
    }

    test("removes superseded version dirs and keeps the kept one", () async {
      makeVersionDir("0.9.0");
      makeVersionDir("1.0.0");
      makeVersionDir("1.17.9");

      await ManagedRuntimeCleaner(runtimeId: "opencode").sweep(managedDir: managedDir.path, keepVersion: "1.17.9");

      expect(Directory(p.join(managedDir.path, "1.17.9")).existsSync(), isTrue);
      expect(Directory(p.join(managedDir.path, "1.0.0")).existsSync(), isFalse);
      expect(Directory(p.join(managedDir.path, "0.9.0")).existsSync(), isFalse);
    });

    test("leaves stray files alone, only sweeps directories", () async {
      makeVersionDir("1.17.9");
      File(p.join(managedDir.path, ".sesori-runtime-download")).writeAsStringSync("partial");

      await ManagedRuntimeCleaner(runtimeId: "opencode").sweep(managedDir: managedDir.path, keepVersion: "1.17.9");

      expect(File(p.join(managedDir.path, ".sesori-runtime-download")).existsSync(), isTrue);
    });

    test("is a no-op when the managed dir does not exist", () async {
      final missing = p.join(managedDir.path, "does-not-exist");
      await ManagedRuntimeCleaner(runtimeId: "opencode").sweep(managedDir: missing, keepVersion: "1.17.9");
      // No throw is the assertion.
      expect(Directory(missing).existsSync(), isFalse);
    });
  });
}
