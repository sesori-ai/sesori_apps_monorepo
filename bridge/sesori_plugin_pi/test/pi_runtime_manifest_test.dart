import "dart:io" show Platform;

import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = PiRuntimeManifest();

  test("keeps the verified PATH floor and pins managed Pi v0.84.2", () {
    expect(manifest.runtimeId, "pi");
    expect(manifest.pathExecutableName, "pi");
    expect(manifest.binaryFileName, Platform.isWindows ? "pi.exe" : "pi");
    expect(manifest.minPathVersion.raw, "0.84.1");
    expect(manifest.bundledVersion.raw, "0.84.2");
    expect(manifest.parseVersion(value: "0.84.2")?.raw, "0.84.2");
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
    expect(assets.map((asset) => asset.sha256).toSet(), hasLength(6));
    expect(
      assets,
      everyElement(
        predicate<ArchiveRuntimeAsset>((asset) => RegExp(r"^[0-9a-f]{64}$").hasMatch(asset.sha256)),
      ),
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

  test("builds the official release URL", () {
    final asset = manifest.assetFor(
      target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
    )!;
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/earendil-works/pi/releases/download/v0.84.2/pi-darwin-arm64.tar.gz",
    );
  });
}
