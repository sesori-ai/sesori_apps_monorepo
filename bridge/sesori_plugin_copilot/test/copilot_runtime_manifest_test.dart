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
      expect(manifest.bundledVersion.raw, "1.0.115");
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
              sha256: "f0858bbff5e35c4fe92d97a0061cb4a2a12b06defacf5512b77ca294175a12cf",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64): (
              assetName: "copilot-darwin-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "e6fb406eea63683563bb9420d4c1c6c09c53156ccd819b9c45560ddf014a7ee9",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64): (
              assetName: "copilot-linux-arm64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "889b423ce7e0dd41a298b95716d3d8fe80dc30f1fd9cf5419a95b6fb8d4e1bc8",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64): (
              assetName: "copilot-linux-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "e01975bf3a73791b0c0adfdf0d7093b8616186db61b78b33604b124806808816",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64): (
              assetName: "copilot-win32-arm64.zip",
              format: ArchiveFormat.zip,
              sha256: "cc3accfcf3bbce431cf9cd41198aec1e81c11908542825a6031726e6eac215cc",
              archiveBinaryName: "copilot.exe",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64): (
              assetName: "copilot-win32-x64.zip",
              format: ArchiveFormat.zip,
              sha256: "256de3c3b8c00cbe5f738c9830f30b1d790d6693563689baade984295606af2c",
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
        "https://github.com/github/copilot-cli/releases/download/v1.0.115/copilot-darwin-arm64.tar.gz",
      );
    });
  });
}
