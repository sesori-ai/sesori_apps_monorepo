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

    for (final executable in [binary, if (!Platform.isWindows) p.basename(binary)]) {
      final result = await Process.run(
        executable,
        ["implicit"],
        environment: {"PATH": output.path},
      ).timeout(const Duration(seconds: 30));
      expect(result.exitCode, 0, reason: "${result.stdout}\n${result.stderr}");
      expect(result.stdout, isEmpty);
      expect(result.stderr, isEmpty);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
