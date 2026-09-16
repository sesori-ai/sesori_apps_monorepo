import "dart:io" show Platform;

import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = DeepSeekRuntimeManifest();

  test("pins the stable adapter as the PATH floor and managed release", () {
    expect(manifest.runtimeId, "deepseek");
    expect(manifest.pathExecutableName, "sesori-deepseek-acp");
    expect(
      manifest.binaryFileName,
      Platform.isWindows ? "sesori-deepseek-acp.cmd" : "sesori-deepseek-acp",
    );
    expect(manifest.minPathVersion.raw, "0.1.5");
    expect(manifest.minPathVersion.raw, DeepSeekPluginDescriptor.minVersion);
    expect(manifest.bundledVersion.raw, "0.1.5");
    expect(manifest.parseVersion(value: "sesori-deepseek-acp/0.1.0")?.raw, "0.1.0");
  });

  test("maps all six immutable package-directory archives", () {
    final assets = <ArchiveRuntimeAsset>[
      for (final target in const [
        PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64),
        PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.linux, arch: PlatformArch.x64),
        PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64),
        PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64),
      ])
        manifest.assetFor(target: target)! as ArchiveRuntimeAsset,
    ];

    expect(
      {for (final asset in assets) asset.assetName: asset.sha256},
      {
        "sesori-deepseek-acp-v0.1.5-darwin-arm64.tar.gz":
            "4741d1e58b912a0d15018c956c4484b2b04be4dd5cd58710508d094ac604c254",
        "sesori-deepseek-acp-v0.1.5-darwin-x64.tar.gz":
            "c985bae87b7fc3f8b6ca01f27dd47e36725e9da496c08bf01e7a0a285458fb86",
        "sesori-deepseek-acp-v0.1.5-linux-arm64.tar.gz":
            "5551a82f11838e4a3e73646283eed0c888547061428caab682c59a62fe72121b",
        "sesori-deepseek-acp-v0.1.5-linux-x64.tar.gz":
            "0675af1b24be0b8c35983b866a0624532767217db8a4254efb6e91e311a7d237",
        "sesori-deepseek-acp-v0.1.5-windows-arm64.zip":
            "390e593ab24f37ca00f52543997c876d90a59affd080e01c3cb8979b744c92c7",
        "sesori-deepseek-acp-v0.1.5-windows-x64.zip":
            "013cd4a261bcf99fe3438645b19fa610cc565f94694d74c674df83f90cb4ea1e",
      },
    );
    expect(
      assets,
      everyElement(
        predicate<ArchiveRuntimeAsset>(
          (asset) =>
              asset.layout == RuntimeArchiveLayout.packageDirectory && RegExp(r"^[0-9a-f]{64}$").hasMatch(asset.sha256),
        ),
      ),
    );
  });

  test("builds the immutable GitHub release URL", () {
    final asset = manifest.assetFor(
      target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
    )!;
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.1.5/sesori-deepseek-acp-v0.1.5-darwin-arm64.tar.gz",
    );
  });
}
