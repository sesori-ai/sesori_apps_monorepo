import "package:opencode_plugin/src/runtime/open_code_plugin_descriptor.dart";
import "package:opencode_plugin/src/runtime/open_code_runtime_manifest.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = OpenCodeRuntimeManifest();

  group("OpenCodeRuntimeManifest", () {
    test("uses the plugin id as its shared managed-runtime subdirectory", () {
      expect(manifest.runtimeId, OpenCodePluginDescriptor.production().id);
    });

    test("pins a sha256 asset for every supported platform target", () {
      for (final os in PlatformOs.values) {
        for (final arch in PlatformArch.values) {
          final asset = manifest.assetFor(
            target: PlatformTarget(os: os, arch: arch),
          );
          expect(asset, isNotNull, reason: "missing asset for $os/$arch");
          expect(asset!.sha256, matches(RegExp(r"^[0-9a-f]{64}$")), reason: "$os/$arch sha256");
          expect(asset.assetName, isNotEmpty);
        }
      }
    });

    test("all six npm tarballs select the nested executable as a single binary", () {
      var count = 0;
      for (final os in PlatformOs.values) {
        for (final arch in PlatformArch.values) {
          final asset =
              manifest.assetFor(
                    target: PlatformTarget(os: os, arch: arch),
                  )!
                  as ArchiveRuntimeAsset;
          final platform = switch (os) {
            PlatformOs.macos => "darwin",
            PlatformOs.linux => "linux",
            PlatformOs.windows => "windows",
          };
          final package = "cli-$platform-${arch.name}";
          final filename = "$package-${OpenCodeRuntimeManifest.targetVersion}.tgz";
          expect(asset.assetName, filename);
          expect(asset.format, ArchiveFormat.tarGz);
          expect(asset.archiveBinaryName, "package/bin/opencode${os == PlatformOs.windows ? ".exe" : ""}");
          expect(asset.layout, RuntimeArchiveLayout.singleBinary);
          expect(manifest.downloadUrlFor(asset: asset), "https://registry.npmjs.org/@opencode/$package/-/$filename");
          count++;
        }
      }
      expect(count, 6);
    });

    test("download URL pins the npm version rather than a moving latest alias", () {
      final asset = manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
      )!;
      expect(
        manifest.downloadUrlFor(asset: asset),
        equals("https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-2.0.18.tgz"),
      );
    });

    test("bundled version is at least the minimum supported version", () {
      expect(OpenCodeRuntimeManifest.targetVersion, "2.0.18");
      expect(manifest.bundledVersion.toString(), OpenCodeRuntimeManifest.targetVersion);
      expect(manifest.minPathVersion.toString(), "1.14.0");
      expect(
        manifest.bundledVersion.compareTo(manifest.minPathVersion),
        greaterThanOrEqualTo(0),
      );
    });
  });
}
