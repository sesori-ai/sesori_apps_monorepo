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
    expect(manifest.bundledVersion.raw, "0.2.0");
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
        "sesori-deepseek-acp-v0.2.0-darwin-arm64.tar.gz":
            "122afd1d8792ffa9caa34a9245798ec184ba96f020f88d99ddd65ca194f9ffaf",
        "sesori-deepseek-acp-v0.2.0-darwin-x64.tar.gz":
            "256e972267508b46a041793f6ac3168043d848edc3815e553f6bdd18b96eb4f4",
        "sesori-deepseek-acp-v0.2.0-linux-arm64.tar.gz":
            "750b9ff66be9d8c36d5cadf17d4f5e3f50889beb807fa6036970883c69b220be",
        "sesori-deepseek-acp-v0.2.0-linux-x64.tar.gz":
            "b756edfe46b79342002965129660fb1739aaf241f87e2c1276a2f71256bed2c5",
        "sesori-deepseek-acp-v0.2.0-windows-arm64.zip":
            "f82a926c107c9e3831ff9324fd913dbb9ec2e9d295fe04b32446ffe4f0e2a32e",
        "sesori-deepseek-acp-v0.2.0-windows-x64.zip":
            "bd14b053a8bb2e4937dfcf852ea660dbfc84d609624c4cbfdf6bca66f0d11f4a",
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
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v0.2.0/sesori-deepseek-acp-v0.2.0-darwin-arm64.tar.gz",
    );
  });
}
