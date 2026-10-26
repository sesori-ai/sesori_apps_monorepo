import "dart:io" show Platform;

import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = DeepSeekRuntimeManifest();

  test("pins the compatible PATH floor and latest managed release", () {
    expect(manifest.runtimeId, "deepseek");
    expect(manifest.pathExecutableName, "sesori-deepseek-acp");
    expect(
      manifest.binaryFileName,
      Platform.isWindows ? "sesori-deepseek-acp.cmd" : "sesori-deepseek-acp",
    );
    expect(manifest.minPathVersion.raw, "0.1.5");
    expect(manifest.minPathVersion.raw, DeepSeekPluginDescriptor.minVersion);
    expect(manifest.bundledVersion.raw, "0.2.1");
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
        "sesori-deepseek-acp-v0.2.1-darwin-arm64.tar.gz":
            "3ca8d94553514796f59f890282f2b065d1d639434fd2125c4869088e8e2703da",
        "sesori-deepseek-acp-v0.2.1-darwin-x64.tar.gz":
            "294edfd30f42f661166efa473e9376dd9575deff5e27d8b1aec06b34945f362a",
        "sesori-deepseek-acp-v0.2.1-linux-arm64.tar.gz":
            "9010b419f477aa4af4286e5a0ba396ee3fd0fb9ea5cee7d7a23c41833c989499",
        "sesori-deepseek-acp-v0.2.1-linux-x64.tar.gz":
            "ea0a220e9962c0f0becb6e4f35b9fe819aa59af272e721098444df6c626bfcba",
        "sesori-deepseek-acp-v0.2.1-windows-arm64.zip":
            "72e21092c59f92d84a4590be3b6c449b229342cb21cba864ccb4988684bfe3d6",
        "sesori-deepseek-acp-v0.2.1-windows-x64.zip":
            "21d764720fdd55cfa360fe762c94bdcd5ce1ca58189368943ed0c83ed302a6b5",
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
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.2.1/sesori-deepseek-acp-v0.2.1-darwin-arm64.tar.gz",
    );
  });
}
