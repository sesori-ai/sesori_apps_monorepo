import "dart:io" show Platform;

import "package:pi_plugin/pi_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = PiRuntimeManifest();

  test("keeps the verified PATH floor and pins managed Pi v1.6.0", () {
    expect(manifest.runtimeId, "pi");
    expect(manifest.pathExecutableName, "pi");
    expect(manifest.binaryFileName, Platform.isWindows ? "pi.exe" : "pi");
    expect(manifest.minPathVersion.raw, "0.99.0");
    expect(PiRuntimeManifest.targetVersion, "1.6.0");
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
        switch (manifest.assetFor(target: target)) {
          final ArchiveRuntimeAsset asset => asset,
          final other => fail("expected an archive asset for $target, got $other"),
        },
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
      "pi-darwin-arm64.tar.gz": "6429287b7ae98d726ec577815d14fd680e7c587e89ecc5153b4a145dc4adba33",
      "pi-darwin-x64.tar.gz": "5b69cd87c3b00e74cce2d1499df3b7a1ec73632f11abf64696d110f0f4dc4192",
      "pi-linux-arm64.tar.gz": "5404547b9739be596d50ae7142c52535899e8e7dd37a7bace9be593e0355b468",
      "pi-linux-x64.tar.gz": "ef77dbe4379b3bdeb425a1e1b862fa3c915c255000dfe4965c98eee96a5765d1",
      "pi-windows-arm64.zip": "56433d392e1baecf9f1692785a3bf171c125b415a29dd36097d02baca98bc9eb",
      "pi-windows-x64.zip": "f5defb6c403ee698f5b3f8886db473e55b78aac670a8ce03620a47f5f0aec57c",
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
    final asset =
        manifest.assetFor(
          target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
        ) ??
        fail("missing macOS arm64 asset");
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/earendil-works/pi/releases/download/v1.6.0/pi-darwin-arm64.tar.gz",
    );
  });
}
