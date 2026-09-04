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
        resolvedExecutable: path.absolute(path.join("repo", "client", "desktop", "build", "Sesori")),
        isWindows: false,
      );

      expect(resolver.resolve(), configuredPath);
    });

    test("resolves an explicit relative path from the launch directory", () {
      final String workingDirectory = path.absolute(path.join("repo", "client", "desktop"));
      final DesktopBridgeExecutablePathResolver resolver = DesktopBridgeExecutablePathResolver.forTesting(
        environment: const {DesktopBridgeExecutablePathResolver.environmentVariable: "tools/bridge"},
        workingDirectory: workingDirectory,
        resolvedExecutable: path.join(workingDirectory, "build", "Sesori"),
        isWindows: false,
      );

      expect(resolver.resolve(), path.join(workingDirectory, "tools", "bridge"));
    });

    test("defaults to the repository host bundle", () {
      final String workingDirectory = path.absolute(path.join("repo", "client", "desktop"));
      final DesktopBridgeExecutablePathResolver resolver = DesktopBridgeExecutablePathResolver.forTesting(
        environment: const {},
        workingDirectory: workingDirectory,
        resolvedExecutable: path.join(workingDirectory, "build", "Sesori"),
        isWindows: false,
      );

      expect(
        resolver.resolve(),
        path.normalize(
          path.join(workingDirectory, "..", "..", "bridge", "app", "build", "cli", "bundle", "bin", "bridge"),
        ),
      );
    });

    test("resolves the repository from the executable when launchd changes the working directory", () {
      final String repositoryRoot = path.absolute("repo");
      final DesktopBridgeExecutablePathResolver resolver = DesktopBridgeExecutablePathResolver.forTesting(
        environment: const {},
        workingDirectory: path.rootPrefix(repositoryRoot),
        resolvedExecutable: path.join(
          repositoryRoot,
          "client",
          "desktop",
          "build",
          "macos",
          "Build",
          "Products",
          "Release",
          "Sesori.app",
          "Contents",
          "MacOS",
          "Sesori",
        ),
        isWindows: false,
      );

      expect(
        resolver.resolve(),
        path.normalize(
          path.join(repositoryRoot, "bridge", "app", "build", "cli", "bundle", "bin", "bridge"),
        ),
      );
    });

    test("falls back to the launch directory outside the repository", () {
      final String root = path.rootPrefix(path.absolute("repo"));
      final String workingDirectory = path.join(root, "tmp", "sesori-desktop");
      final DesktopBridgeExecutablePathResolver resolver = DesktopBridgeExecutablePathResolver.forTesting(
        environment: const {},
        workingDirectory: workingDirectory,
        resolvedExecutable: path.join(root, "Applications", "Sesori.app", "Contents", "MacOS", "Sesori"),
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
        resolvedExecutable: path.join(workingDirectory, "build", "Sesori.exe"),
        isWindows: true,
      );

      expect(path.basename(resolver.resolve()), "bridge.exe");
    });
  });
}
