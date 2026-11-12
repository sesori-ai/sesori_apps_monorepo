import "dart:io";

import "package:path/path.dart" as p;
import "package:test/test.dart";

void main() {
  final fixture = File("test/fixtures/browser_invocation.dart").absolute.path;
  final packageConfig = File("../.dart_tool/package_config.json").absolute.path;

  for (final explicitPackages in [false, true]) {
    test("descriptor source browser helper works with explicit packages: $explicitPackages", () async {
      final result = await Process.run(Platform.resolvedExecutable, [
        if (explicitPackages) "--packages=$packageConfig",
        fixture,
        explicitPackages ? "explicit" : "implicit",
      ]).timeout(const Duration(seconds: 60));
      expect(result.exitCode, 0, reason: "${result.stdout}\n${result.stderr}");
      expect(result.stdout, isEmpty);
      expect(result.stderr, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 75)));
  }

  test("descriptor native browser helper works through absolute and PATH launches", () async {
    final output = await Directory.systemTemp.createTemp("antigravity-native-browser-");
    addTearDown(() => output.delete(recursive: true));
    final binary = p.join(output.path, Platform.isWindows ? "browser-fixture.exe" : "browser-fixture");
    final compiled = await Process.run(Platform.resolvedExecutable, [
      "compile",
      "exe",
      fixture,
      "-o",
      binary,
    ]).timeout(const Duration(minutes: 2));
    expect(compiled.exitCode, 0, reason: "${compiled.stdout}\n${compiled.stderr}");

    // The PATH launch goes through /bin/sh: Dart 3.14 on macOS resolves a bare
    // command against the parent's PATH, not the one supplied to the child.
    for (final (executable, arguments) in [
      (binary, ["implicit"]),
      if (!Platform.isWindows) ("/bin/sh", ["-c", r'exec "$0" "$@"', p.basename(binary), "implicit"]),
    ]) {
      final result = await Process.run(
        executable,
        arguments,
        environment: {"PATH": output.path},
      ).timeout(const Duration(seconds: 30));
      expect(result.exitCode, 0, reason: "${result.stdout}\n${result.stderr}");
      expect(result.stdout, isEmpty);
      expect(result.stderr, isEmpty);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
