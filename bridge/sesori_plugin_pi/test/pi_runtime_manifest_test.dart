import "dart:io" show Platform;

import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = PiRuntimeManifest();

  test("keeps the verified PATH floor and pins managed Pi v0.85.1", () {
    expect(manifest.runtimeId, "pi");
    expect(manifest.pathExecutableName, "pi");
    expect(manifest.binaryFileName, Platform.isWindows ? "pi.exe" : "pi");
    expect(manifest.minPathVersion.raw, "0.84.1");
    expect(PiRuntimeManifest.targetVersion, "0.85.1");
    expect(manifest.bundledVersion.raw, PiRuntimeManifest.targetVersion);
    expect(manifest.parseVersion(value: "0.84.4")?.raw, "0.84.4");
    expect(manifest.parseVersion(value: "pi/0.84.2"), isNull);
  });

  test("maps all six official package-directory archives", () {
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

    expect(assets.map((asset) => asset.assetName), {
      "pi-darwin-arm64.tar.gz",
      "pi-darwin-x64.tar.gz",
      "pi-linux-arm64.tar.gz",
      "pi-linux-x64.tar.gz",
      "pi-windows-arm64.zip",
      "pi-windows-x64.zip",
    });
    expect(
      assets,
      everyElement(
        predicate<ArchiveRuntimeAsset>((asset) => asset.layout == RuntimeArchiveLayout.packageDirectory),
      ),
    );
    const expectedSha256 = {
      "pi-darwin-arm64.tar.gz": "d5f70e3c0cf7398eac239fd0261ee074d98b7ba7f6b43fe3617f052ed5b79d06",
      "pi-darwin-x64.tar.gz": "adb918b845625f184d8bea408d55eacaf21aa87238793c0f5b4f3b9737bce62b",
      "pi-linux-arm64.tar.gz": "042d20ae885ee4f3b102815f3280b962c377b2e9fb44de4037908cc530eae4d4",
      "pi-linux-x64.tar.gz": "494e498f47d74d21f40b3386f6a5e921a3d49531a169cab55bbdaca0ea1fe25a",
      "pi-windows-arm64.zip": "b25e96fe64c9f41f75a924c0d36f395abb98d6c6fec0b78aaa0b86926f938bb4",
      "pi-windows-x64.zip": "002fa95b90d521245b9985d8f168caebc237ad56e7e30b319807dee1b2e17e1c",
    };
    expect(
      {for (final asset in assets) asset.assetName: asset.sha256},
      expectedSha256,
    );
    expect(
      assets.take(4),
      everyElement(predicate<ArchiveRuntimeAsset>((asset) => asset.archiveBinaryName == "pi")),
    );
    expect(
      assets.skip(4),
      everyElement(predicate<ArchiveRuntimeAsset>((asset) => asset.archiveBinaryName == "pi.exe")),
    );
  });

  test("builds the official release URL with the v tag", () {
    final asset = manifest.assetFor(
      target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
    )!;
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/earendil-works/pi/releases/download/v0.85.1/pi-darwin-arm64.tar.gz",
    );
  });
}
