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
      expect(manifest.bundledVersion.raw, "1.0.114");
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
              sha256: "35e8165a6ca811fb907b5afb7892e53d1bb85426bb77fe3f83b7f0b4e955249a",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64): (
              assetName: "copilot-darwin-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "9ac9f8785ad036c8d6a976a386fd05d721b510b57f083f1aac0cac9e378051bb",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64): (
              assetName: "copilot-linux-arm64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "a204154d4522a7c3aa73a65ba598e432f6aafe37d5fa31cf853163a27d98018e",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64): (
              assetName: "copilot-linux-x64.tar.gz",
              format: ArchiveFormat.tarGz,
              sha256: "b91a96f2257297cfb67ed6784a2a658609a6b8c2ee2ded18af9c9abe8cc790ae",
              archiveBinaryName: "copilot",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64): (
              assetName: "copilot-win32-arm64.zip",
              format: ArchiveFormat.zip,
              sha256: "8b87093bb46d8d6700482b58ef0039d00e4445bc13755ac49795e79f8cd565a5",
              archiveBinaryName: "copilot.exe",
            ),
            const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64): (
              assetName: "copilot-win32-x64.zip",
              format: ArchiveFormat.zip,
              sha256: "be5af88c044842949560535b083c47e0c2b41904769cca599ee2cbf937dc9eed",
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
        "https://github.com/github/copilot-cli/releases/download/v1.0.114/copilot-darwin-arm64.tar.gz",
      );
    });
  });
}
