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
      expect(manifest.bundledVersion.raw, "1.0.109");
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
              sha256: "9c21ad663ce98f500c1f0b62e0a6d687bc1b1661e59f4c2161cc114515a01942",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64): (
              assetName: "copilot-darwin-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "ce73d75d599718a7ade68a3b78d2ba84cc1c2a77e01cc4483b03579ff592199d",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64): (
              assetName: "copilot-linux-arm64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "679db06c3168457d8154cd8ce93b822f7c46d3169e61da4c0b78ac6e110c4af6",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64): (
              assetName: "copilot-linux-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "45a7f37e822e8c8725eda6b27deaed55dad2688ff4163ed27ec22e23293cb761",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64): (
              assetName: "copilot-win32-arm64.zip",
              format: ArchiveFormat.zip,
              sha256: "7e5bfc92c5b607491710ff1352079c362270fbe23a8d5d7868a6fc6a10b4040d",
              archiveBinaryName: "copilot.exe",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64): (
              assetName: "copilot-win32-x64.zip",
              format: ArchiveFormat.zip,
              sha256: "794c16bcc5535cdf478598d6cf4af3228daec3b7801bfa3540c56b8d3524beee",
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
        "https://github.com/github/copilot-cli/releases/download/v1.0.109/copilot-darwin-arm64.tar.gz",
      );
    });
  });
}
