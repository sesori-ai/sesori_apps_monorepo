import "package:opencode_plugin/src/runtime/open_code_runtime_manifest.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = OpenCodeRuntimeManifest();

  group("OpenCodeRuntimeManifest", () {
    test("pins a sha256 asset for every supported platform target", () {
      for (final os in PlatformOs.values) {
        for (final arch in PlatformArch.values) {
          final asset = manifest.assetFor(target: PlatformTarget(os: os, arch: arch));
          expect(asset, isNotNull, reason: "missing asset for $os/$arch");
          expect(asset!.sha256, matches(RegExp(r"^[0-9a-f]{64}$")), reason: "$os/$arch sha256");
          expect(asset.assetName, isNotEmpty);
        }
      }
    });

    test("darwin/windows ship .zip, linux ships .tar.gz", () {
      RuntimeAsset asset(PlatformOs os, PlatformArch arch) =>
          manifest.assetFor(target: PlatformTarget(os: os, arch: arch))!;

      expect(asset(PlatformOs.macos, PlatformArch.arm64).format, ArchiveFormat.zip);
      expect(asset(PlatformOs.macos, PlatformArch.arm64).assetName, endsWith(".zip"));
      expect(asset(PlatformOs.windows, PlatformArch.x64).format, ArchiveFormat.zip);
      expect(asset(PlatformOs.windows, PlatformArch.x64).assetName, endsWith(".zip"));
      expect(asset(PlatformOs.linux, PlatformArch.x64).format, ArchiveFormat.tarGz);
      expect(asset(PlatformOs.linux, PlatformArch.x64).assetName, endsWith(".tar.gz"));
    });

    test("download URL embeds the bundled version and asset name", () {
      final asset = manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
      )!;
      expect(
        manifest.downloadUrlFor(asset: asset),
        equals("https://github.com/anomalyco/opencode/releases/download/v1.17.9/opencode-darwin-arm64.zip"),
      );
    });

    test("bundled version is at least the minimum supported version", () {
      expect(
        manifest.bundledVersion.compareTo(manifest.minPathVersion),
        greaterThanOrEqualTo(0),
      );
    });
  });
}
