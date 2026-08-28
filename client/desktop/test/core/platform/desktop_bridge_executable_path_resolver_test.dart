import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop/core/platform/desktop_bridge_executable_path_resolver.dart";

void main() {
  group("DesktopBridgeExecutablePathResolver", () {
    test("uses an explicit absolute path", () {
      final String configuredPath = path.absolute(path.join("opt", "sesori", "bridge"));
      final DesktopBridgeExecutablePathResolver resolver = DesktopBridgeExecutablePathResolver.forTesting(
        environment: {DesktopBridgeExecutablePathResolver.environmentVariable: configuredPath},
        workingDirectory: path.absolute(path.join("repo", "client", "desktop")),
        isWindows: false,
      );

      expect(resolver.resolve(), configuredPath);
    });

    test("resolves an explicit relative path from the launch directory", () {
      final String workingDirectory = path.absolute(path.join("repo", "client", "desktop"));
      final DesktopBridgeExecutablePathResolver resolver = DesktopBridgeExecutablePathResolver.forTesting(
        environment: const {DesktopBridgeExecutablePathResolver.environmentVariable: "tools/bridge"},
        workingDirectory: workingDirectory,
        isWindows: false,
      );

      expect(resolver.resolve(), path.join(workingDirectory, "tools", "bridge"));
    });

    test("defaults to the repository host bundle", () {
      final String workingDirectory = path.absolute(path.join("repo", "client", "desktop"));
      final DesktopBridgeExecutablePathResolver resolver = DesktopBridgeExecutablePathResolver.forTesting(
        environment: const {},
        workingDirectory: workingDirectory,
        isWindows: false,
      );

      expect(
        resolver.resolve(),
        path.normalize(
          path.join(workingDirectory, "..", "..", "bridge", "app", "build", "cli", "bundle", "bin", "bridge"),
        ),
      );
    });

    test("uses the Windows executable name", () {
      final String workingDirectory = path.absolute(path.join("repo", "client", "desktop"));
      final DesktopBridgeExecutablePathResolver resolver = DesktopBridgeExecutablePathResolver.forTesting(
        environment: const {},
        workingDirectory: workingDirectory,
        isWindows: true,
      );

      expect(path.basename(resolver.resolve()), "bridge.exe");
    });
  });
}
