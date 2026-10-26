import "dart:io" show Platform;

import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = PiRuntimeManifest();

  test("keeps the verified PATH floor and pins managed Pi v1.4.0", () {
    expect(manifest.runtimeId, "pi");
    expect(manifest.pathExecutableName, "pi");
    expect(manifest.binaryFileName, Platform.isWindows ? "pi.exe" : "pi");
    expect(manifest.minPathVersion.raw, "0.99.0");
    expect(PiRuntimeManifest.targetVersion, "1.4.0");
    expect(manifest.bundledVersion.raw, PiRuntimeManifest.targetVersion);
    expect(manifest.parseVersion(value: "0.99.2")?.raw, "0.99.2");
    expect(manifest.parseVersion(value: "pi/0.99.2"), isNull);
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
      "pi-darwin-arm64.tar.gz": "79d9979d76a2a5adb7c28e27e9b44629928ccd0dc9fbb6ae7217860bd5e8be5d",
      "pi-darwin-x64.tar.gz": "1bdefc9e1074c1de458ea9f2e43e6013ce49cd05326009b3de144037036585e2",
      "pi-linux-arm64.tar.gz": "fa5829c7ef83ffeaebba015715c8306220f89b2aa8a00154efbba98dd5440156",
      "pi-linux-x64.tar.gz": "f2e4e4329603223d03260cdb8bd5033dbdc1f73ba58ab8939db2e56546e115d2",
      "pi-windows-arm64.zip": "17ab17ee0e9088545c7dfa56d29490c45bd915425610b0db0cd937632f2df714",
      "pi-windows-x64.zip": "0f7256ea8bdac3af20012b94fdc1252a31cc6dc0d2f9b9eb539555d22e3e321b",
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
      "https://github.com/earendil-works/pi/releases/download/v1.4.0/pi-darwin-arm64.tar.gz",
    );
  });
}
