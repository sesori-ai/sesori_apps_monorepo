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
    expect(manifest.minPathVersion.raw, "0.1.4");
    expect(manifest.minPathVersion.raw, DeepSeekPluginDescriptor.minVersion);
    expect(manifest.bundledVersion.raw, "0.1.4");
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
        "sesori-deepseek-acp-v0.1.4-darwin-arm64.tar.gz":
            "fe565d18efc228b5d5a93835f5f4d900c00ae113649a1480266c305fc5623082",
        "sesori-deepseek-acp-v0.1.4-darwin-x64.tar.gz":
            "f3d5d4df05069daab221f5bdda8480bbb6448ea4d8139b3d75ccd0f2722fd151",
        "sesori-deepseek-acp-v0.1.4-linux-arm64.tar.gz":
            "8fa13b6e5dea36eb33c38bc9e1b7960c690b5646d4010809f743e11555e0d979",
        "sesori-deepseek-acp-v0.1.4-linux-x64.tar.gz":
            "0f1b187e54acb008b56fa99fa1c1d0e2ad33913f7c986d801758adf3c642a74d",
        "sesori-deepseek-acp-v0.1.4-windows-arm64.zip":
            "f32f26bb5540cb899b5704d67be8a1ff7521d567382fe2f1a4561026e32678d4",
        "sesori-deepseek-acp-v0.1.4-windows-x64.zip":
            "218cd61ad11c89a9f5d538e47ff0f27c4e23ce3748af235663917f58c3f8e252",
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
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.1.4/sesori-deepseek-acp-v0.1.4-darwin-arm64.tar.gz",
    );
  });
}
