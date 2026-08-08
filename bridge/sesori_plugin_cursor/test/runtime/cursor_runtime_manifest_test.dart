import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = CursorRuntimeManifest();

  test("pins the published build and its compatibility floor", () {
    expect(manifest.runtimeId, "cursor");
    expect(manifest.pathExecutableName, "cursor-agent");
    expect(manifest.binaryFileName, "cursor-agent");
    expect(manifest.bundledVersion.toString(), "2026.8.4-aaa8809");
    expect(manifest.minPathVersion.toString(), "2026.7.16");
  });

  test("publishes darwin and linux packages but not windows", () {
    for (final os in [PlatformOs.macos, PlatformOs.linux]) {
      for (final arch in [PlatformArch.arm64, PlatformArch.x64]) {
        final asset = manifest.assetFor(target: PlatformTarget(os: os, arch: arch));
        expect(asset, isNotNull, reason: "$os/$arch must be published");
        expect(asset!.layout, RuntimeAssetLayout.packageDirectory);
        expect(asset.format, ArchiveFormat.tarGz);
        expect(asset.archiveBinaryName, "cursor-agent");
        expect(asset.sha256, matches(RegExp(r"^[0-9a-f]{64}$")));
      }
    }
    for (final arch in [PlatformArch.arm64, PlatformArch.x64]) {
      expect(
        manifest.assetFor(target: PlatformTarget(os: PlatformOs.windows, arch: arch)),
        isNull,
        reason: "Cursor publishes no Windows package",
      );
    }
  });

  test("every published platform has a distinct checksum", () {
    final digests = {
      for (final os in [PlatformOs.macos, PlatformOs.linux])
        for (final arch in [PlatformArch.arm64, PlatformArch.x64])
          manifest.assetFor(target: PlatformTarget(os: os, arch: arch))!.sha256,
    };

    expect(digests, hasLength(4));
  });

  test("download URLs use the raw published build, not the normalized version", () {
    final asset = manifest.assetFor(
      target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
    )!;

    // SemanticVersion drops the leading zeros (2026.08.04 -> 2026.8.4), which
    // would 404; the URL must carry Cursor's exact build string.
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://downloads.cursor.com/lab/2026.08.04-aaa8809/darwin/arm64/agent-cli-package.tar.gz",
    );
    expect(manifest.downloadUrlFor(asset: asset), isNot(contains("2026.8.4")));
  });

  test("managed binaries live under a version-scoped directory", () {
    expect(
      manifest.managedBinaryPath(stateDirectory: "/state"),
      "/state/cursor/2026.8.4-aaa8809/cursor-agent",
    );
  });
}
