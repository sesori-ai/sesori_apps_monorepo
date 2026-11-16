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
      expect(manifest.bundledVersion.raw, "1.0.112");
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
              sha256: "4a4a6aa624dceb76a23e1a53fb5f64e87a0bb5a2161a5017e0edf78d7082ce68",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64): (
              assetName: "copilot-darwin-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "fda4b6661269589b15447c9c6ebde96939a4cd32d08d6595a9dad6e92d1e83f5",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64): (
              assetName: "copilot-linux-arm64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "491d18303505935675dc20987ef0c5f3ae899f81e66c53d567ad97a8b03e504e",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64): (
              assetName: "copilot-linux-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "dfe7e59acf04f0b7f59b024ea9db101a9246503e9bf7152eb668fbb2a469b151",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64): (
              assetName: "copilot-win32-arm64.zip",
              format: ArchiveFormat.zip,
              sha256: "ddbfa7145274ad568d831bab12959e2577dff558476d0bec79d3a53a171d4362",
              archiveBinaryName: "copilot.exe",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64): (
              assetName: "copilot-win32-x64.zip",
              format: ArchiveFormat.zip,
              sha256: "159a5e610c7b64c4b68b97a812fd7913182f372cb84ce688d81167d5277896d9",
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
        "https://github.com/github/copilot-cli/releases/download/v1.0.112/copilot-darwin-arm64.tar.gz",
      );
    });
  });
}
