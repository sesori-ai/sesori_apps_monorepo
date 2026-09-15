import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop/core/platform/desktop_bridge_executable_path_resolver.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

const DesktopBundleIdentity _identity = DesktopBundleIdentity(
  version: "1.8.4",
  buildNumber: 17,
  sourceSha: "833b989517aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  os: DesktopBundleOs.linux,
  architecture: DesktopBundleArchitecture.arm64,
);

void main() {
  for (final DesktopBundleOs os in DesktopBundleOs.values) {
    for (final DesktopBundleArchitecture architecture in DesktopBundleArchitecture.values) {
      test("$os/$architecture resolves only the installed bundle, ignoring cwd and environment", () {
        final DesktopBundleIdentity expected = _identity.copyWith(os: os, architecture: architecture);
        String? manifestRead;
        final DesktopBridgeExecutablePathResolver resolver = _resolver(
          host: expected,
          compiledIdentity: expected.encode(),
          readManifest: ({required String manifestPath}) {
            manifestRead = manifestPath;
            return expected.encode();
          },
          helperExists: true,
        );
        final String helperRoot = os == DesktopBundleOs.macos
            ? path.absolute("Installed App", "Contents", "Helpers", "bridge")
            : path.absolute("Installed App", "bridge");
        expect(
          resolver.resolve(),
          path.join(helperRoot, "bin", os == DesktopBundleOs.windows ? "bridge.exe" : "bridge"),
        );
        final String manifestDirectory = os == DesktopBundleOs.macos
            ? path.absolute("Installed App", "Contents", "Resources")
            : helperRoot;
        expect(manifestRead, path.join(manifestDirectory, DesktopBundleIdentity.manifestName));
      });
    }
  }

  for (final DesktopBundleIdentity changed in [
    _identity.copyWith(version: "1.8.5"),
    _identity.copyWith(buildNumber: 18),
    _identity.copyWith(sourceSha: "different-source"),
    _identity.copyWith(os: DesktopBundleOs.windows),
    _identity.copyWith(architecture: DesktopBundleArchitecture.x64),
  ]) {
    test("rejects mismatched helper identity: $changed", () {
      final DesktopBridgeExecutablePathResolver resolver = _resolver(
        host: _identity,
        compiledIdentity: _identity.encode(),
        readManifest: ({required String manifestPath}) => changed.encode(),
        helperExists: true,
      );
      expect(resolver.resolve, throwsA(isA<DesktopBridgeBundleException>()));
    });
  }

  for (final DesktopBundleIdentity changed in [
    _identity.copyWith(os: DesktopBundleOs.windows),
    _identity.copyWith(architecture: DesktopBundleArchitecture.x64),
  ]) {
    test("rejects a mutually matching GUI/helper identity on the wrong host: $changed", () {
      final DesktopBridgeExecutablePathResolver resolver = _resolver(
        host: _identity,
        compiledIdentity: changed.encode(),
        readManifest: ({required String manifestPath}) => changed.encode(),
        helperExists: true,
      );
      expect(resolver.resolve, throwsA(isA<DesktopBridgeBundleException>()));
    });
  }

  test("re-reads the manifest before the next spawn after Linux package replacement", () {
    DesktopBundleIdentity onDisk = _identity;
    final DesktopBridgeExecutablePathResolver resolver = _resolver(
      host: _identity,
      compiledIdentity: _identity.encode(),
      readManifest: ({required String manifestPath}) => onDisk.encode(),
      helperExists: true,
    );
    expect(resolver.resolve(), endsWith(path.join("bridge", "bin", "bridge")));
    onDisk = _identity.copyWith(buildNumber: 18);
    expect(
      resolver.resolve,
      throwsA(
        isA<DesktopBridgeBundleException>().having((e) => e.toString(), "repair advice", contains("Restart Sesori")),
      ),
    );
  });

  test("missing build metadata cannot fall back to a development override", () {
    final DesktopBridgeExecutablePathResolver resolver = _resolver(
      host: _identity,
      compiledIdentity: null,
      readManifest: ({required String manifestPath}) => _identity.encode(),
      helperExists: true,
    );
    expect(resolver.resolve, throwsA(isA<DesktopBridgeBundleException>()));
  });

  test("missing manifest retains the original I/O error", () {
    const FileSystemException original = FileSystemException("Missing manifest", "installed/desktop-bundle.json");
    final DesktopBridgeExecutablePathResolver resolver = _resolver(
      host: _identity,
      compiledIdentity: _identity.encode(),
      readManifest: ({required String manifestPath}) => throw original,
      helperExists: true,
    );
    expect(
      resolver.resolve,
      throwsA(isA<DesktopBridgeBundleException>().having((e) => e.innerError, "cause", same(original))),
    );
  });

  test("malformed JSON is retained without rendering its contents", () {
    final DesktopBridgeExecutablePathResolver resolver = _resolver(
      host: _identity,
      compiledIdentity: _identity.encode(),
      readManifest: ({required String manifestPath}) => "not JSON: private contents",
      helperExists: true,
    );
    expect(
      resolver.resolve,
      throwsA(
        isA<DesktopBridgeBundleException>()
            .having((e) => e.innerError, "cause", isA<FormatException>())
            .having((e) => e.toString(), "local diagnostic", isNot(contains("private contents")))
            .having(
              (e) => e.userMessage,
              "safe repair guidance",
              allOf(
                contains("Restart Sesori"),
                contains("reinstall the matching desktop download"),
                isNot(contains("private contents")),
                isNot(contains("Installed App")),
              ),
            ),
      ),
    );
  });

  test("matching metadata does not hide a missing executable", () {
    final DesktopBridgeExecutablePathResolver resolver = _resolver(
      host: _identity,
      compiledIdentity: _identity.encode(),
      readManifest: ({required String manifestPath}) => _identity.encode(),
      helperExists: false,
    );
    expect(resolver.resolve, throwsA(isA<DesktopBridgeBundleException>()));
  });
}

DesktopBridgeExecutablePathResolver _resolver({
  required DesktopBundleIdentity host,
  required String? compiledIdentity,
  required DesktopBridgeManifestReader readManifest,
  required bool helperExists,
}) => DesktopBridgeExecutablePathResolver.forTesting(
  environment: const {DesktopBridgeExecutablePathResolver.environmentVariable: "/arbitrary/development/bridge"},
  workingDirectory: path.absolute("different repo", "client", "desktop"),
  resolvedExecutable: host.os == DesktopBundleOs.macos
      ? path.absolute("Installed App", "Contents", "MacOS", "Sesori")
      : path.absolute("Installed App", "sesori_desktop${host.os == DesktopBundleOs.windows ? '.exe' : ''}"),
  os: host.os,
  architecture: host.architecture,
  isReleaseMode: true,
  compiledIdentityJson: compiledIdentity,
  executableExists: ({required String executablePath}) => helperExists,
  readManifest: readManifest,
);
