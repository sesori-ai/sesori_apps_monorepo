import "dart:io" show Platform;

import "package:omp_plugin/omp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  const manifest = OmpRuntimeManifest();

  test("pins v17.2.13 and parses only the OMP version prefix", () {
    expect(manifest.runtimeId, "omp");
    expect(manifest.pathExecutableName, "omp");
    expect(manifest.binaryFileName, Platform.isWindows ? "omp.exe" : "omp");
    expect(manifest.minPathVersion.raw, "17.2.13");
    expect(manifest.bundledVersion.raw, "17.2.13");
    expect(manifest.parseVersion(value: "omp/17.2.13")?.raw, "17.2.13");
    expect(manifest.parseVersion(value: "17.2.13"), isNull);
    expect(manifest.parseVersion(value: "omp/not-a-version"), isNull);
  });

  test("maps all seven official direct binary assets", () {
    final assets = <RuntimeAsset>[
      manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
      )!,
      manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.x64),
      )!,
      manifest.assetForLinux(arch: PlatformArch.arm64, libc: OmpLinuxLibc.glibc)!,
      manifest.assetForLinux(arch: PlatformArch.x64, libc: OmpLinuxLibc.glibc)!,
      manifest.assetForLinux(arch: PlatformArch.arm64, libc: OmpLinuxLibc.musl)!,
      manifest.assetForLinux(arch: PlatformArch.x64, libc: OmpLinuxLibc.musl)!,
      manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.x64),
      )!,
    ];

    expect(assets, everyElement(isA<DirectBinaryRuntimeAsset>()));
    expect(assets.map((asset) => asset.assetName), {
      "omp-darwin-arm64",
      "omp-darwin-x64",
      "omp-linux-arm64",
      "omp-linux-x64",
      "omp-linux-musl-arm64",
      "omp-linux-musl-x64",
      "omp-windows-x64.exe",
    });
    expect(assets.map((asset) => asset.sha256).toSet(), hasLength(7));
    expect(assets, everyElement(predicate<RuntimeAsset>((asset) => RegExp(r"^[0-9a-f]{64}$").hasMatch(asset.sha256))));
  });

  test("does not claim a Windows arm64 asset", () {
    expect(
      manifest.assetFor(
        target: const PlatformTarget(os: PlatformOs.windows, arch: PlatformArch.arm64),
      ),
      isNull,
    );
  });

  test("builds the official release URL", () {
    final asset = manifest.assetFor(
      target: const PlatformTarget(os: PlatformOs.macos, arch: PlatformArch.arm64),
    )!;
    expect(
      manifest.downloadUrlFor(asset: asset),
      "https://github.com/can1357/oh-my-pi/releases/download/v17.2.13/omp-darwin-arm64",
    );
  });
}
