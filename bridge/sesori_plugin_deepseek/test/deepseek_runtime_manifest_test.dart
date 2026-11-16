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
    expect(manifest.bundledVersion.raw, "0.2.3");
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
        (manifest.assetFor(target: target) ?? fail("no asset for $target")) as ArchiveRuntimeAsset,
    ];

    expect(
      {for (final asset in assets) asset.assetName: asset.sha256},
      {
        "sesori-deepseek-acp-v0.2.3-darwin-arm64.tar.gz":
            "437dbbfbbd6d18b255b35ec89dead4a864810a1c44cfbb10c22dc245228a9906",
        "sesori-deepseek-acp-v0.2.3-darwin-x64.tar.gz":
            "e5294bca3702a893f96e0428aecffc0f8689d0a78ba0ba7dd44e118b8f618c92",
        "sesori-deepseek-acp-v0.2.3-linux-arm64.tar.gz":
            "261e8330b17519c07aab60096bff283046300dedfd5d1f9f9a12aa187530b078",
        "sesori-deepseek-acp-v0.2.3-linux-x64.tar.gz":
            "0b974187a72181a2a29862620ec11a708ee65e544c4fc1d794d464364958b3c0",
        "sesori-deepseek-acp-v0.2.3-windows-arm64.zip":
            "fb80cc40117948b3a738bdb401d16a0998bdfd4308ce6d23953b290180262ee2",
        "sesori-deepseek-acp-v0.2.3-windows-x64.zip":
            "3f676e4bc0490af4a97778272f682972fdba4b13efb1f909c77d966663736de2",
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
    final asset =
        manifest.assetFor(
          target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
        ) ??
        fail("no macOS arm64 asset");
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.2.3/sesori-deepseek-acp-v0.2.3-darwin-arm64.tar.gz",
    );
  });
}
