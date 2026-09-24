import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../models/omp_linux_libc.dart";
import "../omp_identity.dart";

class const OmpRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "17.2.13");

  /// The latest stable Oh My Pi release targeted by this plugin.
  static const String targetVersion = "18.3.0";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, DirectBinaryRuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-arm64",
        sha256: "d61fb411f24146bed48dd901b13b5912a297d899ee691dda69c4b5b7ab8c35dc",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-x64",
        sha256: "be74498e0edcde7e018247b925f0e0ebf00a7748a1006b3a02eb62ca9e021baf",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-arm64.exe",
        sha256: "aed8edaa8a1d8e29ac846d2b88818a3bc6ab21b78cac59267f1406c873fe5fc7",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-x64.exe",
        sha256: "9be13f13e3c11dcba25dfccfad0f8c508f66fd8bc2f95a0f06f2964be8d8f527",
      ),
    },
  };

  static const Map<OmpLinuxLibc, Map<PlatformArch, DirectBinaryRuntimeAsset>> _linuxAssets = {
    OmpLinuxLibc.glibc: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-arm64",
        sha256: "bdfb9c494e17a2fee1956dae16a010a1953574ce4172c4db8efe06fbe477c637",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-x64",
        sha256: "d2fdaa29affe96e596eb9c78d42f548f1f291df28608631bcc00750a84b94bc3",
      ),
    },
    OmpLinuxLibc.musl: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-arm64",
        sha256: "258dfa55a6d90f288f2d1869535ab6e43e82a58b4fd5bb4477830819c08b3465",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-x64",
        sha256: "fa5c7ab9f0cfc8de67df17227961bbfc92f37bac14eee843bfd765c0d6c53562",
      ),
    },
  };

  @override
  String get runtimeId => OmpPluginIdentity.id;

  @override
  String get displayName => OmpPluginIdentity.displayName;

  @override
  String get installDocsUrl => "https://github.com/can1357/oh-my-pi";

  @override
  String get pathExecutableName => "omp";

  @override
  String get binaryFileName => Platform.isWindows ? "omp.exe" : "omp";

  @override
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeVersion? parseVersion({required String value}) {
    if (!value.startsWith("omp/")) return null;
    return SemanticRuntimeVersion.tryParse(value: value.substring(4));
  }

  /// `omp --version` prints `omp/<semver>` and the prefix is required so an
  /// unrelated semver token in that output is not mistaken for the runtime
  /// version. Version directories carry the bare semver, so they parse here.
  @override
  RuntimeVersion? parseInstalledVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) {
    if (target.os == PlatformOs.linux) return null;
    return _assets[target.os]?[target.arch];
  }

  /// Whether this release publishes an asset for [target]. Linux support is
  /// known before the host's libc variant is selected asynchronously.
  @override
  bool supportsManagedInstallOn({required PlatformTarget target}) {
    if (target.os == PlatformOs.linux) return _linuxAssets.values.any((assets) => assets.containsKey(target.arch));
    return assetFor(target: target) != null;
  }

  RuntimeAsset? assetForLinux({required PlatformArch arch, required OmpLinuxLibc libc}) => _linuxAssets[libc]?[arch];

  @override
  String downloadUrlFor({required RuntimeAsset asset}) =>
      githubReleaseAssetUrl(repository: "can1357/oh-my-pi", tag: "v${bundledVersion.raw}", asset: asset);
}
