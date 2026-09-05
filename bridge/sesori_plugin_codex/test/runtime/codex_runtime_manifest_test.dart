import "dart:io" show Platform;

import "package:codex_plugin/src/runtime/codex_plugin_descriptor.dart";
import "package:codex_plugin/src/runtime/codex_runtime_manifest.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginStateStorage;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = CodexRuntimeManifest();

  group("CodexRuntimeManifest", () {
    test("descriptor preserves the legacy shared runtime directory", () {
      expect(const CodexPluginDescriptor().stateStorage, PluginStateStorage.legacySharedRuntime);
    });

    test("pinned versions", () {
      expect(CodexRuntimeManifest.targetVersion, "0.148.0");
      expect(manifest.bundledVersion.toString(), CodexRuntimeManifest.targetVersion);
      expect(manifest.minPathVersion.toString(), "0.139.0");
      expect(manifest.runtimeId, const CodexPluginDescriptor().id);
      expect(manifest.pathExecutableName, "codex");
      expect(manifest.binaryFileName, Platform.isWindows ? r"bin\codex.exe" : "bin/codex");
    });

    test("pins the canonical package and digest for every platform target", () {
      const expected = <PlatformOs, Map<PlatformArch, ({String assetName, String sha256})>>{
        PlatformOs.macos: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-apple-darwin.tar.gz",
            sha256: "bfae69c7bb7a3fbe68161f2ca9328839c7e6eea053a8871186eb6edbb1346870",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-apple-darwin.tar.gz",
            sha256: "9ac9245ea244629a9ba4db3315f0cdaebb05182b790ee34271a5060875d836e1",
          ),
        },
        PlatformOs.linux: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-unknown-linux-musl.tar.gz",
            sha256: "580db3c7411f5852b550876f185c30b61b674e01b948fd5030f2cd7a30db110a",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-unknown-linux-musl.tar.gz",
            sha256: "8c790500af2ba6e74ce4948fe26c651ac1f77f6dbb005b47c8d26ff711146262",
          ),
        },
        PlatformOs.windows: {
          PlatformArch.arm64: (
            assetName: "codex-package-aarch64-pc-windows-msvc.tar.gz",
            sha256: "0258ac84ebf8fdc6d8e1f4b0541d55a703f3d8996debca157a013cf753134c54",
          ),
          PlatformArch.x64: (
            assetName: "codex-package-x86_64-pc-windows-msvc.tar.gz",
            sha256: "cc09f725b8ed133b76a2882fda750b3f1672b10701e8172c9680b5ab79b861ff",
          ),
        },
      };

      for (final osEntry in expected.entries) {
        for (final archEntry in osEntry.value.entries) {
          final asset = manifest.assetFor(
            target: PlatformTarget(os: osEntry.key, arch: archEntry.key),
          );
          expect(asset, isA<ArchiveRuntimeAsset>(), reason: "${osEntry.key}/${archEntry.key} asset type");
          final archive = asset! as ArchiveRuntimeAsset;
          expect(archive.assetName, archEntry.value.assetName);
          expect(archive.sha256, archEntry.value.sha256);
          expect(archive.format, ArchiveFormat.tarGz);
          expect(archive.layout, RuntimeArchiveLayout.packageDirectory);
          expect(
            archive.archiveBinaryName,
            osEntry.key == PlatformOs.windows ? "bin/codex.exe" : "bin/codex",
          );
        }
      }
    });

    test("download URL embeds the rust-v bundled tag and asset name", () {
      final asset = manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
      )!;
      expect(
        manifest.downloadUrlFor(asset: asset),
        equals(
          "https://github.com/openai/codex/releases/download/"
          "rust-v0.148.0/codex-package-aarch64-apple-darwin.tar.gz",
        ),
      );
    });

    test("bundled version is at least the minimum PATH version", () {
      expect(manifest.bundledVersion.compareTo(manifest.minPathVersion), greaterThanOrEqualTo(0));
    });
  });
}
