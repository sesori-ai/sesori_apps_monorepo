import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

/// A real [CommandExecutor] backed by [Process.run], used so the extractor's
/// security hardening is exercised against the actual `tar`/`unzip` binaries.
class _RealCommandExecutor implements CommandExecutor {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    final ProcessResult result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }
}

void main() {
  late Directory tempDir;
  late String payloadDir;
  late String stagingPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp("archive-extractor");
    payloadDir = p.join(tempDir.path, "payload");
    stagingPath = p.join(tempDir.path, "staging");
    Directory(payloadDir).createSync(recursive: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void writeFile(String relative, String contents) {
    final file = File(p.join(payloadDir, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  ArchiveExtractor extractor() => ArchiveExtractor(commandExecutor: _RealCommandExecutor());

  group("tarGz", () {
    Future<String> tarPayload() async {
      final archive = p.join(tempDir.path, "payload.tar.gz");
      final result = await Process.run("tar", ["-czf", archive, "-C", payloadDir, "."]);
      expect(result.exitCode, 0, reason: "tar failed: ${result.stderr}");
      return archive;
    }

    test("extracts a regular-file payload", () async {
      if (Platform.isWindows) return; // uses POSIX tar
      writeFile(p.join("bin", "sesori-bridge"), "BIN");
      writeFile(p.join("lib", "a.dll"), "A");
      final archive = await tarPayload();

      final ok = await extractor().extract(
        archivePath: archive,
        stagingPath: stagingPath,
        format: ArchiveFormat.tarGz,
      );

      expect(ok, isTrue);
      expect(File(p.join(stagingPath, "bin", "sesori-bridge")).readAsStringSync(), "BIN");
      expect(File(p.join(stagingPath, "lib", "a.dll")).readAsStringSync(), "A");
    });

    test("rejects a payload containing a symlink and cleans staging", () async {
      if (Platform.isWindows) return; // uses POSIX tar + symlinks
      writeFile(p.join("lib", "real.dll"), "REAL");
      // A symlink that escapes the install root — the concrete attack vector.
      Link(p.join(payloadDir, "lib", "evil")).createSync("/etc/passwd");
      final archive = await tarPayload();

      final ok = await extractor().extract(
        archivePath: archive,
        stagingPath: stagingPath,
        format: ArchiveFormat.tarGz,
      );

      expect(ok, isFalse);
      // Fail-closed: nothing is left staged for the placement step.
      expect(Directory(stagingPath).existsSync(), isFalse);
    });
  });

  group("zip (posix)", () {
    test("extracts a regular-file payload", () async {
      if (Platform.isWindows) return; // posix unzip path
      writeFile(p.join("bin", "opencode"), "BIN");
      writeFile(p.join("lib", "a.txt"), "A");

      final archive = p.join(tempDir.path, "payload.zip");
      final ProcessResult zipResult;
      try {
        zipResult = await Process.run("zip", ["-r", "-q", archive, "."], workingDirectory: payloadDir);
      } on ProcessException {
        markTestSkipped("`zip` is not available on this host");
        return;
      }
      expect(zipResult.exitCode, 0, reason: "zip failed: ${zipResult.stderr}");

      final ok = await extractor().extract(
        archivePath: archive,
        stagingPath: stagingPath,
        format: ArchiveFormat.zip,
      );

      expect(ok, isTrue);
      expect(File(p.join(stagingPath, "bin", "opencode")).readAsStringSync(), "BIN");
      expect(File(p.join(stagingPath, "lib", "a.txt")).readAsStringSync(), "A");
    });
  });
}
