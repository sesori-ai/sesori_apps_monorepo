import "package:copilot_plugin/copilot_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  group("CopilotRuntimeManifest", () {
    const manifest = CopilotRuntimeManifest();

    test("pins the validated ACP floor and managed target", () {
      expect(manifest.runtimeId, "copilot");
      expect(manifest.minPathVersion.raw, "1.0.78");
      expect(manifest.bundledVersion.raw, CopilotRuntimeManifest.targetVersion);
      expect(manifest.bundledVersion.raw, "1.0.117");
    });

    test("probes the version with auto-update off, as the session launches", () {
      expect(manifest.versionProbeArguments, ["--no-auto-update", "--version"]);
    });

    test("pins all six official single-binary release archives", () {
      final expected =
          <PlatformTarget, ({String assetName, ArchiveFormat format, String sha256, String archiveBinaryName})>{
            const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64): (
              assetName: "copilot-darwin-arm64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "081e8b48ef046c7a1d1c1f3178fa0260998c2848fa720b600a27f24840e4f8bc",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64): (
              assetName: "copilot-darwin-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "fc3827dfc74229c6045e12cca2f517db0b1ab11d05c3a9c7d5195a3c39fa67c8",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64): (
              assetName: "copilot-linux-arm64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "24591c89a6a155f26e97bd081ea20f55c12e8a423eaad01386e7c49a80990846",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64): (
              assetName: "copilot-linux-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "d12052d8cb42c0ee4345fb625d3d65dfc6e19f65277e2a4827ee10723adce8aa",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64): (
              assetName: "copilot-win32-arm64.zip",
              format: ArchiveFormat.zip,
              sha256: "33087f22d548321a5e0682fdf4daa6a872ad9dcedb00d7f22c004d9033e21039",
              archiveBinaryName: "copilot.exe",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64): (
              assetName: "copilot-win32-x64.zip",
              format: ArchiveFormat.zip,
              sha256: "57a7101fb6d7e3fc43b34f35c58a527c2a42762fb493a75630a17a47c3f115e7",
              archiveBinaryName: "copilot.exe",
            ),
          };

      for (final entry in expected.entries) {
        final asset = manifest.assetFor(target: entry.key);
        expect(asset, isA<ArchiveRuntimeAsset>(), reason: entry.key.key);
        if (asset is! ArchiveRuntimeAsset) continue;
        expect(asset.assetName, entry.value.assetName);
        expect(asset.format, entry.value.format);
        expect(asset.sha256, entry.value.sha256);
        expect(asset.archiveBinaryName, entry.value.archiveBinaryName);
        expect(asset.layout, RuntimeArchiveLayout.singleBinary);
      }
    });

    test("builds the official pinned release URL", () {
      final asset = manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
      );
      if (asset == null) fail("missing macOS arm64 asset");
      expect(
        manifest.downloadUrlFor(asset: asset),
        "https://github.com/github/copilot-cli/releases/download/v1.0.117/copilot-darwin-arm64.tar.gz",
      );
    });
  });
}
